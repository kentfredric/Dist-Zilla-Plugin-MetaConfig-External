use 5.006;
use strict;
use warnings;

package Git::Wrapper;

#ABSTRACT: Wrap git(7) command-line interface
$Git::Wrapper::VERSION = '0.047';
our $DEBUG = 0;

# Prevent ANSI color with extreme prejudice
# https://github.com/genehack/Git-Wrapper/issues/13
delete $ENV{GIT_PAGER_IN_USE};

use File::chdir;
use File::Temp;
use IPC::Open3 qw();
use Scalar::Util qw(blessed);
use Sort::Versions;
use Symbol;

use Git::Wrapper::Exception;
use Git::Wrapper::File::RawModification;
use Git::Wrapper::Log;
use Git::Wrapper::Statuses;

sub new {
  my $class = shift;

  # three calling conventions
  # 1: my $gw = Git::Wrapper->new( $dir )
  # 2: my $gw = Git::Wrapper->new( $dir , %options )
  # 3: my $gw = Git::Wrapper->new({ dir => $dir , %options });

  my $args;

  if ( scalar @_ == 1 ) {
    my $arg = shift;
    if ( ref $arg eq 'HASH' ) { $args = $arg }
    elsif ( blessed $arg ) { $args = { dir => "$arg" } }    # my objects, let me
                                                            # show you them.
    elsif ( !ref $arg )    { $args = { dir => $arg } }
    else                   { die "Single arg must be hashref, scalar, or stringify-able object" }
  }
  else {
    my ( $dir, %opts ) = @_;
    $dir  = "$dir" if blessed $dir;                         # we can stringify it for you wholesale
    $args = { dir => $dir, %opts };
  }

  my $self = bless $args => $class;

  die "usage: $class->new(\$dir)" unless $self->dir;

  return $self;
}

sub AUTOLOAD {
  my $self = shift;

  ( my $meth = our $AUTOLOAD ) =~ s/.+:://;
  return if $meth eq 'DESTROY';

  $meth =~ tr/_/-/;

  return $self->RUN( $meth, @_ );
}

sub ERR { shift->{err} }
sub OUT { shift->{out} }

sub RUN {
  my $self = shift;

  delete $self->{err};
  delete $self->{out};

  my $cmd = shift;

  my ( $parts, $stdin ) = _parse_args( $cmd, @_ );

  my @cmd = ( $self->git, @$parts );

  my ( @out, @err );

  {
    local $CWD = $self->dir unless $cmd eq 'clone';

    my ( $wtr, $rdr, $err );

    local *TEMP;
    if ( $^O eq 'MSWin32' && defined $stdin ) {
      my $file = File::Temp->new;
      $file->autoflush(1);
      $file->print($stdin);
      $file->seek( 0, 0 );
      open TEMP, '<&=', $file;
      $wtr = '<&TEMP';
      undef $stdin;
    }

    $err = Symbol::gensym;

    print STDERR join( ' ', @cmd ), "\n" if $DEBUG;

    # Prevent commands from running interactively
    local $ENV{GIT_EDITOR} = ' ';

    my $pid = IPC::Open3::open3( $wtr, $rdr, $err, @cmd );
    print $wtr $stdin
      if defined $stdin;

    close $wtr;
    chomp( @out = <$rdr> );
    chomp( @err = <$err> );

    waitpid $pid, 0;
  };

  print "status: $?\n" if $DEBUG;

  # In earlier gits (1.5, 1.6, I'm not sure when it changed), "git status"
  # would exit 1 if there was nothing to commit, or in other cases. This is
  # basically insane, and has been fixed, but if we don't require git 1.7, we
  # should cope with it. -- rjbs, 2012-03-31
  my $stupid_status = $cmd eq 'status' && @out && !@err;

  if ( $? && !$stupid_status ) {
    die Git::Wrapper::Exception->new(
      output => \@out,
      error  => \@err,
      status => $? >> 8,
    );
  }

  chomp(@err);
  $self->{err} = \@err;

  chomp(@out);
  $self->{out} = \@out;

  return @out;
}

