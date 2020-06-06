package Data::DPath::Attrs;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Abstraction for internal attributes attached to a point
$Data::DPath::Attrs::VERSION = '0.57';
use strict;
use warnings;

use Class::XSAccessor    # ::Array
  chained     => 1,
  constructor => 'new',
  accessors   => [qw( key )];

1;

__END__

