package Pod::Weaver::Role::Section;

# ABSTRACT: a plugin that will get a section into a woven document
$Pod::Weaver::Role::Section::VERSION = '4.015';
use Moose::Role;
with 'Pod::Weaver::Role::Plugin';

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod This role is used by plugins that will append sections to the output document.
#pod They must provide a method, C<weave_section> which will be invoked like this:
#pod
#pod   $section_plugin->weave_section($output_document, \%input);
#pod
#pod They are expected to append their output to the output document, but they are
#pod free to behave differently if it's needed to do something really cool.
#pod
#pod =cut

requires 'weave_section';

1;

__END__

