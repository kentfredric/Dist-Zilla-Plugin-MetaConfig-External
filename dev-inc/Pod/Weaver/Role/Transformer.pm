package Pod::Weaver::Role::Transformer;

# ABSTRACT: something that restructures a Pod5 document
$Pod::Weaver::Role::Transformer::VERSION = '4.015';
use Moose::Role;
with 'Pod::Weaver::Role::Plugin';

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod The Transformer role indicates that a plugin will be used to pre-process the input
#pod hashref's Pod document before weaving begins.  The plugin must provide a
#pod C<transform_document> method which will be called with the input Pod document.
#pod It is expected to modify the input in place.
#pod
#pod =cut

requires 'transform_document';

1;

__END__

