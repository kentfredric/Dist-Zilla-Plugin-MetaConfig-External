#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package Dist::Zilla::Plugin::Git::GatherDir;

# ABSTRACT: Gather all tracked files in a Git working directory

our $VERSION = '2.043';

use Moose;
extends 'Dist::Zilla::Plugin::GatherDir' => { -version => 4.200016 };    # exclude_match

#pod =head1 SYNOPSIS
#pod
#pod In your F<dist.ini>:
#pod
#pod     [Git::GatherDir]
#pod     root = .                     ; this is the default
#pod     prefix =                     ; this is the default
#pod     include_dotfiles = 0         ; this is the default
#pod     include_untracked = 0        ; this is the default
#pod     exclude_filename = dir/skip  ; there is no default
#pod     exclude_match = ^local_      ; there is no default
#pod
#pod =head1 DESCRIPTION
#pod
#pod This is a trivial variant of the L<GatherDir|Dist::Zilla::Plugin::GatherDir>
#pod plugin.  It looks in the directory named in the L</root> attribute and adds all
#pod the Git tracked files it finds there (as determined by C<git ls-files>).  If the
#pod root begins with a tilde, the directory name is passed through C<glob()> first.
#pod
#pod Most users just need:
#pod
#pod   [Git::GatherDir]
#pod
#pod ...and this will pick up all tracked files from the current directory into the
#pod dist.  You can use it multiple times, as you can any other plugin, by providing
#pod a plugin name.  For example, if you want to include external specification
#pod files into a subdir of your dist, you might write:
#pod
#pod   [Git::GatherDir]
#pod   ; this plugin needs no config and gathers most of your files
#pod
#pod   [Git::GatherDir / SpecFiles]
#pod   ; this plugin gets all tracked files in the root dir and adds them under ./spec
#pod   root   = ~/projects/my-project/spec
#pod   prefix = spec
#pod
#pod =cut

use List::Util 1.45 qw(uniq);
use MooseX::Types::Moose qw(Bool);

use namespace::autoclean;

#pod =attr root
#pod
#pod This is the directory in which to look for files.  If not given, it defaults to
#pod the dist root -- generally, the place where your F<dist.ini> or other
#pod configuration file is located.  It may begin with C<~> (or C<~user>)
#pod to mean your (or some other user's) home directory.  If a relative path,
#pod it's relative to the dist root.  It does not need to be the root of a
#pod Git repository, but it must be inside a repository.
#pod
#pod =attr prefix
#pod
#pod This parameter can be set to gather all the files found under a common
#pod directory.  See the L<description|DESCRIPTION> above for an example.
#pod
#pod =attr include_dotfiles
#pod
#pod By default, files will not be included if they begin with a dot.  This goes
#pod both for files and for directories relative to the C<root>.
#pod
#pod In almost all cases, the default value (false) is correct.
#pod
#pod =attr include_untracked
#pod
#pod By default, files not tracked by Git will not be gathered.  If this is
#pod set to a true value, then untracked files not covered by a Git ignore
#pod pattern (i.e. those reported by C<git ls-files -o --exclude-standard>)
#pod are also gathered (and you'll probably want to use
#pod L<Git::Check|Dist::Zilla::Plugin::Git::Check> to ensure all files are
#pod checked in before a release).
#pod
#pod C<include_untracked> requires at least Git 1.5.4, but you should
#pod probably not use it if your Git is older than 1.6.5.2.  Versions
#pod before that would not list files matched by your F<.gitignore>, even
#pod if they were already being tracked by Git (which means they will not
#pod be gathered, even though they should be).  Whether that is a problem
#pod depends on the contents of your exclude files (including the global
#pod one, if any).
#pod
#pod =attr follow_symlinks
#pod
#pod Git::GatherDir does not honor GatherDir's
#pod L<follow_symlinks|Dist::Zilla::Plugin::GatherDir/follow_symlinks>
#pod option.  While the attribute exists (because Git::GatherDir is a
#pod subclass), setting it has no effect.
#pod
#pod Directories that are symlinks will not be gathered.  Instead, you'll
#pod get a message saying C<WARNING: %s is symlink to directory, skipping it>.
#pod To suppress the warning, add that directory to C<exclude_filename> or
#pod C<exclude_match>.  To gather the files in the symlinked directory, use
#pod a second instance of GatherDir or Git::GatherDir with appropriate
#pod C<root> and C<prefix> options.
#pod
#pod Files which are symlinks are always gathered.
#pod
#pod =attr exclude_filename
#pod
#pod To exclude certain files from being gathered, use the C<exclude_filename>
#pod option. This may be used multiple times to specify multiple files to exclude.
#pod
#pod =attr exclude_match
#pod
#pod This is just like C<exclude_filename> but provides a regular expression
#pod pattern.  Files matching the pattern are not gathered.  This may be used
#pod multiple times to specify multiple patterns to exclude.
#pod
#pod =cut

has include_untracked => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
);

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    include_untracked => $self->include_untracked ? 1 : 0,
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

override gather_files => sub {
  my ($self) = @_;

  require Git::Wrapper;
  require Path::Tiny;

  my $root = '' . $self->root;

  # Convert ~ to home directory:
  if ( $root =~ /^~/ ) {
    ($root) = glob($root);
    warn 'old perl on Win32 detected: ~ in root not translated'
      if $root =~ /^~/ and $^O eq 'Win32' && "$]" < '5.016';
  }

  $root = Path::Tiny::path($root)->absolute( $self->zilla->root->absolute );

  # Prepare to gather files
  my $git = Git::Wrapper->new( $root->stringify );

  my @opts;
  @opts = qw(--cached --others --exclude-standard) if $self->include_untracked;

  my $exclude_regex = qr/\000/;
  $exclude_regex = qr/$exclude_regex|$_/ for ( @{ $self->exclude_match } );

  my %is_excluded = map { ; $_ => 1 } @{ $self->exclude_filename };

  my $prefix = $self->prefix;

  # Loop over files reported by git ls-files
  for my $filename ( uniq $git->ls_files(@opts) ) {

    # $file is a Path::Tiny relative to $root
    my $file = Path::Tiny::path($filename);

    $self->log_debug("considering $file");

    # Exclusion tests
    unless ( $self->include_dotfiles ) {
      next if grep { /^\./ } split q{/}, $file->stringify;
    }

    next if $file =~ $exclude_regex;
    next if $is_excluded{$file};

    # DZil can't gather directory symlinks
    my $path = $root->child($file);

    if ( -d $path ) {
      $self->log("WARNING: $file is symlink to directory, skipping it");
      next;
    }

    # Gather the file
    my $fileobj = $self->_file_from_filename( $path->stringify );

    $file = Path::Tiny::path( $prefix, $file ) if length $prefix;

    $fileobj->name( $file->stringify );
    $self->add_file($fileobj);
    $self->log_debug("gathered $file");
  }

  return;
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

