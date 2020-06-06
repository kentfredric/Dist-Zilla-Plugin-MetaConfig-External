package Data::DPath::Point;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Abstraction for a single reference (a "point") in the datastructure
$Data::DPath::Point::VERSION = '0.57';
use strict;
use warnings;

use Class::XSAccessor    # ::Array
  chained     => 1,
  constructor => 'new',
  accessors   => [
  qw( parent
    attrs
    ref
    )
  ];

1;

__END__

