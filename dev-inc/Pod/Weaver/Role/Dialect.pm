package Pod::Weaver::Role::Dialect;

# ABSTRACT: something that translates Pod subdialects to standard Pod5
$Pod::Weaver::Role::Dialect::VERSION = '4.015';
use Moose::Role;
with 'Pod::Weaver::Role::Plugin';

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod The Dialect role indicates that a plugin will be used to pre-process the input
#pod Pod document before weaving begins.  The plugin must provide a
#pod C<translate_dialect> method which will be called with the input hashref's
#pod C<pod_document> entry.  It is expected to modify the document in place.
#pod
#pod =cut

requires 'translate_dialect';

1;

__END__

