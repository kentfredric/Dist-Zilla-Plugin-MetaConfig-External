package Pod::Elemental::Element::Pod5::Nonpod;

# ABSTRACT: a non-pod element in a Pod document
$Pod::Elemental::Element::Pod5::Nonpod::VERSION = '0.103004';
use Moose;
with 'Pod::Elemental::Flat';
with 'Pod::Elemental::Autoblank';

#pod =head1 OVERVIEW
#pod
#pod A Pod5::Nonpod element represents a hunk of non-Pod content found in a Pod
#pod document tree.  It is equivalent to a
#pod L<Generic::Nonpod|Pod::Elemental::Element::Generic::Nonpod> element, with the
#pod following differences:
#pod
#pod =over 4
#pod
#pod =item * it includes L<Pod::Elemental::Autoblank>
#pod
#pod =item * when producing a pod string, it wraps the non-pod content in =cut/=pod
#pod
#pod =back
#pod
#pod =cut

use namespace::autoclean;

sub as_pod_string {
  my ($self) = @_;
  return sprintf "=cut\n%s=pod\n", $self->content;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

