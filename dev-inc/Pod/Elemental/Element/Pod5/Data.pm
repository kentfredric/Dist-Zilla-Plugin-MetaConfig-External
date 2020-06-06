package Pod::Elemental::Element::Pod5::Data;

# ABSTRACT: a Pod data paragraph
$Pod::Elemental::Element::Pod5::Data::VERSION = '0.103004';
use Moose;
extends 'Pod::Elemental::Element::Generic::Text';

#pod =head1 OVERVIEW
#pod
#pod Pod5::Data paragraphs represent the content of
#pod L<Pod5::Region|Pod::Elemental::Element::Pod5::Region> paragraphs when the
#pod region is not a Pod-like region.  These regions should generally have a single
#pod data element contained in them.
#pod
#pod =cut

use namespace::autoclean;

__PACKAGE__->meta->make_immutable;

1;

__END__

