
use strict;
use warnings;

package Iterator;
our $VERSION = '0.03';

# Declare exception classes
use Exception::Class (
  'Iterator::X' => {
    description => 'Generic Iterator exception',
  },
  'Iterator::X::Parameter_Error' => {
    isa         => 'Iterator::X',
    description => 'Iterator method parameter error',
  },
  'Iterator::X::OptionError' => {
    isa         => 'Iterator::X',
    fields      => 'name',
    description => 'A bad option was passed to an iterator method or function',
  },
  'Iterator::X::Exhausted' => {
    isa         => 'Iterator::X',
    description => 'Attempt to next_value () on an exhausted iterator',
  },
  'Iterator::X::Am_Now_Exhausted' => {
    isa         => 'Iterator::X',
    description => 'Signals Iterator object that it is now exhausted',
  },
  'Iterator::X::User_Code_Error' => {
    isa         => 'Iterator::X',
    fields      => 'eval_error',
    description => q{An exception was thrown within the user's code},
  },
  'Iterator::X::IO_Error' => {
    isa         => 'Iterator::X',
    fields      => 'os_error',
    description => q{An I/O error occurred},
  },
  'Iterator::X::Internal_Error' => {
    isa         => 'Iterator::X',
    description => 'An Iterator.pm internal error.  Please contact author.',
  },
);

# Class method to help caller catch exceptions
BEGIN {
  # Dave Rolsky added this subroutine in v1.22 of Exception::Class.
  # Thanks, Dave!
  # We define it here so we have the functionality in pre-1.22 versions;
  # we make it conditional so as to avoid a warning in post-1.22 versions.
  *Exception::Class::Base::caught = sub {
    my $class = shift;
    return Exception::Class->caught($class);
    }
    if $Exception::Class::VERSION lt '1.22';
}

# Croak-like location of error
sub Iterator::X::location {
  my ( $pkg, $file, $line );
  my $caller_level = 0;
  while (1) {
    ( $pkg, $file, $line ) = caller( $caller_level++ );
    last if $pkg !~ /\A Iterator/x && $pkg !~ /\A Exception::Class/x;
  }
  return "at $file line $line";
}

# Die-like location of error
sub Iterator::X::Internal_Error::location {
  my $self = shift;
  return "at " . $self->file() . " line " . $self->line();
}

# Override full_message, to report location of error in caller's code.
sub Iterator::X::full_message {
  my $self = shift;

  my $msg = $self->message;
  return $msg if substr( $msg, -1, 1 ) eq "\n";

  $msg =~ s/[ \t]+\z//;    # remove any trailing spaces (is this necessary?)
  return $msg . q{ } . $self->location() . qq{\n};
}

## Constructor

# Method name:   new
# Synopsis:      $iterator = Iterator->new( $code_ref );
# Description:   Object constructor.
# Created:       07/27/2005 by EJR
# Parameters:    $code_ref - the iterator sequence generation code.
# Returns:       New Iterator.
# Exceptions:    Iterator::X::Parameter_Error (via _initialize)
sub new {
  my $class = shift;
  my $self  = \do { my $anonymous };
  bless $self, $class;
  $self->_initialize(@_);
  return $self;
}

{    # encapsulation enclosure

  # Attributes:
  my %code_for;          # The sequence code (coderef) for each object.
  my %is_exhausted;      # Boolean: is this object exhausted?
  my %next_value_for;    # One-item lookahead buffer for each object.
                         # [if you update this list of attributes, be sure to edit DESTROY]

  # Method name:   _initialize
  # Synopsis:      $iterator->_initialize( $code_ref );
  # Description:   Object initializer.
  # Created:       07/27/2005 by EJR
  # Parameters:    $code_ref - the iterator sequence generation code.
  # Returns:       Nothing.
  # Exceptions:    Iterator::X::Parameter_Error
  #                Iterator::X::User_Code_Error
  # Notes:         For internal module use only.
  #                Caches the first value of the iterator in %next_value_for.
  sub _initialize {
    my $self = shift;

    Iterator::X::Parameter_Error->throw(q{Too few parameters to Iterator->new()})
      if @_ < 1;
    Iterator::X::Parameter_Error->throw(q{Too many parameters to Iterator->new()})
      if @_ > 1;
    my $code = shift;
    Iterator::X::Parameter_Error->throw(q{Parameter to Iterator->new() must be code reference})
      if ref $code ne 'CODE';

    $code_for{$self} = $code;

    # Get the next (first) value for this iterator
    eval { $next_value_for{$self} = $code->(); };

    my $ex;
    if ( $ex = Iterator::X::Am_Now_Exhausted->caught() ) {

      # Starting off exhausted is okay
      $is_exhausted{$self} = 1;
    }
    elsif ($@) {
      Iterator::X::User_Code_Error->throw(
        message    => "$@",
        eval_error => $@
      );
    }

    return;
  }

  # Method name:   DESTROY
  # Synopsis:      (none)
  # Description:   Object destructor.
  # Created:       07/27/2005 by EJR
  # Parameters:    None.
  # Returns:       Nothing.
  # Exceptions:    None.
  # Notes:         Invoked automatically by perl.
  #                Releases the hash entries used by the object.
  #                Module would leak memory otherwise.
  sub DESTROY {
    my $self = shift;
    delete $code_for{$self};
    delete $is_exhausted{$self};
    delete $next_value_for{$self};
  }

  # Method name:   value
  # Synopsis:      $next_value = $iterator->value();
  # Description:   Returns each value of the sequence in turn.
  # Created:       07/27/2005 by EJR
  # Parameters:    None.
  # Returns:       Next value, as generated by caller's code ref.
  # Exceptions:    Iterator::X::Exhausted
  # Notes:         Keeps one forward-looking value for the iterator in
  #                   %next_value_for.  This is so we have something to
  #                   return when user's code throws Am_Now_Exhausted.
  sub value {
    my $self = shift;

    Iterator::X::Exhausted->throw(q{Iterator is exhausted})
      if $is_exhausted{$self};

    # The value that we'll be returning this time.
    my $this_value = $next_value_for{$self};

    # Compute the value that we'll return next time
    eval { $next_value_for{$self} = $code_for{$self}->(@_); };
    if ( my $ex = Iterator::X::Am_Now_Exhausted->caught() ) {

      # Aha, we're done; we'll have to stop next time.
      $is_exhausted{$self} = 1;
    }
    elsif ($@) {
      Iterator::X::User_Code_Error->throw(
        message    => "$@",
        eval_error => $@
      );
    }

    return $this_value;
  }

  # Method name:   is_exhausted
  # Synopsis:      $boolean = $iterator->is_exhausted();
  # Description:   Flag indicating that the iterator is exhausted.
  # Created:       07/27/2005 by EJR
  # Parameters:    None.
  # Returns:       Current value of %is_exhausted for this object.
  # Exceptions:    None.
  sub is_exhausted {
    my $self = shift;

    return $is_exhausted{$self};
  }

  # Method name:   isnt_exhausted
  # Synopsis:      $boolean = $iterator->isnt_exhausted();
  # Description:   Flag indicating that the iterator is NOT exhausted.
  # Created:       07/27/2005 by EJR
  # Parameters:    None.
  # Returns:       Logical NOT of %is_exhausted for this object.
  # Exceptions:    None.
  sub isnt_exhausted {
    my $self = shift;

    return !$is_exhausted{$self};
  }

}    # end of encapsulation enclosure

# Function name: is_done
# Synopsis:      Iterator::is_done ();
# Description:   Convenience function. Throws an Am_Now_Exhausted exception.
# Created:       08/02/2005 by EJR, per Will Coleda's suggestion.
# Parameters:    None.
# Returns:       Doesn't return.
# Exceptions:    Iterator::X::Am_Now_Exhausted
sub is_done {
  Iterator::X::Am_Now_Exhausted->throw();
}

1;
__END__


