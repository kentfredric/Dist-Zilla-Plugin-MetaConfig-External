
use strict;
use warnings;

package Iterator::Util;
our $VERSION = '0.02';

use base 'Exporter';
use vars qw/@EXPORT @EXPORT_OK %EXPORT_TAGS/;

@EXPORT = qw(imap igrep irange ilist iarray ihead iappend
  ipairwise iskip iskip_until imesh izip iuniq);

@EXPORT_OK = (@EXPORT);

use Iterator;

# Function name: imap
# Synopsis:      $iter = imap {code} $another_iterator;
# Description:   Transforms an iterator.
# Created:       07/27/2005 by EJR
# Parameters:    code - Transformation code
#                $another_iterator - any other iterator.
# Returns:       Transformed iterator.
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub imap (&$) {
  my ( $transformation, $iter ) = @_;

  Iterator::X::Parameter_Error->throw(q{Argument to imap must be an Iterator object})
    unless UNIVERSAL::isa( $iter, 'Iterator' );

  return Iterator->new(
    sub {
      Iterator::is_done if ( $iter->is_exhausted );

      local $_ = $iter->value();
      return $transformation->();
    }
  );
}

# Function name: igrep
# Synopsis:      $iter = igrep {code} $another_iterator;
# Description:   Filters an iterator.
# Created:       07/27/2005 by EJR
# Parameters:    code - Filter condition.
#                $another_iterator - any other iterator.
# Returns:       Filtered iterator.
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub igrep (&$) {
  my ( $test, $iter ) = @_;

  Iterator::X::Parameter_Error->throw(q{Argument to imap must be an Iterator object})
    unless UNIVERSAL::isa( $iter, 'Iterator' );

  return Iterator->new(
    sub {
      while ( $iter->isnt_exhausted() ) {
        local $_ = $iter->value();
        return $_ if $test->();
      }

      Iterator::is_done();
    }
  );
}

# Function name: irange
# Synopsis:      $iter = irange ($start, $end, $step);
# Description:   Generates an arithmetic sequence of numbers.
# Created:       07/27/2005 by EJR
# Parameters:    $start - First value.
#                $end   - Final value.     (may be omitted)
#                $step  - Increment value. (may be omitted)
# Returns:       Sequence iterator
# Exceptions:    Iterator::X::Am_Now_Exhausted
# Notes:         If the $end value is omitted, iterator is unbounded.
#                If $step is omitted, it defaults to 1.
#                $step may be negative (or even zero).
sub irange {
  my ( $from, $to, $step ) = @_;
  $step = 1 unless defined $step;

  return Iterator->new(
    sub {
      # Reached limit?
      Iterator::is_done
        if ( defined($to)
        && ( $step > 0 && $from > $to || $step < 0 && $from < $to ) );

      # This iteration's return value
      my $retval = $from;

      $from += $step;
      return $retval;
    }
  );
}

# Function name: ilist
# Synopsis:      $iter = ilist (@list);
# Description:   Creates an iterator from a list
# Created:       07/28/2005 by EJR
# Parameters:    @list - list of values to iterate over
# Returns:       Array (list) iterator
# Exceptions:    Iterator::X::Am_Now_Exhausted
# Notes:         Makes an internal copy of the list.
sub ilist {
  my @items = @_;
  my $index = 0;
  return Iterator->new(
    sub {
      Iterator::is_done if ( $index >= @items );
      return $items[ $index++ ];
    }
  );
}

# Function name: iarray
# Synopsis:      $iter = iarray ($a_ref);
# Description:   Creates an iterator from an array reference
# Created:       07/28/2005 by EJR
# Parameters:    $a_ref - Reference to array to iterate over
# Returns:       Array iterator
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
# Notes:         Does not make an internal copy of the list.
sub iarray ($) {
  my $items = shift;
  my $index = 0;

  Iterator::X::Parameter_Error->throw->(q{Argument to iarray must be an array reference})
    if ref $items ne 'ARRAY';

  return Iterator->new(
    sub {
      Iterator::is_done if $index >= @$items;
      return $items->[ $index++ ];
    }
  );
}

# Function name: ihead
# Synopsis:      $iter = ihead ($num, $some_other_iterator);
# Synopsis:      @valuse = ihead ($num, $iterator);
# Description:   Returns at most $num items from other iterator.
# Created:       07/28/2005 by EJR
#                08/02/2005 EJR: combined with ahead, per Will Coleda
# Parameters:    $num - Max number of items to return
#                $some_other_iterator - another iterator
# Returns:       limited iterator
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub ihead {
  my $num  = shift;
  my $iter = shift;

  Iterator::X::Parameter_Error->throw(q{Second parameter for ihead must be an Iterator})
    unless UNIVERSAL::isa( $iter, 'Iterator' );

  # List context?  Return the first $num elements.
  if (wantarray) {
    my @a;
    while ( $iter->isnt_exhausted && ( !defined($num) || $num-- > 0 ) ) {
      push @a, $iter->value;
    }
    return @a;
  }

  # Scalar context: return an iterator to return at most $num elements.
  return Iterator->new(
    sub {
      Iterator::is_done if $num <= 0;

      $num--;
      return $iter->value;
    }
  );
}

# Function name: iappend
# Synopsis:      $iter = iappend (@iterators);
# Description:   Joins a bunch of iterators together.
# Created:       07/28/2005 by EJR
# Parameters:    @iterators - any number of other iterators
# Returns:       A "merged" iterator.
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub iappend {
  my @its = @_;

  # Check types
  foreach (@its) {
    Iterator::X::Parameter_Error->throw(q{All parameters for iarray must be Iterators})
      unless UNIVERSAL::isa( $_, 'Iterator' );
  }

  # Passthru, if there's only one.
  return $its[0] if @its == 1;

  return Iterator->new(
    sub {
      my $val;

      # Any empty iterators at front of list?  Remove'em.
      while ( @its && $its[0]->is_exhausted ) {
        shift @its;
      }

      # No more iterators?  Then we're done.
      Iterator::is_done
        if @its == 0;

      # Return the next value of the iterator at the head of the list.
      return $its[0]->value;
    }
  );
}

