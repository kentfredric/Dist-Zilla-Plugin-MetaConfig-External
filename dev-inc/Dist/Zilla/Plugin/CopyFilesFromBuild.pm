use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::CopyFilesFromBuild;

# ABSTRACT: Copy (or move) specific files after building (for SCM inclusion, etc.)
$Dist::Zilla::Plugin::CopyFilesFromBuild::VERSION = '0.170880';
use Moose;
use MooseX::Has::Sugar;
with qw/ Dist::Zilla::Role::AfterBuild /;

use File::Copy ();
use IO::File;
use List::Util 1.33 qw( any );
use Path::Tiny;
use Set::Scalar;

# accept some arguments multiple times.
sub mvp_multivalue_args { qw{ copy move } }

has copy => (
  ro, lazy,
  isa     => 'ArrayRef[Str]',
  default => sub { [] },
);

has move => (
  ro, lazy,
  isa     => 'ArrayRef[Str]',
  default => sub { [] },
);

sub after_build {
  my $self = shift;
  my $data = shift;

  my $build_root = $data->{build_root};
  for my $path ( @{ $self->copy } ) {
    if ( $path eq '' ) {
      next;
    }
    my $src  = path($build_root)->child($path);
    my $dest = path( $self->zilla->root )->child($path);
    if ( -e $src ) {
      File::Copy::copy "$src", "$dest"
        or $self->log_fatal("Unable to copy $src to $dest: $!");
      $self->log("Copied $src to $dest");
    }
    else {
      $self->log_fatal("Cannot copy $path from build: file does not exist");
    }
  }

  my $moved_something = 0;

  for my $path ( @{ $self->move } ) {
    if ( $path eq '' ) {
      next;
    }
    my $src  = path($build_root)->child($path);
    my $dest = path( $self->zilla->root )->child($path);
    if ( -e $src ) {
      File::Copy::move "$src", "$dest"
        or $self->log_fatal("Unable to move $src to $dest: $!");
      $moved_something++;
      $self->log("Moved $src to $dest");
    }
    else {
      $self->log_fatal("Cannot move $path from build: file does not exist");
    }
  }

  if ($moved_something) {

    # These are probably horrible hacks. If so, please tell me a
    # better way.
    $self->_prune_moved_files();
    $self->_filter_manifest($build_root);
  }
}

sub _prune_moved_files {
  my ( $self, ) = @_;
  for my $file ( @{ $self->zilla->files } ) {
    next unless any { $file->name eq $_ } @{ $self->move };

    $self->log_debug( [ 'pruning moved file %s', $file->name ] );

    $self->zilla->prune_file($file);
  }
}

sub _read_manifest {
  my ( $self, $manifest_filename ) = @_;
  my $input = IO::File->new($manifest_filename);
  my @lines = $input->getlines;
  chomp @lines;
  return @lines;
}

sub _write_manifest {
  my ( $self, $manifest_filename, @contents ) = @_;
  my $output = IO::File->new( $manifest_filename, 'w' );
  $output->print( join( "\n", ( sort @contents ) ), "\n" );
}

sub _filter_manifest {
  my ( $self, $build_root ) = @_;
  if ( @{ $self->move } ) {
    my $manifest_file = path($build_root)->child('MANIFEST');
    return unless -e $manifest_file;
    my $files          = Set::Scalar->new( $self->_read_manifest($manifest_file) );
    my $moved_files    = Set::Scalar->new( @{ $self->move } );
    my $filtered_files = $files->difference($moved_files);
    $self->log_debug("Removing moved files from MANIFEST");
    $self->_write_manifest( $manifest_file, $filtered_files->members );
  }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;    # Magic true value required at end of module

__END__

