package Pod::Weaver::Role::Preparer;

# ABSTRACT: something that mucks about with the input before weaving begins
$Pod::Weaver::Role::Preparer::VERSION = '4.015';
use Moose::Role;
with 'Pod::Weaver::Role::Plugin';

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod The Preparer role indicates that a plugin will be used to pre-process the input
#pod hashref before weaving begins.  The plugin must provide a C<prepare_input>
#pod method which will be called with the input hashref.  It is expected to modify
#pod the input in place.
#pod
#pod =cut

requires 'prepare_input';

1;

__END__

