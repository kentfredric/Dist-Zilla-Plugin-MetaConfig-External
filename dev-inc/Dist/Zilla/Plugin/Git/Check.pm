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

package Dist::Zilla::Plugin::Git::Check;

# ABSTRACT: Check your git repository before releasing

our $VERSION = '2.043';

use Moose;
use namespace::autoclean 0.09;
use Moose::Util::TypeConstraints qw(enum);
use MooseX::Types::Moose qw(Bool);

with 'Dist::Zilla::Role::AfterBuild', 'Dist::Zilla::Role::BeforeRelease', 'Dist::Zilla::Role::Git::Repo';
with 'Dist::Zilla::Role::Git::DirtyFiles', 'Dist::Zilla::Role::GitConfig';

has build_warnings => ( is => 'ro', isa => Bool, default => 0 );

has untracked_files => ( is => 'ro', isa => enum( [qw(die warn ignore)] ), default => 'die' );

sub _git_config_mapping {
  +{ changelog => '%{changelog}s', };
}

# -- public methods

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {

    # build_warnings does not affect the build outcome; do not need to track it
    untracked_files => $self->untracked_files,
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

sub _perform_checks {
  my ( $self, $log_method ) = @_;

  my @issues;
  my $git = $self->git;
  my @output;

  # fetch current branch
  my ($branch) =
    map { /^\*\s+(.+)/ ? $1 : () } $git->branch;

  # check if some changes are staged for commit
  @output = $git->diff( { cached => 1, 'name-status' => 1 } );
  if (@output) {
    push @issues, @output . " staged change" . ( @output == 1 ? '' : 's' );

    my $errmsg = "branch $branch has some changes staged for commit:\n" . join "\n", map { "\t$_" } @output;
    $self->$log_method($errmsg);
  }

  # everything but files listed in allow_dirty should be in a
  # clean state
  @output = $self->list_dirty_files($git);
  if (@output) {
    push @issues, @output . " uncommitted file" . ( @output == 1 ? '' : 's' );

    my $errmsg = "branch $branch has some uncommitted files:\n" . join "\n", map { "\t$_" } @output;
    $self->$log_method($errmsg);
  }

  # no files should be untracked
  @output = $git->ls_files( { others => 1, 'exclude-standard' => 1 } );
  if (@output) {
    push @issues, @output . " untracked file" . ( @output == 1 ? '' : 's' );

    my $untracked = $self->untracked_files;
    if ( $untracked ne 'ignore' ) {

      # If $log_method is log_fatal, switch to log unless
      # untracked files are fatal.  If $log_method is already log,
      # this is a no-op.
      $log_method = 'log' unless $untracked eq 'die';

      my $errmsg = "branch $branch has some untracked files:\n" . join "\n", map { "\t$_" } @output;
      $self->$log_method($errmsg);
    }
  }

  if (@issues) {
    $self->log( "branch $branch has " . join( ', ', @issues ) );
  }
  else {
    $self->log("branch $branch is in a clean state");
  }
}    # end _perform_checks

sub after_build {
  my $self = shift;

  $self->_perform_checks('log') if $self->build_warnings;
}

sub before_release {
  my $self = shift;

  $self->_perform_checks('log_fatal');
}

__PACKAGE__->meta->make_immutable;
1;

__END__

