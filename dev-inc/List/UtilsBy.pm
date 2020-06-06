#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2009-2018 -- leonerd@leonerd.org.uk

package List::UtilsBy;

use strict;
use warnings;

our $VERSION = '0.11';

use Exporter 'import';

our @EXPORT_OK = qw(
  sort_by
  nsort_by
  rev_sort_by
  rev_nsort_by

  max_by nmax_by
  min_by nmin_by
  minmax_by nminmax_by

  uniq_by

  partition_by
  count_by

  zip_by
  unzip_by

  extract_by
  extract_first_by

  weighted_shuffle_by

  bundle_by
);

sub sort_by(&@) {
  my $keygen = shift;

  my @keys = map { local $_ = $_; scalar $keygen->($_) } @_;
  return @_[ sort { $keys[$a] cmp $keys[$b] } 0 .. $#_ ];
}

sub nsort_by(&@) {
  my $keygen = shift;

  my @keys = map { local $_ = $_; scalar $keygen->($_) } @_;
  return @_[ sort { $keys[$a] <=> $keys[$b] } 0 .. $#_ ];
}

sub rev_sort_by(&@) {
  my $keygen = shift;

  my @keys = map { local $_ = $_; scalar $keygen->($_) } @_;
  return @_[ sort { $keys[$b] cmp $keys[$a] } 0 .. $#_ ];
}

sub rev_nsort_by(&@) {
  my $keygen = shift;

  my @keys = map { local $_ = $_; scalar $keygen->($_) } @_;
  return @_[ sort { $keys[$b] <=> $keys[$a] } 0 .. $#_ ];
}

sub max_by(&@) {
  my $code = shift;

  return unless @_;

  local $_;

  my @maximal = $_ = shift @_;
  my $max     = $code->($_);

  foreach (@_) {
    my $this = $code->($_);
    if ( $this > $max ) {
      @maximal = $_;
      $max     = $this;
    }
    elsif ( wantarray and $this == $max ) {
      push @maximal, $_;
    }
  }

  return wantarray ? @maximal : $maximal[0];
}

*nmax_by = \&max_by;

sub min_by(&@) {
  my $code = shift;

  return unless @_;

  local $_;

  my @minimal = $_ = shift @_;
  my $min     = $code->($_);

  foreach (@_) {
    my $this = $code->($_);
    if ( $this < $min ) {
      @minimal = $_;
      $min     = $this;
    }
    elsif ( wantarray and $this == $min ) {
      push @minimal, $_;
    }
  }

  return wantarray ? @minimal : $minimal[0];
}

*nmin_by = \&min_by;

sub minmax_by(&@) {
  my $code = shift;

  return unless @_;

  my $minimal = $_ = shift @_;
  my $min     = $code->($_);

  return ( $minimal, $minimal ) unless @_;

  my $maximal = $_ = shift @_;
  my $max     = $code->($_);

  if ( $max < $min ) {
    ( $maximal, $minimal ) = ( $minimal, $maximal );
    ( $max,     $min )     = ( $min,     $max );
  }

  # Minmax algorithm is faster than naïve min + max individually because it
  # takes pairs of values
  while (@_) {
    my $try_minimal = $_ = shift @_;
    my $try_min     = $code->($_);

    my $try_maximal = $try_minimal;
    my $try_max     = $try_min;
    if (@_) {
      $try_maximal = $_ = shift @_;
      $try_max     = $code->($_);

      if ( $try_max < $try_min ) {
        ( $try_minimal, $try_maximal ) = ( $try_maximal, $try_minimal );
        ( $try_min,     $try_max )     = ( $try_max,     $try_min );
      }
    }

    if ( $try_min < $min ) {
      $minimal = $try_minimal;
      $min     = $try_min;
    }
    if ( $try_max > $max ) {
      $maximal = $try_maximal;
      $max     = $try_max;
    }
  }

  return ( $minimal, $maximal );
}

*nminmax_by = \&minmax_by;

sub uniq_by(&@) {
  my $code = shift;

  my %present;
  return grep {
    my $key = $code->( local $_ = $_ );
    !$present{$key}++
  } @_;
}

sub partition_by(&@) {
  my $code = shift;

  my %parts;
  push @{ $parts{ $code->( local $_ = $_ ) } }, $_ for @_;

  return %parts;
}

sub count_by(&@) {
  my $code = shift;

  my %counts;
  $counts{ $code->( local $_ = $_ ) }++ for @_;

  return %counts;
}

sub zip_by(&@) {
  my $code = shift;

  @_ or return;

  my $len = 0;
  scalar @$_ > $len and $len = scalar @$_ for @_;

  return map {
    my $idx = $_;
    $code->( map { $_[$_][$idx] } 0 .. $#_ )
  } 0 .. $len - 1;
}

sub unzip_by(&@) {
  my $code = shift;

  my @ret;
  foreach my $idx ( 0 .. $#_ ) {
    my @slice = $code->( local $_ = $_[$idx] );
    $#slice = $#ret if @slice < @ret;
    $ret[$_][$idx] = $slice[$_] for 0 .. $#slice;
  }

  return @ret;
}

sub extract_by(&\@) {
  my $code = shift;
  my ($arrref) = @_;

  my @ret;
  for ( my $idx = 0 ; ; $idx++ ) {
    last if $idx > $#$arrref;
    next unless $code->( local $_ = $arrref->[$idx] );

    push @ret, splice @$arrref, $idx, 1, ();
    redo;
  }

  return @ret;
}

sub extract_first_by(&\@) {
  my $code = shift;
  my ($arrref) = @_;

  foreach my $idx ( 0 .. $#$arrref ) {
    next unless $code->( local $_ = $arrref->[$idx] );

    return splice @$arrref, $idx, 1, ();
  }

  return;
}

sub weighted_shuffle_by(&@) {
  my $code = shift;
  my @vals = @_;

  my @weights = map { $code->( local $_ = $_ ) } @vals;

  my @ret;
  while ( @vals > 1 ) {
    my $total = 0;
    $total += $_ for @weights;
    my $select = int rand $total;
    my $idx    = 0;
    while ( $select >= $weights[$idx] ) {
      $select -= $weights[ $idx++ ];
    }

    push @ret, splice @vals, $idx, 1, ();
    splice @weights, $idx, 1, ();
  }

  push @ret, @vals if @vals;

  return @ret;
}

sub bundle_by(&@) {
  my $code = shift;
  my $n    = shift;

  my @ret;
  for ( my ( $pos, $next ) = ( 0, $n ) ; $pos < @_ ; $pos = $next, $next += $n ) {
    $next = @_ if $next > @_;
    push @ret, $code->( @_[ $pos .. $next - 1 ] );
  }
  return @ret;
}

0x55AA;
