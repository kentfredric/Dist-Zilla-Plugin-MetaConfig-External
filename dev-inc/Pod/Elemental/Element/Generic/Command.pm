package Pod::Elemental::Element::Generic::Command;

# ABSTRACT: a Pod =command element
$Pod::Elemental::Element::Generic::Command::VERSION = '0.103004';
use Moose;

use namespace::autoclean;

#pod =head1 OVERVIEW
#pod
#pod Generic::Command elements are paragraph elements implementing the
#pod Pod::Elemental::Command role.  They provide the command method by implementing
#pod a read/write command attribute.
#pod
#pod =attr command
#pod
#pod This attribute contains the name of the command, like C<head1> or C<encoding>.
#pod
#pod =cut

has command => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

with 'Pod::Elemental::Command';

__PACKAGE__->meta->make_immutable;

1;

__END__

