use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::RewriteVersion;

# ABSTRACT: Get and/or rewrite module versions to match distribution version

our $VERSION = '0.017';

use Moose;
use namespace::autoclean;
use version ();

#pod =attr allow_decimal_underscore
#pod
#pod Allows use of decimal versions with underscores.  Default is false.  (Version
#pod tuples with underscores are never allowed!)
#pod
#pod =cut

has allow_decimal_underscore => (
  is  => 'ro',
  isa => 'Bool',
);

#pod =attr global
#pod
#pod If true, all occurrences of the version pattern will be replaced.  Otherwise,
#pod only the first occurrence is replaced.  Defaults to false.
#pod
#pod =cut

has global => (
  is  => 'ro',
  isa => 'Bool',
);

#pod =attr skip_version_provider
#pod
#pod If true, rely on some other mechanism for determining the "current" version
#pod instead of extracting it from the C<main_module>. Defaults to false.
#pod
#pod This enables hard-coding C<version => in C<dist.ini> among other tricks.
#pod
#pod =cut

has skip_version_provider => ( is => ro =>, lazy => 1, default => undef );

#pod =attr add_tarball_name
#pod
#pod If true, when the version is written, it will append a comment with the name of
#pod the tarball it comes from.  This helps users track down the source of a
#pod module if its name doesn't match the tarball name.  If the module is
#pod a TRIAL release, that is also in the comment.  For example:
#pod
#pod     our $VERSION = '0.010'; # from Foo-Bar-0.010.tar.gz
#pod     our $VERSION = '0.011'; # TRIAL from Foo-Bar-0.011-TRIAL.tar.gz
#pod
#pod This option defaults to false.
#pod
#pod =cut

has add_tarball_name => ( is => ro =>, lazy => 1, default => undef );

sub provide_version {
  my ($self) = @_;
  return if $self->skip_version_provider;

  # override (or maybe needed to initialize)
  return $ENV{V} if exists $ENV{V};

  my $file    = $self->zilla->main_module;
  my $content = $file->content;

  my $assign_regex = $self->assign_re();

  my ( $quote, $version ) = $content =~ m{^$assign_regex[^\n]*$}ms;

  $self->log_debug( [ 'extracted version from main module: %s', $version ] )
    if $version;
  return $version;
}

sub munge_files {
  my $self = shift;
  $self->munge_file($_) for @{ $self->found_files };
  return;
}

sub munge_file {
  my ( $self, $file ) = @_;

  return if $file->is_bytes;

  if ( $file->name =~ m/\.pod$/ ) {
    $self->log_debug( [ 'Skipping: "%s" is pod only', $file->name ] );
    return;
  }

  my $version = $self->zilla->version;

  $self->check_valid_version($version);

  if ( $self->rewrite_version( $file, $version ) ) {
    $self->log_debug( [ 'updating $VERSION assignment in %s', $file->name ] );
  }
  else {
    $self->log( [ q[Skipping: no "our $VERSION = '...'" found in "%s"], $file->name ] );
  }
  return;
}

sub rewrite_version {
  my ( $self, $file, $version ) = @_;

  my $content = $file->content;

  my $code = "our \$VERSION = '$version';";
  $code .= " # TRIAL" if $self->zilla->is_trial;

  if ( $self->add_tarball_name ) {
    my $tarball = $self->zilla->archive_filename;
    $code .= ( $self->zilla->is_trial ? "" : " #" ) . " from $tarball";
  }

  $code .= "\n\$VERSION = eval \$VERSION;"
    if $version =~ /_/ and scalar( $version =~ /\./g ) <= 1;

  my $assign_regex = $self->assign_re();

  if (
    $self->global
    ? ( $content =~ s{^$assign_regex[^\n]*$}{$code}msg )
    : ( $content =~ s{^$assign_regex[^\n]*$}{$code}ms )
    )
  {
    $file->content($content);
    return 1;
  }

  return;
}

with(
  'Dist::Zilla::Role::FileMunger' => { -version => 5 },
  'Dist::Zilla::Role::VersionProvider',
  'Dist::Zilla::Role::FileFinderUser' =>
    { default_finders => [ ':InstallModules', ':ExecFiles' ], },
  'Dist::Zilla::Plugin::BumpVersionAfterRelease::_Util',
);

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    finders => [ sort @{ $self->finder } ],
    ( map { $_ => $self->$_ ? 1 : 0 } qw(global skip_version_provider add_tarball_name) ),
  };

  return $config;
};

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=4 sts=4 sw=4 et:

__END__

