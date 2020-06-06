package Pod::Elemental::Element::Generic::Text;

# ABSTRACT: a Pod text or verbatim element
$Pod::Elemental::Element::Generic::Text::VERSION = '0.103004';
use Moose;
with 'Pod::Elemental::Flat';

use namespace::autoclean;

#pod =head1 OVERVIEW
#pod
#pod Generic::Text elements represent text paragraphs found in raw Pod.  They are
#pod likely to be fed to a Pod5 translator and converted to ordinary, verbatim, or
#pod data paragraphs in that dialect.  Otherwise, Generic::Text paragraphs are
#pod simple flat paragraphs.
#pod
#pod =cut

__PACKAGE__->meta->make_immutable;

1;

__END__

