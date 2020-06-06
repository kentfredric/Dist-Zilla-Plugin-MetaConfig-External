use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::BumpVersionAfterRelease;

# ABSTRACT: Bump module versions after distribution release

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
#pod only the first occurrence in each file is replaced.  Defaults to false.
#pod
#pod =cut

has global => (
  is  => 'ro',
  isa => 'Bool',
);

#pod =attr all_matching
#pod
#pod If true, only versions matching that of the last release will be replaced.
#pod Defaults to false.
#pod
#pod =cut

has all_matching => (
  is  => 'ro',
  isa => 'Bool',
);

#pod =attr munge_makefile_pl
#pod
#pod If there is a F<Makefile.PL> in the root of the repository, its version will be
#pod set as well.  Defaults to true.
#pod
#pod =cut

has munge_makefile_pl => (
  is      => 'ro',
  isa     => 'Bool',
  default => 1,
);

#pod =attr munge_build_pl
#pod
#pod If there is a F<Build.PL> in the root of the repository, its version will be
#pod set as well.  Defaults to true.
#pod
#pod =cut

has munge_build_pl => (
  is      => 'ro',
  isa     => 'Bool',
  default => 1,
);

has _next_version => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  init_arg => undef,
  builder  => '_build__next_version',
);

sub _build__next_version {
  my ($self) = @_;
  require Version::Next;
  my $version = $self->zilla->version;

  $self->check_valid_version($version);

  return Version::Next::next_version($version);
}

sub after_release {
  my ($self) = @_;
  $self->munge_file($_) for @{ $self->found_files };
  $self->rewrite_makefile_pl if -f "Makefile.PL" && $self->munge_makefile_pl;
  $self->rewrite_build_pl    if -f "Build.PL"    && $self->munge_build_pl;
  return;
}

sub munge_file {
  my ( $self, $file ) = @_;

  return if $file->is_bytes;

  if ( $file->name =~ m/\.pod$/ ) {
    $self->log_debug( [ 'Skipping: "%s" is pod only', $file->name ] );
    return;
  }

  if ( !-r $file->name ) {
    $self->log_debug( [ 'Skipping: "%s" not found in source', $file->name ] );
    return;
  }

  if ( $self->rewrite_version( $file, $self->_next_version ) ) {
    $self->log_debug( [ 'bumped $VERSION in %s', $file->_original_name ] );
  }
  else {
    my $version = $self->all_matching ? $self->zilla->version : '...';
    $self->log( [ q[Skipping: no "our $VERSION = '%s'" found in "%s"], $version, $file->name ] );
  }
  return;
}

sub rewrite_version {
  my ( $self, $file, $version ) = @_;

  require Path::Tiny;
  Path::Tiny->VERSION(0.061);

  my $iolayer = sprintf( ":raw:encoding(%s)", $file->encoding );

  # read source file
  my $content =
    Path::Tiny::path( $file->_original_name )->slurp( { binmode => $iolayer } );

  my $code = "our \$VERSION = '$version';";
  $code .= "\n\$VERSION = eval \$VERSION;"
    if $version =~ /_/ and scalar( $version =~ /\./g ) <= 1;

  my $assign_regex   = $self->assign_re();
  my $matching_regex = $self->matching_re( $self->zilla->version );

  if (
      $self->global       ? ( $content =~ s{^$assign_regex[^\n]*$}{$code}msg )
    : $self->all_matching ? ( $content =~ s{^$matching_regex[^\n]*$}{$code}msg )
    :                       ( $content =~ s{^$assign_regex[^\n]*$}{$code}ms )
    )
  {
    # append+truncate to preserve file mode
    Path::Tiny::path( $file->name )->append( { binmode => $iolayer, truncate => 1 }, $content );
    return 1;
  }

  return;
}

sub rewrite_makefile_pl {
  my ($self) = @_;

  my $next_version = $self->_next_version;

  require Path::Tiny;
  Path::Tiny->VERSION(0.061);

  my $path = Path::Tiny::path("Makefile.PL");

  my $content = $path->slurp_utf8;

  if ( $content =~ s{"VERSION" => "[^"]+"}{"VERSION" => "$next_version"}ms ) {
    $path->append_utf8( { truncate => 1 }, $content );
    return 1;
  }

  return;
}

sub rewrite_build_pl {
  my ($self) = @_;

  my $next_version = $self->_next_version;

  require Path::Tiny;
  Path::Tiny->VERSION(0.061);

  my $path = Path::Tiny::path("Build.PL");

  my $content = $path->slurp_utf8;

  if ( $content =~ s{"dist_version" => "[^"]+"}{"dist_version" => "$next_version"}ms ) {
    $path->append_utf8( { truncate => 1 }, $content );
    return 1;
  }

  return;
}

with(
  'Dist::Zilla::Role::AfterRelease'   => { -version        => 5 },
  'Dist::Zilla::Role::FileFinderUser' => { default_finders => [ ':InstallModules', ':ExecFiles' ], },
  'Dist::Zilla::Plugin::BumpVersionAfterRelease::_Util',
);

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    finders => [ sort @{ $self->finder } ],
    ( map { $_ => $self->$_ ? 1 : 0 } qw(global munge_makefile_pl) ),
  };

  return $config;
};

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=4 sts=4 sw=4 et:

__END__

