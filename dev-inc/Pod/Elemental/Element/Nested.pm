package Pod::Elemental::Element::Nested;

# ABSTRACT: an element that is a command and a node
$Pod::Elemental::Element::Nested::VERSION = '0.103004';
use Moose;
extends 'Pod::Elemental::Element::Generic::Command';
with 'Pod::Elemental::Node';
with 'Pod::Elemental::Autochomp';

use namespace::autoclean;

# BEGIN Autochomp Replacement
use Pod::Elemental::Types qw(ChompedString);
has '+content' => ( coerce => 1, isa => ChompedString );

# END   Autochomp Replacement

#pod =head1 WARNING
#pod
#pod This class is somewhat sketchy and may be refactored somewhat in the future,
#pod specifically to refactor its similarities to
#pod L<Pod::Elemental::Element::Pod5::Region>.
#pod
#pod =head1 OVERVIEW
#pod
#pod A Nested element is a Generic::Command element that is also a node.
#pod
#pod It's used by the nester transformer to produce commands with children, to make
#pod documents seem more structured for easy manipulation.
#pod
#pod =cut

override as_pod_string => sub {
  my ($self) = @_;

  my $string = super;

  $string = join q{}, "$string\n\n", map { $_->as_pod_string } @{ $self->children };

  $string =~ s/\n{3,}\z/\n\n/g;

  return $string;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

