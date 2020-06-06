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

package Dist::Zilla::Plugin::Git::Commit;

# ABSTRACT: Commit dirty files

our $VERSION = '2.043';

use namespace::autoclean;
use File::Temp qw{ tempfile };
use Moose;
use MooseX::Has::Sugar;
use MooseX::Types::Moose qw{ Str };
use MooseX::Types::Path::Tiny 0.010 qw{ Paths };
use Path::Tiny 0.048 qw();    # subsumes
use Cwd;

with 'Dist::Zilla::Role::AfterRelease', 'Dist::Zilla::Role::Git::Repo';
with 'Dist::Zilla::Role::Git::DirtyFiles';
with 'Dist::Zilla::Role::Git::StringFormatter';
with 'Dist::Zilla::Role::GitConfig';

sub _git_config_mapping {
  +{ changelog => '%{changelog}s', };
}

# -- attributes

has commit_msg   => ( ro, isa => Str,   default => 'v%v%n%n%c' );
has add_files_in => ( ro, isa => Paths, coerce  => 1, default => sub { [] } );

# -- public methods

sub mvp_multivalue_args { qw( add_files_in ) }

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    commit_msg   => $self->commit_msg,
    add_files_in => [ sort @{ $self->add_files_in } ],
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

sub after_release {
  my $self = shift;

  my $git = $self->git;
  my @output;

  # check if there are dirty files that need to be committed.
  # at this time, we know that only those 2 files may remain modified,
  # otherwise before_release would have failed, ending the release
  # process.
  @output = sort { lc $a cmp lc $b } $self->list_dirty_files( $git, 1 );

  # add any other untracked files to the commit list
  if ( @{ $self->add_files_in } ) {
    my @untracked_files = $git->ls_files( { others => 1, 'exclude-standard' => 1 } );
    foreach my $f (@untracked_files) {
      foreach my $path ( @{ $self->add_files_in } ) {
        if ( Path::Tiny::path($path)->subsumes($f) ) {
          push( @output, $f );
          last;
        }
      }
    }
  }

  # if nothing to commit, we're done!
  return unless @output;

  # write commit message in a temp file
  my ( $fh, $filename ) = tempfile( getcwd . '/DZP-git.XXXX', UNLINK => 1 );
  binmode $fh, ':utf8' unless Dist::Zilla->VERSION < 5;
  print $fh $self->get_commit_message;
  close $fh;

  # commit the files in git
  $git->add(@output);
  $self->log_debug($_) for $git->commit( { file => $filename } );
  $self->log("Committed @output");
}

#pod =method get_commit_message
#pod
#pod This method returns the commit message.  The default implementation
#pod reads the Changes file to get the list of changes in the just-released version.
#pod
#pod =cut

sub get_commit_message {
  my $self = shift;

  return $self->_format_string( $self->commit_msg );
}    # end get_commit_message

__PACKAGE__->meta->make_immutable;
1;

__END__

