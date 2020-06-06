use strict;
use warnings;

package Dist::Zilla::Role::RepoFileInjector;    # git description: v0.006-2-gaf009ca

# ABSTRACT: Create files outside the build directory
# KEYWORDS: plugin distribution generate create file repository
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.007';

use Moose::Role;

use MooseX::Types qw(enum role_type);
use MooseX::Types::Moose qw(ArrayRef Str Bool);
use Path::Tiny 0.022;
use Cwd ();
use namespace::clean;

has repo_root => (
  is        => 'ro',
  isa       => Str,
  predicate => '_has_repo_root',
  lazy      => 1,
  default   => sub { path( Cwd::getcwd() )->stringify },
);

has allow_overwrite => (
  is      => 'ro',
  isa     => Bool,
  default => 1,
);

has _repo_files => (
  isa     => ArrayRef [ role_type('Dist::Zilla::Role::File') ],
  lazy    => 1,
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    __push_repo_file => 'push',
    _repo_files      => 'elements',
  },
);

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    version         => $VERSION,
    allow_overwrite => ( $self->allow_overwrite ? 1 : 0 ),
    repo_root       => ( $self->_has_repo_root ? $self->repo_root : '.' ),
  };
  return $config;
};

sub add_repo_file {
  my ( $self, $file ) = @_;

  my ( $pkg, undef, $line ) = caller;
  if ( $file->can('_set_added_by') ) {
    $file->_set_added_by( sprintf( "%s (%s line %s)", $self->plugin_name, $pkg, $line ) );
  }
  else {
    # as done in Dist::Zilla::Role::FileInjector 4.300039
    $file->meta->get_attribute('added_by')->set_value( $file, sprintf( "%s (%s line %s)", $self->plugin_name, $pkg, $line ), );
  }

  $self->log_debug( [ 'adding file %s', $file->name ] );

  $self->__push_repo_file($file);
}

sub write_repo_files {
  my $self = shift;

  foreach my $file ( $self->_repo_files ) {
    my $filename = path( $file->name );
    my $abs_filename =
      $filename->is_relative
      ? path( $self->repo_root )->child( $file->name )->stringify
      : $file->name;

    if ( -e $abs_filename and $self->allow_overwrite ) {
      $self->log_debug( [ 'removing pre-existing %s', $abs_filename ] );
      unlink $abs_filename;
    }
    $self->log_fatal( [ '%s already exists (allow_overwrite = 0)', $abs_filename ] ) if -e $abs_filename;

    $self->log_debug( [ 'writing out %s%s', $file->name, $filename->is_relative ? ' to ' . $self->repo_root : '' ] );

    Carp::croak("attempted to write $filename multiple times") if -e $filename;
    $filename->touchpath;

    # handle dzil v4 files by assuming no (or latin1) encoding
    my $encoded_content = $file->can('encoded_content') ? $file->encoded_content : $file->content;

    $filename->spew_raw($encoded_content);
    chmod $file->mode, "$filename" or die "couldn't chmod $filename: $!";
  }
}

1;

__END__