# Function name: ipairwise
# Synopsis:      $iter = ipairwise {code} ($iter1, $iter2);
# Description:   Applies an operation to pairs of values from iterators.
# Created:       07/28/2005 by EJR
# Parameters:    code - transformation, may use $a and $b
#                $iter1 - First iterator; "$a" value.
#                $iter2 - First iterator; "$b" value.
# Returns:       Iterator
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub ipairwise (&$$) {
  my $op    = shift;
  my $iterA = shift;
  my $iterB = shift;

  # Check types
  for ( $iterA, $iterB ) {
    Iterator::X::Parameter_Error->throw(q{Second and third parameters for ipairwise must be Iterators})
      unless UNIVERSAL::isa( $_, 'Iterator' );
  }

  return Iterator->new(
    sub {
      Iterator::is_done
        if $iterA->is_exhausted || $iterB->is_exhausted;

      # Localize $a and $b
      # My thanks to Benjamin Goldberg for this little bit of evil.
      my ( $caller_a, $caller_b ) = do {
        my $pkg;
        my $i = 1;
        while (1) {
          $pkg = caller( $i++ );
          last if $pkg ne 'Iterator' && $pkg ne 'Iterator::Util';
        }
        no strict 'refs';
        \*{ $pkg . '::a' }, \*{ $pkg . '::b' };
      };

      # Set caller's $a and $b
      local ( *$caller_a, *$caller_b ) = \( $iterA->value, $iterB->value );

      # Invoke caller's operation
      return $op->();
    }
  );
}

# Function name: iskip
# Synopsis:      $iter = iskip $num, $another_iterator
# Description:   Skips the first $num values of another iterator
# Created:       07/28/2005 by EJR
# Parameters:    $num - how many values to skip
#                $another_iterator - another iterator
# Returns:       Sequence iterator
# Exceptions:    None
sub iskip {
  my $num = shift;
  my $it  = shift;

  Iterator::X::Parameter_Error->throw(q{Second parameter for iskip must be an Iterator})
    unless UNIVERSAL::isa( $it, 'Iterator' );

  # Discard first $num values
  $it->value while $it->isnt_exhausted && $num-- > 0;

  return $it;
}

# Function name: iskip_until
# Synopsis:      $iter = iskip_until {code}, $another_iterator
# Description:   Skips values of another iterator until {code} is true.
# Created:       07/28/2005 by EJR
# Parameters:    {code} - Determines when to start returning values
#                $another_iterator - another iterator
# Returns:       Sequence iterator
# Exceptions:    Iterator::X::Am_Now_Exhausted
sub iskip_until (&$) {
  my $code = shift;
  my $iter = shift;
  my $value;
  my $found_it = 0;

  Iterator::X::Parameter_Error->throw(q{Second parameter for iskip_until must be an Iterator})
    unless UNIVERSAL::isa( $iter, 'Iterator' );

  # Discard first $num values
  while ( $iter->isnt_exhausted ) {
    local $_ = $iter->value;
    if ( $code->() ) {
      $found_it = 1;
      $value    = $_;
      last;
    }
  }

  # Didn't find it?  Pity.
  Iterator::is_done
    unless $found_it;

  # Return an iterator with this value, and all remaining values.
  return iappend ilist($value), $iter;
}

# Function name: imesh / izip
# Synopsis:      $iter = imesh ($iter1, $iter2, ...)
# Description:   Merges other iterators together.
# Created:       07/30/2005 by EJR
# Parameters:    Any number of other iterators.
# Returns:       Sequence iterator
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
foreach my $sub (qw/imesh izip/) {
  no strict 'refs';
  *$sub = sub {
    use strict 'refs';

    my @iterators = @_;
    my $it_index  = 0;

    foreach my $iter (@iterators) {
      Iterator::X::Parameter_Error->throw("Argument to $sub is not an iterator")
        unless UNIVERSAL::isa( $iter, 'Iterator' );
    }

    return Iterator->new(
      sub {
        Iterator::is_done
          if $iterators[$it_index]->is_exhausted();

        my $retval = $iterators[$it_index]->value();

        if ( ++$it_index >= @iterators ) {
          $it_index = 0;
        }

        return $retval;
      }
    );
  };
}

# Function name: iuniq
# Synopsis:      $iter = iuniq ($another_iterator);
# Description:   Removes duplicate entries from an iterator.
# Created:       07/30/2005 by EJR
# Parameters:    Another iterator.
# Returns:       Sequence iterator
# Exceptions:    Iterator::X::Parameter_Error
#                Iterator::X::Am_Now_Exhausted
sub iuniq {
  Iterator::X::Parameter_Error->throw("Too few parameters to iuniq")
    if @_ < 1;
  Iterator::X::Parameter_Error->throw("Too many parameters to iuniq")
    if @_ > 1;

  my $iter = shift;
  Iterator::X::Parameter_Error->throw("Argument to iuniq is not an iterator")
    unless UNIVERSAL::isa( $iter, 'Iterator' );

  my %did_see;
  return Iterator->new(
    sub {
      my $value;
      while (1) {
        Iterator::is_done
          if $iter->is_exhausted;

        $value = $iter->value;
        last if !$did_see{$value}++;
      }
      return $value;
    }
  );
}

1;
__END__


