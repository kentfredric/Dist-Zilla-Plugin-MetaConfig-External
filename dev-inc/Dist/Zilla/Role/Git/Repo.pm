#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package Dist::Zilla::Role::Git::Repo;

# ABSTRACT: Provide repository information for Git plugins

our $VERSION = '2.043';

use Moose::Role;
use MooseX::Types::Moose qw(Str Maybe);
use namespace::autoclean;

has 'repo_root' => ( is => 'ro', isa => Str, default => '.' );

#pod =method current_git_branch
#pod
#pod   $branch = $plugin->current_git_branch;
#pod
#pod The current branch in the repository, or C<undef> if the repository
#pod has a detached HEAD.  Note: This value is cached; it will not
#pod be updated if the branch is changed during the run.
#pod
#pod =cut

has current_git_branch => (
  is       => 'ro',
  isa      => Maybe [Str],
  lazy     => 1,
  builder  => '_build_current_git_branch',
  init_arg => undef,                         # Not configurable
);

sub _build_current_git_branch {
  my $self = shift;

  # Git 1.7+ allows "rev-parse --abbrev-ref HEAD", but we want to support 1.5.4
  my ($branch) = $self->git->RUN(qw(symbolic-ref -q HEAD));

  no warnings 'uninitialized';
  undef $branch unless $branch =~ s!^refs/heads/!!;

  $branch;
}    # end _build_current_git_branch

#pod =method git
#pod
#pod   $git = $plugin->git;
#pod
#pod This method returns a Git::Wrapper object for the C<repo_root>
#pod directory, constructing one if necessary.  The object is shared
#pod between all plugins that consume this role (if they have the same
#pod C<repo_root>).
#pod
#pod =cut

my %cached_wrapper;

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    repo_root   => $self->repo_root,
    git_version => $self->git->version,
  };

  return $config;
};

sub git {
  my $root = shift->repo_root;

  $cached_wrapper{$root} ||= do {
    require Git::Wrapper;
    Git::Wrapper->new($root);
  };
}

1;

__END__

