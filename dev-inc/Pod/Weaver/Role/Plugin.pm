package Pod::Weaver::Role::Plugin;

# ABSTRACT: a Pod::Weaver plugin
$Pod::Weaver::Role::Plugin::VERSION = '4.015';
use Moose::Role;

use Params::Util qw(_HASHLIKE);

use namespace::autoclean;

#pod =head1 IMPLEMENTING
#pod
#pod This is the most basic role that all plugins must perform.
#pod
#pod =attr plugin_name
#pod
#pod This name must be unique among all other plugins loaded into a weaver.  In
#pod general, this will be set up by the configuration reader.
#pod
#pod =cut

has plugin_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

#pod =attr weaver
#pod
#pod This is the Pod::Weaver object into which the plugin was loaded.  In general,
#pod this will be set up when the weaver is instantiated from config.
#pod
#pod =cut

has weaver => (
  is       => 'ro',
  isa      => 'Pod::Weaver',
  required => 1,
  weak_ref => 1,
);

has logger => (
  is      => 'ro',
  lazy    => 1,
  handles => [qw(log log_debug log_fatal)],
  default => sub {
    $_[0]->weaver->logger->proxy(
      {
        proxy_prefix => '[' . $_[0]->plugin_name . '] ',
      }
    );
  },
);

1;

__END__

