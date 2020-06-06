use strict;

package Path::Class::Dir;
{
  $Path::Class::Dir::VERSION = '0.37';
}

use Path::Class::File;
use Carp();
use parent qw(Path::Class::Entity);

use IO::Dir      ();
use File::Path   ();
use File::Temp   ();
use Scalar::Util ();

# updir & curdir on the local machine, for screening them out in
# children().  Note that they don't respect 'foreign' semantics.
my $Updir  = __PACKAGE__->_spec->updir;
my $Curdir = __PACKAGE__->_spec->curdir;

sub new {
  my $self = shift->SUPER::new();

  # If the only arg is undef, it's probably a mistake.  Without this
  # special case here, we'd return the root directory, which is a
  # lousy thing to do to someone when they made a mistake.  Return
  # undef instead.
  return if @_ == 1 && !defined( $_[0] );

  my $s = $self->_spec;

  my $first = (
      @_ == 0                      ? $s->curdir
    : !ref( $_[0] ) && $_[0] eq '' ? ( shift, $s->rootdir )
    :                                shift()
  );

  $self->{dirs} = [];
  if ( Scalar::Util::blessed($first) && $first->isa("Path::Class::Dir") ) {
    $self->{volume} = $first->{volume};
    push @{ $self->{dirs} }, @{ $first->{dirs} };
  }
  else {
    ( $self->{volume}, my $dirs ) = $s->splitpath( $s->canonpath("$first"), 1 );
    push @{ $self->{dirs} }, $dirs eq $s->rootdir ? "" : $s->splitdir($dirs);
  }

  push @{ $self->{dirs} },
    map { Scalar::Util::blessed($_) && $_->isa("Path::Class::Dir") ? @{ $_->{dirs} } : $s->splitdir( $s->canonpath($_) ) } @_;

  return $self;
}

sub file_class { "Path::Class::File" }

sub is_dir { 1 }

sub as_foreign {
  my ( $self, $type ) = @_;

  my $foreign = do {
    local $self->{file_spec_class} = $self->_spec_class($type);
    $self->SUPER::new;
  };

  # Clone internal structure
  $foreign->{volume} = $self->{volume};
  my ( $u, $fu ) = ( $self->_spec->updir, $foreign->_spec->updir );
  $foreign->{dirs} = [ map { $_ eq $u ? $fu : $_ } @{ $self->{dirs} } ];
  return $foreign;
}

sub stringify {
  my $self = shift;
  my $s    = $self->_spec;
  return $s->catpath( $self->{volume}, $s->catdir( @{ $self->{dirs} } ), '' );
}

sub volume { shift()->{volume} }

sub file {
  local $Path::Class::Foreign = $_[0]->{file_spec_class} if $_[0]->{file_spec_class};
  return $_[0]->file_class->new(@_);
}

sub basename { shift()->{dirs}[-1] }

