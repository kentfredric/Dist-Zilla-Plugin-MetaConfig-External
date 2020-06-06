package Pod::Weaver::Role::Finalizer;

# ABSTRACT: something that goes back and finishes up after main weaving is over
$Pod::Weaver::Role::Finalizer::VERSION = '4.015';
use Moose::Role;
with 'Pod::Weaver::Role::Plugin';

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod The Finalizer role indicates that a plugin will be used to post-process the
#pod output document hashref after section weaving is completed.  The plugin must
#pod provide a C<finalize_document> method which will be called as follows:
#pod
#pod   $finalizer_plugin->finalize_document($document, \%input);
#pod
#pod =cut

requires 'finalize_document';

1;

__END__

