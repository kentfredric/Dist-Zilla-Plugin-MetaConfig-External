package File::chdir;
use 5.004;
use strict;
use vars qw($VERSION @ISA @EXPORT $CWD @CWD);

# ABSTRACT: a more sensible way to change directories

our $VERSION = '0.1010';

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(*CWD);

use Carp;
use Cwd 3.16;
use File::Spec::Functions 3.27 qw/canonpath splitpath catpath splitdir catdir/;

tie $CWD, 'File::chdir::SCALAR' or die "Can't tie \$CWD";
tie @CWD, 'File::chdir::ARRAY'  or die "Can't tie \@CWD";

sub _abs_path {

  # Otherwise we'll never work under taint mode.
  my ($cwd) = Cwd::getcwd =~ /(.*)/s;

  # Run through File::Spec, since everything else uses it
  return canonpath($cwd);
}

# splitpath but also split directory
sub _split_cwd {
  my ( $vol, $dir ) = splitpath( _abs_path, 1 );
  my @dirs = splitdir($dir);
  shift @dirs;    # get rid of leading empty "root" directory
  return ( $vol, @dirs );
}

# catpath, but take list of directories
# restore the empty root dir and provide an empty file to avoid warnings
sub _catpath {
  my ( $vol, @dirs ) = @_;
  return catpath( $vol, catdir( q{}, @dirs ), q{} );
}

sub _chdir {

  # Untaint target directory
  my ($new_dir) = $_[0] =~ /(.*)/s;

  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  if ( !CORE::chdir($new_dir) ) {
    croak "Failed to change directory to '$new_dir': $!";
  }
  return 1;
}

{

  package File::chdir::SCALAR;
  use Carp;

  BEGIN {
    *_abs_path  = \&File::chdir::_abs_path;
    *_chdir     = \&File::chdir::_chdir;
    *_split_cwd = \&File::chdir::_split_cwd;
    *_catpath   = \&File::chdir::_catpath;
  }

  sub TIESCALAR {
    bless [], $_[0];
  }

  # To be safe, in case someone chdir'd out from under us, we always
  # check the Cwd explicitly.
  sub FETCH {
    return _abs_path;
  }

  sub STORE {
    return unless defined $_[1];
    _chdir( $_[1] );
  }
}

{

  package File::chdir::ARRAY;
  use Carp;

  BEGIN {
    *_abs_path  = \&File::chdir::_abs_path;
    *_chdir     = \&File::chdir::_chdir;
    *_split_cwd = \&File::chdir::_split_cwd;
    *_catpath   = \&File::chdir::_catpath;
  }

  sub TIEARRAY {
    bless {}, $_[0];
  }

  sub FETCH {
    my ( $self, $idx ) = @_;
    my ( $vol,  @cwd ) = _split_cwd;
    return $cwd[$idx];
  }

  sub STORE {
    my ( $self, $idx, $val ) = @_;

    my ( $vol, @cwd ) = _split_cwd;
    if ( $self->{Cleared} ) {
      @cwd = ();
      $self->{Cleared} = 0;
    }

    $cwd[$idx] = $val;
    my $dir = _catpath( $vol, @cwd );

    _chdir($dir);
    return $cwd[$idx];
  }

  sub FETCHSIZE {
    my ( $vol, @cwd ) = _split_cwd;
    return scalar @cwd;
  }
  sub STORESIZE { }

  sub PUSH {
    my ($self) = shift;

    my $dir = _catpath( _split_cwd, @_ );
    _chdir($dir);
    return $self->FETCHSIZE;
  }

  sub POP {
    my ($self) = shift;

    my ( $vol, @cwd ) = _split_cwd;
    my $popped = pop @cwd;
    my $dir    = _catpath( $vol, @cwd );
    _chdir($dir);
    return $popped;
  }

  sub SHIFT {
    my ($self) = shift;

    my ( $vol, @cwd ) = _split_cwd;
    my $shifted = shift @cwd;
    my $dir     = _catpath( $vol, @cwd );
    _chdir($dir);
    return $shifted;
  }

  sub UNSHIFT {
    my ($self) = shift;

    my ( $vol, @cwd ) = _split_cwd;
    my $dir = _catpath( $vol, @_, @cwd );
    _chdir($dir);
    return $self->FETCHSIZE;
  }

  sub CLEAR {
    my ($self) = shift;
    $self->{Cleared} = 1;
  }

  sub SPLICE {
    my $self     = shift;
    my $offset   = shift || 0;
    my $len      = shift || $self->FETCHSIZE - $offset;
    my @new_dirs = @_;

    my ( $vol, @cwd ) = _split_cwd;
    my @orig_dirs = splice @cwd, $offset, $len, @new_dirs;
    my $dir       = _catpath( $vol, @cwd );
    _chdir($dir);
    return @orig_dirs;
  }

  sub EXTEND { }

  sub EXISTS {
    my ( $self, $idx ) = @_;
    return $self->FETCHSIZE >= $idx ? 1 : 0;
  }

  sub DELETE {
    my ( $self, $idx ) = @_;
    croak "Can't delete except at the end of \@CWD"
      if $idx < $self->FETCHSIZE - 1;
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    $self->POP;
  }
}

1;

__END__

