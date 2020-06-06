use strict;

package Path::Class::File;
{
  $Path::Class::File::VERSION = '0.37';
}

use Path::Class::Dir;
use parent qw(Path::Class::Entity);
use Carp;

use IO::File ();

sub new {
  my $self = shift->SUPER::new;
  my $file = pop();
  my @dirs = @_;

  my ( $volume, $dirs, $base ) = $self->_spec->splitpath($file);

  if ( length $dirs ) {
    push @dirs, $self->_spec->catpath( $volume, $dirs, '' );
  }

  $self->{dir}  = @dirs ? $self->dir_class->new(@dirs) : undef;
  $self->{file} = $base;

  return $self;
}

sub dir_class { "Path::Class::Dir" }

sub as_foreign {
  my ( $self, $type ) = @_;
  local $Path::Class::Foreign = $self->_spec_class($type);
  my $foreign = ref($self)->SUPER::new;
  $foreign->{dir}  = $self->{dir}->as_foreign($type) if defined $self->{dir};
  $foreign->{file} = $self->{file};
  return $foreign;
}

sub stringify {
  my $self = shift;
  return $self->{file} unless defined $self->{dir};
  return $self->_spec->catfile( $self->{dir}->stringify, $self->{file} );
}

sub dir {
  my $self = shift;
  return $self->{dir} if defined $self->{dir};
  return $self->dir_class->new( $self->_spec->curdir );
}
BEGIN { *parent = \&dir; }

sub volume {
  my $self = shift;
  return '' unless defined $self->{dir};
  return $self->{dir}->volume;
}

sub components {
  my $self = shift;
  croak "Arguments are not currently supported by File->components()" if @_;
  return ( $self->dir->components, $self->basename );
}

sub basename { shift->{file} }
sub open     { IO::File->new(@_) }

sub openr { $_[0]->open('r') or croak "Can't read $_[0]: $!" }
sub openw { $_[0]->open('w') or croak "Can't write to $_[0]: $!" }
sub opena { $_[0]->open('a') or croak "Can't append to $_[0]: $!" }

sub touch {
  my $self = shift;
  if ( -e $self ) {
    utime undef, undef, $self;
  }
  else {
    $self->openw;
  }
}

sub slurp {
  my ( $self, %args ) = @_;
  my $iomode = $args{iomode} || 'r';
  my $fh     = $self->open($iomode) or croak "Can't read $self: $!";

  if (wantarray) {
    my @data = <$fh>;
    chomp @data if $args{chomped} or $args{chomp};

    if ( my $splitter = $args{split} ) {
      @data = map { [ split $splitter, $_ ] } @data;
    }

    return @data;
  }

  croak "'split' argument can only be used in list context"
    if $args{split};

  if ( $args{chomped} or $args{chomp} ) {
    chomp( my @data = <$fh> );
    return join '', @data;
  }

  local $/;
  return <$fh>;
}

sub spew {
  my $self = shift;
  my %args = splice( @_, 0, @_ - 1 );

  my $iomode = $args{iomode} || 'w';
  my $fh     = $self->open($iomode) or croak "Can't write to $self: $!";

  if ( ref( $_[0] ) eq 'ARRAY' ) {

    # Use old-school for loop to avoid copying.
    for ( my $i = 0 ; $i < @{ $_[0] } ; $i++ ) {
      print $fh $_[0]->[$i]
        or croak "Can't write to $self: $!";
    }
  }
  else {
    print $fh $_[0]
      or croak "Can't write to $self: $!";
  }

  close $fh
    or croak "Can't write to $self: $!";

  return;
}

sub spew_lines {
  my $self = shift;
  my %args = splice( @_, 0, @_ - 1 );

  my $content = $_[0];

  # If content is an array ref, appends $/ to each element of the array.
  # Otherwise, if it is a simple scalar, just appends $/ to that scalar.

  $content =
    ref($content) eq 'ARRAY'
    ? [ map { $_, $/ } @$content ]
    : "$content$/";

  return $self->spew( %args, $content );
}

sub remove {
  my $file = shift->stringify;
  return unlink $file unless -e $file;    # Sets $! correctly
  1 while unlink $file;
  return not -e $file;
}

sub copy_to {
  my ( $self, $dest ) = @_;
  if ( eval { $dest->isa("Path::Class::File") } ) {
    $dest = $dest->stringify;
    croak "Can't copy to file $dest: it is a directory" if -d $dest;
  }
  elsif ( eval { $dest->isa("Path::Class::Dir") } ) {
    $dest = $dest->stringify;
    croak "Can't copy to directory $dest: it is a file" if -f $dest;
    croak "Can't copy to directory $dest: no such directory" unless -d $dest;
  }
  elsif ( ref $dest ) {
    croak "Don't know how to copy files to objects of type '" . ref($self) . "'";
  }

  require Perl::OSType;
  if ( !Perl::OSType::is_os_type('Unix') ) {

    require File::Copy;
    return unless File::Copy::cp( $self->stringify, "${dest}" );

  }
  else {

    return unless ( system( 'cp', $self->stringify, "${dest}" ) == 0 );

  }

  return $self->new($dest);
}

sub move_to {
  my ( $self, $dest ) = @_;
  require File::Copy;
  if ( File::Copy::move( $self->stringify, "${dest}" ) ) {

    my $new = $self->new($dest);

    $self->{$_} = $new->{$_} foreach (qw/ dir file /);

    return $self;

  }
  else {

    return;

  }
}

sub traverse {
  my $self = shift;
  my ( $callback, @args ) = @_;
  return $self->$callback( sub { () }, @args );
}

sub traverse_if {
  my $self = shift;
  my ( $callback, $condition, @args ) = @_;
  return $self->$callback( sub { () }, @args );
}

1;
__END__

