package Dist::Zilla::Role::GitConfig;

our $VERSION = '0.92';    # VERSION

# ABSTRACT: Easy role to add git_config option to most plugins

#############################################################################
# Modules

use Moose::Role;
use MooseX::Types::Moose qw(Str RegexpRef);

use List::Util qw(first);

use String::Errf qw(errf);    # We are here to save the errf: E-R-R-F!

use namespace::clean;

#############################################################################
# Requirements

requires qw(log_fatal zilla _git_config_mapping);

#############################################################################
# Attributes

has git_config => (
  is  => 'ro',
  isa => Str,
);

#############################################################################
# Pre/post-BUILD

around BUILDARGS => sub {
  my $orig = shift;
  my $self = shift;
  my %opts = @_ == 1 ? %{ $_[0] } : @_;

  my $zilla = $opts{zilla};

  if ( $opts{git_config} ) {
    my $config = first {
      $_->isa('Dist::Zilla::Plugin::Config::Git') && $_->plugin_name eq $opts{git_config}
    }
    @{ $zilla->plugins };

    $self->log_fatal( [ 'No Config::Git plugin found called "%s"', $opts{git_config} ] )
      unless $config;

    my $mapping = $self->_git_config_mapping;
    my @mvps    = $self->can('mvp_multivalue_args') ? $self->mvp_multivalue_args : ();

    # Map configuration to different attributes
    foreach my $option ( sort keys %$mapping ) {
      my $errf_str = $mapping->{$option};

      my $val = errf $errf_str, { map { $_ => $config->$_() } qw( remote local_branch remote_branch changelog ) };

      # Don't overwrite if option already exists
      unless ( exists $opts{$option} ) {
        $opts{$option} = ( grep { $_ eq $option } @mvps ) ? [$val] : $val;
      }
    }

    ### XXX: This should probably be more dynamic...
    if ( $self->can('allow_dirty') && !exists $opts{'allow_dirty'} ) {
      if ( $self->can('allow_dirty_match') ) {
        $opts{'allow_dirty'}       = [ grep { Str->check($_) } @{ $config->allow_dirty } ];
        $opts{'allow_dirty_match'} = [ grep { RegexpRef->check($_) } @{ $config->allow_dirty } ];
      }
      else {
        $opts{'allow_dirty'} = [ @{ $config->allow_dirty } ];
      }
    }
  }

  $orig->( $self, %opts );
};

42;

__END__

