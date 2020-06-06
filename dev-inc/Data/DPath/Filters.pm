package Data::DPath::Filters;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Magic functions available inside filter conditions
$Data::DPath::Filters::VERSION = '0.57';
use strict;
use warnings;

use Data::Dumper;
use Scalar::Util;
use constant {
  HASH   => 'HASH',
  ARRAY  => 'ARRAY',
  SCALAR => 'SCALAR',
};

our $idx;
our $p;    # current point

sub affe {
  return $_ eq 'affe' ? 1 : 0;
}

sub idx { $idx }

sub size() {
  no warnings 'uninitialized';

  return -1 unless defined $_;

  # speed optimization: first try faster ref, then reftype
  # ref
  return scalar @$_      if ref $_ eq ARRAY;
  return scalar keys %$_ if ref $_ eq HASH;
  return 1               if ref \$_ eq SCALAR;

  # reftype
  return scalar @$_      if Scalar::Util::reftype $_ eq ARRAY;
  return scalar keys %$_ if Scalar::Util::reftype $_ eq HASH;
  return 1               if Scalar::Util::reftype \$_ eq SCALAR;

  # else
  return -1;
}

sub key() {
  no warnings 'uninitialized';
  my $attrs = defined $p->attrs ? $p->attrs : {};
  return $attrs->{key};
}

sub value() {
  no warnings 'uninitialized';
  return $_;
}

sub isa($) {
  my ($classname) = @_;

  no warnings 'uninitialized';

  #print STDERR "*** value ", Dumper($_ ? $_ : "UNDEF");
  return $_->isa($classname) if Scalar::Util::blessed $_;
  return undef;
}

sub reftype() {
  return Scalar::Util::reftype($_);
}

sub is_reftype($) {
  no warnings 'uninitialized';
  return ( Scalar::Util::reftype($_) eq shift );
}

1;

__END__


# sub parent, Eltern-Knoten liefern
# nextchild, von parent und mir selbst
# previous child
# "." als aktueller Knoten, kind of "no-op", daran aber Filter verknÃ¼pfbar, lÃ¶st //.[filter] und /.[filter]

# IDEA: functions that return always true, but track stack of values, eg. last taken index
#
#    //AAA/*[ _push_idx ]/CCC[ condition ]/../../*[ idx == pop_idx + 1]/
#
# This would take a way down to a filtered CCC, then back again and take the next neighbor.

