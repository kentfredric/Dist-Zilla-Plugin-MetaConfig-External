## Please see file perltidy.ERR
use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::MetaConfig::External;

our $VERSION = '0.001000';

# ABSTRACT: Stuff your dzil configuration in its own file

# AUTHORITY

use Moose qw( with around has );
use JSON::MaybeXS;
with 'Dist::Zilla::Role::FileGatherer';

sub my_metadata {
  my ($self) = @_;
  my $dump = {};
  my @plugins;
  $dump->{plugins} = \@plugins;

  my $config = $self->zilla->dump_config;
  $dump->{zilla} = {
    class   => $self->zilla->meta->name,
    version => $self->zilla->VERSION,
    ( keys %$config ? ( config => $config ) : () ),
  };
  $dump->{perl} = { version => "$]", };
  for my $plugin ( @{ $self->zilla->plugins } ) {
    my $config = $plugin->dump_config;
    push @plugins,
      {
      class   => $plugin->meta->name,
      name    => $plugin->plugin_name,
      version => $plugin->VERSION,
      ( keys %$config ? ( config => $config ) : () ),
      };
  }
  $dump;
}

sub gather_files {
  my ( $self, ) = @_;
  my $zilla = $self->zilla;

  my $file = Dist::Zilla::File::FromCode->new(
    {
      name             => 'META.dzil',
      code_return_type => 'text',
      code             => sub {
        JSON::MaybeXS->new(
          pretty          => 1,
          indent          => 1,
          canonical       => 1,
          convert_blessed => 1,
        )->encode( $self->my_metadata );
      }
    }
  );
  $self->add_file($file);
}

1;