sub branch {
  my $self = shift;

  my $opt = ref $_[0] eq 'HASH' ? shift : {};
  $opt->{no_color} = 1;

  return $self->RUN( branch => $opt, @_ );
}

sub dir { shift->{dir} }

sub git {
  my $self = shift;

  return $self->{git_binary} if defined $self->{git_binary};

  return ( defined $ENV{GIT_WRAPPER_GIT} ) ? $ENV{GIT_WRAPPER_GIT} : 'git';
}

sub has_git_in_path {
  require IPC::Cmd;
  IPC::Cmd::can_run('git');
}

sub log {
  my $self = shift;

  if ( grep /format=/, @_ ) {
    die Git::Wrapper::Exception->new(
      error  => [qw/--format not allowed. Use the RUN() method if you with to use a custom log format./],
      output => undef,
      status => 255,
    );
  }

  my $opt = ref $_[0] eq 'HASH' ? shift : {};
  $opt->{no_color}  = 1;
  $opt->{pretty}    = 'medium';
  $opt->{no_abbrev} = 1;          # https://github.com/genehack/Git-Wrapper/issues/67

  $opt->{no_abbrev_commit} = 1
    if $self->supports_log_no_abbrev_commit;
  $opt->{no_expand_tabs} = 1
    if $self->supports_log_no_expand_tabs;

  my $raw = defined $opt->{raw} && $opt->{raw};

  my @out = $self->RUN( log => $opt, @_ );

  my @logs;
  while ( my $line = shift @out ) {
    die "unhandled: $line" unless $line =~ /^commit (\S+)/;

    my $current = Git::Wrapper::Log->new($1);

    $line = shift @out;    # next line;

    while ( $line =~ /^(\S+):\s+(.+)$/ ) {
      $current->attr->{ lc $1 } = $2;
      $line = shift @out;    # next line;
    }

    die "no blank line separating head from message" if $line;

    my ($initial_indent) = $out[0] =~ /^(\s*)/ if @out;

    my $message = '';
    while ( @out
      and $out[0] !~ /^commit (\S+)/
      and length( $line = shift @out ) )
    {
      $line =~ s/^$initial_indent//;    # strip just the indenting added by git
      $message .= "$line\n";
    }

    $current->message($message);

    if ($raw) {
      my @modifications;

      # example outputs:
      #  regular:
      # :000000 100644 0000000000000000000000000000000000000000 ce013625030ba8dba906f756967f9e9ca394464a A     foo/bar
      #  with score value after file type (see https://github.com/genehack/Git-Wrapper/issues/70):
      # :100644 100644 c659037... c659037... R100       foo bar
      while ( @out and $out[0] =~ m/^\:(\d{6}) (\d{6}) (\w{40}) (\w{40}) (\w{1}[0-9]*)\t(.*)$/ ) {
        push @modifications, Git::Wrapper::File::RawModification->new( $6, $5, $1, $2, $3, $4 );
        shift @out;
      }
      $current->modifications(@modifications) if @modifications;
    }

    push @logs, $current;

    last unless @out;                          # handle running out of log
    shift @out unless $out[0] =~ /^commit/;    # blank line at end of entry, except merge commits;
  }

  return @logs;
}

my %STATUS_CONFLICTS = map { $_ => 1 } qw<DD AU UD UA DU AA UU>;

