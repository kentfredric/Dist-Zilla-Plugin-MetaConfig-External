use strict;
use warnings;

package Dist::Zilla::Plugin::RunExtraTests;

# ABSTRACT: support running xt tests via dzil test

our $VERSION = '0.029';

# Dependencies
use Dist::Zilla 4.3 ();
use Moose 2;
use namespace::autoclean 0.09;

# extends, roles, attributes, etc.

with 'Dist::Zilla::Role::TestRunner';

# methods

sub test {
  my ( $self, $target, $arg ) = @_;

  my %dirs;
  @dirs{ grep { -d } glob('xt/*') } = ();
  delete $dirs{'xt/author'}  unless $ENV{AUTHOR_TESTING};
  delete $dirs{'xt/smoke'}   unless $ENV{AUTOMATED_TESTING};
  delete $dirs{'xt/release'} unless $ENV{RELEASE_TESTING};

  my @dirs  = sort keys %dirs;
  my @files = grep { -f } glob('xt/*');
  return unless @dirs or @files;

  # If the dist hasn't been built yet, then build it:
  unless ( -d 'blib' ) {
    my @builders = @{ $self->zilla->plugins_with( -BuildRunner ) };
    die "no BuildRunner plugins specified" unless @builders;
    $_->build for @builders;
    die "no blib; failed to build properly?" unless -d 'blib';
  }

  my $jobs =
      $arg && exists $arg->{jobs} ? $arg->{jobs}
    : $self->can('default_jobs')  ? $self->default_jobs
    :                               1;
  my @v = $self->zilla->logger->get_debug ? ('-v') : ();

  require App::Prove;
  App::Prove->VERSION('3.00');

  my $app = App::Prove->new;

  $self->log_debug( [ 'running prove with args: %s', join( ' ', '-j', $jobs, @v, qw/-b xt/ ) ] );
  $app->process_args( '-j', $jobs, @v, qw/-b xt/ );

  $self->log_debug( [ 'running prove with args: %s', join( ' ', '-j', $jobs, @v, qw/-r -b/, @dirs ) ] );
  $app->process_args( '-j', $jobs, @v, qw/-r -b/, @dirs );
  $app->run or $self->log_fatal("Fatal errors in xt tests");
  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

