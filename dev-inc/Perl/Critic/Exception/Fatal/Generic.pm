package Perl::Critic::Exception::Fatal::Generic;

use 5.006001;
use strict;
use warnings;

use Readonly;

our $VERSION = '1.130';

#-----------------------------------------------------------------------------

use Exception::Class (
  'Perl::Critic::Exception::Fatal::Generic' => {
    isa         => 'Perl::Critic::Exception::Fatal',
    description => 'A general problem was found.',
    alias       => 'throw_generic',
  },
);

#-----------------------------------------------------------------------------

Readonly::Array our @EXPORT_OK => qw< throw_generic >;

#-----------------------------------------------------------------------------

1;

__END__

#-----------------------------------------------------------------------------


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 ft=perl expandtab shiftround :