sub status {
  my $self = shift;

  return $self->RUN( 'status', @_ )
    unless $self->supports_status_porcelain;

  my $opt = ref $_[0] eq 'HASH' ? shift : {};
  $opt->{$_} = 1 for qw<porcelain>;

  my @out = $self->RUN( status => $opt, @_ );

  my $statuses = Git::Wrapper::Statuses->new;

  return $statuses if !@out;

  for (@out) {
    my ( $x, $y, $from, $to ) = $_ =~ /\A(.)(.) (.*?)(?: -> (.*))?\z/;

    if ( $STATUS_CONFLICTS{"$x$y"} ) {
      $statuses->add( 'conflict', "$x$y", $from, $to );
    }
    elsif ( $x eq '?' && $y eq '?' ) {
      $statuses->add( 'unknown', '?', $from, $to );
    }
    else {
      $statuses->add( 'changed', $y, $from, $to )
        if $y ne ' ';
      $statuses->add( 'indexed', $x, $from, $to )
        if $x ne ' ';
    }
  }
  return $statuses;
}

sub supports_hash_object_filters {
  my $self = shift;

  # The '--no-filters' option to 'git-hash-object' was added in version 1.6.1
  return 0 if ( versioncmp( $self->version, '1.6.1' ) eq -1 );
  return 1;
}

sub supports_log_no_abbrev_commit {
  my $self = shift;

  # The '--no-abbrev-commit' option to 'git log' was added in version 1.7.6
  return ( versioncmp( $self->version, '1.7.6' ) eq -1 ) ? 0 : 1;
}

sub supports_log_no_expand_tabs {
  my $self = shift;

  # The '--no-expand-tabs' option to git log was added in version 2.9.0
  return 0 if ( versioncmp( $self->version, '2.9' ) eq -1 );
  return 1;
}

sub supports_log_raw_dates {
  my $self = shift;

  # The '--date=raw' option to 'git log' was added in version 1.6.2
  return 0 if ( versioncmp( $self->version, '1.6.2' ) eq -1 );
  return 1;
}

sub supports_status_porcelain {
  my $self = shift;

  # The '--porcelain' option to git status was added in version 1.7.0
  return 0 if ( versioncmp( $self->version, '1.7' ) eq -1 );
  return 1;
}

sub version {
  my $self = shift;

  my ($version) = $self->RUN('version');

  $version =~ s/^git version //;

  return $version;
}

sub _message_tempfile {
  my ($message) = @_;

  my $tmp = File::Temp->new( UNLINK => 0 );
  $tmp->print($message);

  return ( "file", '"' . $tmp->filename . '"' );
}

sub _opt_and_val {
  my ( $name, $val ) = @_;

  $name =~ tr/_/-/;
  my $opt =
    length($name) == 1
    ? "-$name"
    : "--$name";

  return
      $val eq '1'        ? ($opt)
    : length($name) == 1 ? ( $opt, $val )
    :                      "$opt=$val";
}

sub _parse_args {
  my $cmd = shift;
  die "initial argument must not be a reference\n"
    if ref $cmd;

  my ( $stdin, @pre_cmd, @post_cmd );

  foreach (@_) {
    if ( ref $_ eq 'HASH' ) {
      $stdin = delete $_->{-STDIN}
        if exists $_->{-STDIN};

      for my $name ( sort keys %$_ ) {
        my $val = delete $_->{$name};
        next if $val eq '0';

        if ( $name =~ s/^-// ) {
          push @pre_cmd, _opt_and_val( $name, $val );
        }
        else {
          ( $name, $val ) = _message_tempfile($val)
            if _win32_multiline_commit_msg( $cmd, $name, $val );

          push @post_cmd, _opt_and_val( $name, $val );
        }
      }
    }
    elsif ( blessed $_ ) {
      push @post_cmd, "$_";    # here be anteaters
    }
    elsif ( ref $_ ) {
      die "Git::Wrapper command arguments must be plain scalars, hashrefs, " . "or stringify-able objects.\n";
    }
    else { push @post_cmd, $_; }
  }

  return ( [ @pre_cmd, $cmd, @post_cmd ], $stdin );
}

sub _win32_multiline_commit_msg {
  my ( $cmd, $name, $val ) = @_;

  return 0 if $^O ne "MSWin32";
  return 0 if $cmd ne "commit";
  return 0 if $name ne "m" and $name ne "message";
  return 0 if $val !~ /\n/;

  return 1;
}

__END__

