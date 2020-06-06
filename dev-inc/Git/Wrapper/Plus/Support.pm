use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Support;

our $VERSION = '0.004011';

# ABSTRACT: Determine what versions of things support what

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

has 'git' => ( is => ro =>, required => 1 );

has 'versions' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_versions {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Versions;
  return Git::Wrapper::Plus::Versions->new( git => $self->git );
}

has 'commands' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_commands {
  require Git::Wrapper::Plus::Support::Commands;
  return Git::Wrapper::Plus::Support::Commands->new();
}

has 'behaviors' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_behaviors {
  require Git::Wrapper::Plus::Support::Behaviors;
  return Git::Wrapper::Plus::Support::Behaviors->new();
}

has 'arguments' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_arguments {
  require Git::Wrapper::Plus::Support::Arguments;
  return Git::Wrapper::Plus::Support::Arguments->new();
}

sub supports_command {
  my ( $self, $command ) = @_;
  return unless $self->commands->has_entry($command);
  return 1 if $self->commands->entry_supports( $command, $self->versions );
  return 0;
}

sub supports_behavior {
  my ( $self, $beh ) = @_;
  return unless $self->behaviors->has_entry($beh);
  return 1 if $self->behaviors->entry_supports( $beh, $self->versions );
  return 0;
}

sub supports_argument {
  my ( $self, $command, $argument ) = @_;
  return unless $self->arguments->has_argument( $command, $argument );
  return 1 if $self->arguments->argument_supports( $command, $argument, $self->versions );
  return 0;

}

no Moo;
1;

__END__

