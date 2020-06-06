package Data::DPath::Step;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Abstraction for a single Step through a Path
$Data::DPath::Step::VERSION = '0.57';
use strict;
use warnings;

use Class::XSAccessor::Array
  chained     => 1,
  constructor => 'new',
  accessors   => {
  kind   => 0,
  part   => 1,
  filter => 2,
  };

1;

__END__

