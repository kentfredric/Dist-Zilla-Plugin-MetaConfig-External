package Pod::Elemental::Element::Pod5::Verbatim;

# ABSTRACT: a Pod verbatim paragraph
$Pod::Elemental::Element::Pod5::Verbatim::VERSION = '0.103004';
use Moose;
extends 'Pod::Elemental::Element::Generic::Text';
with 'Pod::Elemental::Autoblank';
with 'Pod::Elemental::Autochomp';

# BEGIN Autochomp Replacement
use Pod::Elemental::Types qw(ChompedString);
has '+content' => ( coerce => 1, isa => ChompedString );

# END   Autochomp Replacement

#pod =head1 OVERVIEW
#pod
#pod Pod5::Verbatim elements represent "verbatim" paragraphs of text.  These are
#pod ordinary, flat paragraphs of text that were indented in the source Pod to
#pod indicate that they should be represented verbatim in formatted output.  The
#pod following paragraph is a verbatim paragraph:
#pod
#pod   This is a verbatim
#pod       paragraph
#pod          right here.
#pod
#pod =cut

use namespace::autoclean;

__PACKAGE__->meta->make_immutable;

1;

__END__

