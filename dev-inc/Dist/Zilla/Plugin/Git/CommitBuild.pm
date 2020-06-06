#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use 5.008;
use strict;
use warnings;

package Dist::Zilla::Plugin::Git::CommitBuild;

# ABSTRACT: Check in build results on separate branch

our $VERSION = '2.043';

use Git::Wrapper 0.021 ();    # need -STDIN
use IPC::Open3;
use IPC::System::Simple;      # required for Fatalised/autodying system
use File::chdir;
use File::Spec::Functions qw/ rel2abs catfile /;
use File::Temp;
use Moose;
use namespace::autoclean;
use Path::Tiny qw();
use MooseX::Types::Path::Tiny qw( Path );
use MooseX::Has::Sugar;
use MooseX::Types::Moose qw{ Str Bool };
use Cwd qw(abs_path);
use Try::Tiny;

use String::Formatter (
  method_stringf => {
    -as   => '_format_branch',
    codes => {
      b => sub { shift->_source_branch },
    },
  },
  method_stringf => {
    -as   => '_format_message',
    codes => {
      b => sub { shift->_source_branch },
      h => sub { ( shift->git->rev_parse( '--short', 'HEAD' ) )[0] },
      H => sub { ( shift->git->rev_parse('HEAD') )[0] },
      t => sub { shift->zilla->is_trial ? '-TRIAL' : '' },
      v => sub { shift->zilla->version },
    }
  }
);

# debugging...
#use Smart::Comments '###';

with 'Dist::Zilla::Role::AfterBuild', 'Dist::Zilla::Role::AfterRelease', 'Dist::Zilla::Role::Git::Repo';

# -- attributes

has branch          => ( ro, isa => Str, default  => 'build/%b', required => 1 );
has release_branch  => ( ro, isa => Str, required => 0 );
has message         => ( ro, isa => Str, default  => 'Build results of %h (on %b)', required => 1 );
has release_message => ( ro, isa => Str, lazy     => 1, builder => '_build_release_message' );
has build_root => ( rw, coerce => 1, isa => Path );

has _source_branch => (
  is       => 'ro',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
  default  => sub {
    ( $_[0]->git->name_rev( '--name-only', 'HEAD' ) )[0];
  },
);

has multiple_inheritance => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
);

# -- attribute builders

sub _build_release_message { return shift->message; }

# -- role implementation

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    ( map { $_ => $self->$_ } qw(branch release_branch message release_message build_root) ),
    multiple_inheritance => $self->multiple_inheritance ? 1 : 0,
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

sub after_build {
  my ( $self, $args ) = @_;

  # because the build_root mysteriously change at
  # the 'after_release' stage
  $self->build_root( $args->{build_root} );

  $self->_commit_build( $args, $self->branch, $self->message );
}

sub after_release {
  my ( $self, $args ) = @_;

  $self->_commit_build( $args, $self->release_branch, $self->release_message );
}

sub _commit_build {
  my ( $self, undef, $branch, $message ) = @_;

  return unless $branch;

  my $dir = Path::Tiny->tempdir( CLEANUP => 1 );
  my $src = $self->git;

  my $target_branch = _format_branch( $branch, $self );

  for my $file ( @{ $self->zilla->files } ) {
    my ( $name, $content ) = (
      $file->name,
      (
        Dist::Zilla->VERSION < 5
        ? $file->content
        : $file->encoded_content
      )
    );
    my ($outfile) = $dir->child($name);
    $outfile->parent->mkpath();
    $outfile->spew_raw($content);
    chmod $file->mode, "$outfile" or die "couldn't chmod $outfile: $!";
  }

  # returns the sha1 of the created tree object
  my $tree = $self->_create_tree( $src, $dir );

  my ($last_build_tree) = try { $src->rev_parse("$target_branch^{tree}") };
  $last_build_tree ||= 'none';

  ### $last_build_tree
  if ( $tree eq $last_build_tree ) {

    $self->log("No changes since the last build; not committing");
    return;
  }

  my @parents = (
    ( $self->_source_branch ) x $self->multiple_inheritance,
    grep {
      eval { $src->rev_parse( { 'q' => 1, 'verify' => 1 }, $_ ) }
    } $target_branch
  );

  ### @parents

  my $this_message = _format_message( $message, $self );
  my @commit       = $src->commit_tree( { -STDIN => $this_message }, $tree, map { ( '-p' => $_ ) } @parents );

  ### @commit
  $src->update_ref( 'refs/heads/' . $target_branch, $commit[0] );
}

sub _create_tree {
  my ( $self, $repo, $fs_obj ) = @_;

  ### called with: "$fs_obj"
  if ( !$fs_obj->is_dir ) {

    my ($sha) = $repo->hash_object( { w => 1 }, "$fs_obj" );
    ### hashed: "$sha $fs_obj"
    return $sha;
  }

  my @entries;
  for my $obj ( $fs_obj->children ) {

    ### working on: "$obj"
    my $sha  = $self->_create_tree( $repo, $obj );
    my $mode = sprintf( '%o', $obj->stat->mode );    # $obj->is_dir ? '040000' : '
    my $type = $obj->is_dir ? 'tree' : 'blob';
    my $name = $obj->basename;

    push @entries, "$mode $type $sha\t$name";
  }

  ### @entries

  my ($sha) = $repo->mktree( { -STDIN => join( "\n", @entries, q{} ) } );

  return $sha;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

