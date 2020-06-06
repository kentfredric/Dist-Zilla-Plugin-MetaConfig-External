package Pod::Elemental::Transformer;

# ABSTRACT: something that transforms a node tree into a new tree
$Pod::Elemental::Transformer::VERSION = '0.103004';
use Moose::Role;

use namespace::autoclean;

requires 'transform_node';

#pod =head1 OVERVIEW
#pod
#pod Pod::Elemental::Transformer is a role to be composed by anything that takes a
#pod node and messes around with its contents.  This includes transformers to
#pod implement Pod dialects, Pod tree nesting strategies, and Pod document
#pod rewriters.
#pod
#pod A class including this role must implement the following methods:
#pod
#pod =method transform_node
#pod
#pod   my $node = $nester->transform_node($node);
#pod
#pod This method alters the given node and returns it.  Apart from that, the sky is
#pod the limit.
#pod
#pod =cut

1;

__END__

