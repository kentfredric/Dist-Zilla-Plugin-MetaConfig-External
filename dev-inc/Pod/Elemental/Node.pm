package Pod::Elemental::Node;

# ABSTRACT: a thing with Pod::Elemental::Nodes as children
$Pod::Elemental::Node::VERSION = '0.103004';
use Moose::Role;

use namespace::autoclean;

use MooseX::Types;
use MooseX::Types::Moose qw(ArrayRef);
use Moose::Util::TypeConstraints qw(class_type);

requires 'as_pod_string';
requires 'as_debug_string';

#pod =head1 OVERVIEW
#pod
#pod Classes that include Pod::Elemental::Node represent collections of child
#pod Pod::Elemental::Paragraphs.  This includes Pod documents, Pod5 regions, and
#pod nested Pod elements produced by the Gatherer transformer.
#pod
#pod =attr children
#pod
#pod This attribute is an arrayref of
#pod L<Pod::Elemental::Node|Pod::Elemental::Node>-performing objects, and represents
#pod elements contained by an object.
#pod
#pod =cut

has children => (
  is       => 'rw',
  isa      => ArrayRef [ role_type('Pod::Elemental::Paragraph') ],
  required => 1,
  default  => sub { [] },
);

around as_debug_string => sub {
  my ( $orig, $self ) = @_;

  my $str = $self->$orig;

  my @children = map { $_->as_debug_string } @{ $self->children };
  s/^/  /sgm for @children;

  $str = join "\n", $str, @children;

  return $str;
};

1;

__END__

