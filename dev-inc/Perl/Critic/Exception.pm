package Perl::Critic::Exception;

use 5.006001;
use strict;
use warnings;

our $VERSION = '1.130';

#-----------------------------------------------------------------------------

use Exception::Class (
  'Perl::Critic::Exception' => {
    isa         => 'Exception::Class::Base',
    description => 'A problem discovered by Perl::Critic.',
  },
);

use Exporter 'import';

#-----------------------------------------------------------------------------

sub short_class_name {
  my ($self) = @_;

  return substr ref $self, ( length 'Perl::Critic' ) + 2;
}

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
