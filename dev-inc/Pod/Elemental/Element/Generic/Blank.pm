package Pod::Elemental::Element::Generic::Blank;

# ABSTRACT: a series of blank lines
$Pod::Elemental::Element::Generic::Blank::VERSION = '0.103004';
use Moose;
with 'Pod::Elemental::Flat';

#pod =head1 OVERVIEW
#pod
#pod Generic::Blank elements represent vertical whitespace in a Pod document.  For
#pod the most part, these are meant to be placeholders until made unnecessary by the
#pod Pod5 transformer.  Most end-users will never need to worry about these
#pod elements.
#pod
#pod =cut

use namespace::autoclean;

sub as_debug_string { '|' }

__PACKAGE__->meta->make_immutable;

1;

__END__

