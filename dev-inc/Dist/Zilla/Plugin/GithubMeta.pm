package Dist::Zilla::Plugin::GithubMeta;
$Dist::Zilla::Plugin::GithubMeta::VERSION = '0.54';

# ABSTRACT: Automatically include GitHub meta information in META.yml

use strict;
use warnings;
use Moose;
with 'Dist::Zilla::Role::MetaProvider';

use MooseX::Types::URI qw[Uri];
use Cwd;
use Try::Tiny;

use namespace::autoclean;

has 'homepage' => (
  is     => 'ro',
  isa    => Uri,
  coerce => 1,
);

has 'remote' => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { ['origin'] },
);

has 'issues' => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has 'user' => (
  is        => 'rw',
  isa       => 'Str',
  predicate => '_has_user',
);

has 'repo' => (
  is        => 'rw',
  isa       => 'Str',
  predicate => '_has_repo',
);

sub mvp_multivalue_args { qw(remote) }

sub _acquire_repo_info {
  my ($self) = @_;

  return if $self->_has_user and $self->_has_repo;

  return unless _under_git();

  require IPC::Cmd;
  return unless IPC::Cmd::can_run('git');

  {
    my $gitver = `git version`;
    my ($ver) = $gitver =~ m!git version ([0-9.]+(\.msysgit)?[0-9.]+)!;
    $ver =~ s![^\d._]!!g;
    $ver =~ s!\.$!!;
    $ver =~ s!\.+!.!g;
    chomp $gitver;
    require version;
    my $ver_obj = try { version->parse($ver) }
    catch { die "'$gitver' not parsable as '$ver': $_" };

    if ( $ver_obj < version->parse('1.5.0') ) {
      warn "$gitver is too low, 1.5.0 or above is required\n";
      return;
    }
  }

  my $git_url;
remotelist: for my $remote ( @{ $self->remote } ) {

    # Missing remotes expand to the same value as they were input
    # ( git version 1.7.7 -- kentnl -- 2011-10-08 )
    unless ( $git_url = $self->_url_for_remote($remote) and $remote ne $git_url ) {
      $self->log( [ 'A remote named \'%s\' was specified, but does not appear to exist.', $remote ] );
      undef $git_url;
      next remotelist;
    }
    last if $git_url =~ m!\bgithub\.com[:/]!;    # Short Circuit on Github repository

    # Not a Github Repository?
    $self->log( [ 'Specified remote \'%s\' expanded to \'%s\', which is not a github repository URL', $remote, $git_url, ] );

    undef $git_url;
  }

  return unless $git_url;

  my ( $user, $repo ) = $git_url =~ m{
    github\.com              # the domain
    [:/] ([^/]+)             # the username (: for ssh, / for http)
    /    ([^/]+?) (?:\.git)? # the repo name
    $
  }ix;

  $self->log( [ 'No user could be discerned from URL: \'%s\'',       $git_url ] ) unless defined $user;
  $self->log( [ 'No repository could be discerned from URL: \'%s\'', $git_url ] ) unless defined $repo;

  return unless defined $user and defined $repo;

  $self->user($user) unless $self->_has_user;
  $self->repo($repo) unless $self->_has_repo;
}

sub metadata {
  my $self = shift;

  $self->_acquire_repo_info;

  unless ( $self->_has_user and $self->_has_repo ) {
    $self->log( ['skipping meta.resources.repository creation'] );
    return;
  }

  my $gh_url   = sprintf 'https://github.com/%s/%s', $self->user, $self->repo;
  my $bug_url  = "$gh_url/issues";
  my $repo_url = "$gh_url.git";

  my $home_url = $self->homepage ? $self->homepage->as_string : $gh_url;

  return {
    resources => {
      homepage   => $home_url,
      repository => {
        type => 'git',
        url  => $repo_url,
        web  => $gh_url,
      },
      ( $self->issues ? ( bugtracker => { web => $bug_url } ) : () ),
    }
  };
}

sub _url_for_remote {
  my ( $self, $remote ) = @_;
  local $ENV{LC_ALL} = 'C';
  local $ENV{LANG}   = 'C';
  my @remote_info = `git remote show -n $remote`;
  for my $line (@remote_info) {
    chomp $line;
    if ( $line =~ /^\s*(?:Fetch)?\s*URL:\s*(.*)/ ) {
      return $1;
    }
  }
  return;
}

sub _under_git {
  return 1 if -e '.git';
  my $cwd   = getcwd;
  my $last  = $cwd;
  my $found = 0;
  while (1) {
    chdir '..' or last;
    my $current = getcwd;
    last if $last eq $current;
    $last = $current;
    if ( -e '.git' ) {
      $found = 1;
      last;
    }
  }
  chdir $cwd;
  return $found;
}

__PACKAGE__->meta->make_immutable;
no Moose;

qq[1 is the loneliest number];

__END__