sub dir_list {
  my $self = shift;
  my $d    = $self->{dirs};
  return @$d unless @_;

  my $offset = shift;
  if ( $offset < 0 ) { $offset = $#$d + $offset + 1 }

  return wantarray ? @$d[ $offset .. $#$d ] : $d->[$offset] unless @_;

  my $length = shift;
  if ( $length < 0 ) { $length = $#$d + $length + 1 - $offset }
  return @$d[ $offset .. $length + $offset - 1 ];
}

sub components {
  my $self = shift;
  return $self->dir_list(@_);
}

sub subdir {
  my $self = shift;
  return $self->new( $self, @_ );
}

sub parent {
  my $self = shift;
  my $dirs = $self->{dirs};
  my ( $curdir, $updir ) = ( $self->_spec->curdir, $self->_spec->updir );

  if ( $self->is_absolute ) {
    my $parent = $self->new($self);
    pop @{ $parent->{dirs} } if @$dirs > 1;
    return $parent;

  }
  elsif ( $self eq $curdir ) {
    return $self->new($updir);

  }
  elsif ( !grep { $_ ne $updir } @$dirs ) {    # All updirs
    return $self->new( $self, $updir );        # Add one more

  }
  elsif ( @$dirs == 1 ) {
    return $self->new($curdir);

  }
  else {
    my $parent = $self->new($self);
    pop @{ $parent->{dirs} };
    return $parent;
  }
}

sub relative {

  # File::Spec->abs2rel before version 3.13 returned the empty string
  # when the two paths were equal - work around it here.
  my $self = shift;
  my $rel  = $self->_spec->abs2rel( $self->stringify, @_ );
  return $self->new( length $rel ? $rel : $self->_spec->curdir );
}

sub open   { IO::Dir->new(@_) }
sub mkpath { File::Path::mkpath( shift()->stringify, @_ ) }
sub rmtree { File::Path::rmtree( shift()->stringify, @_ ) }

sub remove {
  rmdir( shift() );
}

sub traverse {
  my $self = shift;
  my ( $callback, @args ) = @_;
  my @children = $self->children;
  return $self->$callback(
    sub {
      my @inner_args = @_;
      return map { $_->traverse( $callback, @inner_args ) } @children;
    },
    @args
  );
}

sub traverse_if {
  my $self = shift;
  my ( $callback, $condition, @args ) = @_;
  my @children = grep { $condition->($_) } $self->children;
  return $self->$callback(
    sub {
      my @inner_args = @_;
      return map { $_->traverse_if( $callback, $condition, @inner_args ) } @children;
    },
    @args
  );
}

sub recurse {
  my $self = shift;
  my %opts = ( preorder => 1, depthfirst => 0, @_ );

  my $callback = $opts{callback}
    or Carp::croak("Must provide a 'callback' parameter to recurse()");

  my @queue = ($self);

  my $visit_entry;
  my $visit_dir = $opts{depthfirst} && $opts{preorder}
    ? sub {
    my $dir = shift;
    my $ret = $callback->($dir);
    unless ( ( $ret || '' ) eq $self->PRUNE ) {
      unshift @queue, $dir->children;
    }
    }
    : $opts{preorder} ? sub {
    my $dir = shift;
    my $ret = $callback->($dir);
    unless ( ( $ret || '' ) eq $self->PRUNE ) {
      push @queue, $dir->children;
    }
    }
    : sub {
    my $dir = shift;
    $visit_entry->($_) foreach $dir->children;
    $callback->($dir);
    };

  $visit_entry = sub {
    my $entry = shift;
    if   ( $entry->is_dir ) { $visit_dir->($entry) }    # Will call $callback
    else                    { $callback->($entry) }
  };

  while (@queue) {
    $visit_entry->( shift @queue );
  }
}

sub children {
  my ( $self, %opts ) = @_;

  my $dh = $self->open or Carp::croak("Can't open directory $self: $!");

  my @out;
  while ( defined( my $entry = $dh->read ) ) {
    next if !$opts{all} && $self->_is_local_dot_dir($entry);
    next if ( $opts{no_hidden} && $entry =~ /^\./ );
    push @out, $self->file($entry);
    $out[-1] = $self->subdir($entry) if -d $out[-1];
  }
  return @out;
}

sub _is_local_dot_dir {
  my $self = shift;
  my $dir  = shift;

  return ( $dir eq $Updir or $dir eq $Curdir );
}

sub next {
  my $self = shift;
  unless ( $self->{dh} ) {
    $self->{dh} = $self->open or Carp::croak("Can't open directory $self: $!");
  }

  my $next = $self->{dh}->read;
  unless ( defined $next ) {
    delete $self->{dh};
    ## no critic
    return undef;
  }

  # Figure out whether it's a file or directory
  my $file = $self->file($next);
  $file = $self->subdir($next) if -d $file;
  return $file;
}

sub subsumes {
  Carp::croak "Too many arguments given to subsumes()" if $#_ > 2;
  my ( $self, $other ) = @_;
  Carp::croak("No second entity given to subsumes()") unless defined $other;

  $other = $self->new($other) unless eval { $other->isa("Path::Class::Entity") };
  $other = $other->dir        unless $other->is_dir;

  if ( $self->is_absolute ) {
    $other = $other->absolute;
  }
  elsif ( $other->is_absolute ) {
    $self = $self->absolute;
  }

  $self  = $self->cleanup;
  $other = $other->cleanup;

  if ( $self->volume || $other->volume ) {
    return 0 unless $other->volume eq $self->volume;
  }

  # The root dir subsumes everything (but ignore the volume because
  # we've already checked that)
  return 1 if "@{$self->{dirs}}" eq "@{$self->new('')->{dirs}}";

  # The current dir subsumes every relative path (unless starting with updir)
  if ( $self eq $self->_spec->curdir ) {
    return $other->{dirs}[0] ne $self->_spec->updir;
  }

  my $i = 0;
  while ( $i <= $#{ $self->{dirs} } ) {
    return 0 if $i > $#{ $other->{dirs} };
    return 0 if $self->{dirs}[$i] ne $other->{dirs}[$i];
    $i++;
  }
  return 1;
}

sub contains {
  Carp::croak "Too many arguments given to contains()" if $#_ > 2;
  my ( $self, $other ) = @_;
  Carp::croak "No second entity given to contains()" unless defined $other;
  return unless -d $self and ( -e $other or -l $other );

  # We're going to resolve the path, and don't want side effects on the objects
  # so clone them.  This also handles strings passed as $other.
  $self  = $self->new($self)->resolve;
  $other = $self->new($other)->resolve;

  return $self->subsumes($other);
}

sub tempfile {
  my $self = shift;
  return File::Temp::tempfile( @_, DIR => $self->stringify );
}

1;
__END__

