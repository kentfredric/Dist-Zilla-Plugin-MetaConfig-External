package Pod::Elemental::Element::Generic::Nonpod;

# ABSTRACT: a non-pod element in a Pod document
$Pod::Elemental::Element::Generic::Nonpod::VERSION = '0.103004';
use Moose;
with 'Pod::Elemental::Flat';

use namespace::autoclean;

#pod =head1 OVERVIEW
#pod
#pod Generic::Nonpod elements are just like Generic::Text elements, but represent
#pod non-pod content found in the Pod stream.
#pod
#pod =cut

__PACKAGE__->meta->make_immutable;

1;

__END__

