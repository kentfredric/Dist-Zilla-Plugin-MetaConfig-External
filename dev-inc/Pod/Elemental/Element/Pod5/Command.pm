package Pod::Elemental::Element::Pod5::Command;

# ABSTRACT: a Pod5 =command element
$Pod::Elemental::Element::Pod5::Command::VERSION = '0.103004';
use Moose;

extends 'Pod::Elemental::Element::Generic::Command';
with 'Pod::Elemental::Autoblank';
with 'Pod::Elemental::Autochomp';

use Pod::Elemental::Types qw(ChompedString);
has '+content' => (
  coerce => 1,
  isa    => ChompedString,
);

#pod =head1 OVERVIEW
#pod
#pod Pod5::Command elements are identical to
#pod L<Generic::Command|Pod::Elemental::Element::Generic::Command> elements, except
#pod that they incorporate L<Pod::Elemental::Autoblank>.  They represent command
#pod paragraphs in a Pod5 document.
#pod
#pod =cut

use namespace::autoclean;

__PACKAGE__->meta->make_immutable;

1;

__END__

