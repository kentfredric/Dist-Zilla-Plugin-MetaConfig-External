use strict;
use warnings;

package Dist::Zilla::Plugin::GenerateFile::FromShareDir;    # git description: v0.012-6-g2cf801b

# vim: set ts=8 sts=4 sw=4 tw=115 et :
# ABSTRACT: Create files in the repository or in the build, based on a template located in a dist sharedir
# KEYWORDS: plugin distribution generate create file sharedir template

our $VERSION = '0.013';

use Moose;
with(
  'Dist::Zilla::Role::FileGatherer',
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::TextTemplate',
  'Dist::Zilla::Role::RepoFileInjector' => { -version => '0.006' },
  'Dist::Zilla::Role::AfterBuild',
  'Dist::Zilla::Role::AfterRelease',
);

use MooseX::SlurpyConstructor 1.2;
use Moose::Util 'find_meta';
use File::ShareDir 'dist_file';
use Path::Tiny 0.04;
use Encode;
use Moose::Util::TypeConstraints 'enum';
use namespace::autoclean;

has dist => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => '-dist',
  lazy     => 1,
  default  => sub { ( my $dist = find_meta(shift)->name ) =~ s/::/-/g; $dist },
);

has filename => (
  init_arg => '-destination_filename',
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has source_filename => (
  init_arg => '-source_filename',
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  default  => sub { shift->filename },
);

has encoding => (
  init_arg => '-encoding',
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  default  => 'UTF-8',
);

has location => (
  is       => 'ro',
  isa      => enum( [qw(build root)] ),
  lazy     => 1,
  default  => 'build',
  init_arg => '-location',
);

has phase => (
  is       => 'ro',
  isa      => enum( [qw(build release)] ),
  lazy     => 1,
  default  => 'build',
  init_arg => '-phase',
);

has _extra_args => (
  isa      => 'HashRef[Str]',
  init_arg => undef,
  lazy     => 1,
  default  => sub { {} },
  traits   => ['Hash'],
  handles  => { _extra_args => 'elements' },
  slurpy   => 1,
);

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;

  my $args = $class->$orig(@_);
  $args->{'-destination_filename'} = delete $args->{'-filename'} if exists $args->{'-filename'};

  return $args;
};

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {

    # XXX FIXME - it seems META.* does not like the leading - in field
    # names! something is wrong with the serialization process.
    'dist'                 => $self->dist,
    'encoding'             => $self->encoding,
    'source_filename'      => $self->source_filename,
    'destination_filename' => $self->filename,
    'location'             => $self->location,
    $self->location eq 'root'     ? ( 'phase' => $self->phase ) : (),
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION )     : (),
    $self->_extra_args,
  };
  return $config;
};

sub gather_files {
  my $self = shift;

  my $file_path;
  if ( $self->dist eq $self->zilla->name ) {
    if ( my $sharedir = $self->zilla->_share_dir_map->{dist} ) {
      $file_path = path( $sharedir, $self->source_filename )->stringify;
    }
  }
  else {
    # this should die if the file does not exist
    $file_path = dist_file( $self->dist, $self->source_filename );
  }

  $self->log_debug( [ 'using template in %s', $file_path ] );

  my $content = path($file_path)->slurp_raw;
  $content = Encode::decode( $self->encoding, $content, Encode::FB_CROAK() );

  require Dist::Zilla::File::InMemory;
  my $file = Dist::Zilla::File::InMemory->new(
    name     => $self->filename,
    encoding => $self->encoding,    # only used in Dist::Zilla 5.000+
    content  => $content,
  );

  if ( $self->location eq 'build' ) {
    if ( $self->phase eq 'release' ) {

      # we can't generate a file only in the release without doing it now,
      # which would add it for all builds. Consequently this config combo is
      # nonsensical and suggests the user is misunderstanding something.
      $self->log('nonsensical and impossible combination of configs: -location = build, -phase = release');
      return;
    }

    $self->add_file($file);
  }
  else {
    # root eq $self->location
    $self->add_repo_file($file);
  }
  return;
}

around munge_files => sub {
  my ( $orig, $self, @args ) = @_;

  return $self->$orig(@args) if $self->location eq 'build';

  for my $file ( $self->_repo_files ) {
    if ( $file->can('is_bytes') and $file->is_bytes ) {
      $self->log_debug( [ '%s has \'bytes\' encoding, skipping...', $file->name ] );
      next;
    }
    $self->munge_file($file);
  }
};

sub munge_file {
  my ( $self, $file ) = @_;

  return unless $file->name eq $self->filename;
  $self->log_debug( [ 'updating contents of %s in memory', $file->name ] );

  my $content = $self->fill_in_string(
    $file->content,
    {
      $self->_extra_args,    # must be first
      dist   => \( $self->zilla ),
      plugin => \$self,
    },
  );

  # older Dist::Zilla wrote out all files :raw, so we need to encode manually here.
  $content = Encode::encode( $self->encoding, $content, Encode::FB_CROAK() ) if not $file->can('encoded_content');

  $file->content($content);
}

sub after_build {
  my $self = shift;
  $self->write_repo_files if $self->phase eq 'build';
}

sub after_release {
  my $self = shift;
  $self->write_repo_files if $self->phase eq 'release';
}

__PACKAGE__->meta->make_immutable;

__END__

