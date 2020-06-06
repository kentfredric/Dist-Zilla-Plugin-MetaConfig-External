package WWW::Shorten::Simple;

use strict;
use 5.008_001;
our $VERSION = '0.02';

use Carp;

sub new {
  my ( $class, $impl, @args ) = @_;

  unless ($impl) {
    Carp::croak "WWW::Shorten subclass name is required";
  }

  my $subclass = "WWW::Shorten::$impl";
  $subclass =~ s!::!/!g;
  $subclass .= ".pm";
  eval { require $subclass };
  Carp::croak "Can't load $impl: $@" if $@;

  bless { impl => "WWW::Shorten::$impl", args => \@args }, $class;
}

sub shorten {
  my $self = shift;
  my ($url) = @_;

  $self->call_method( "makeashorterlink", $url, @{ $self->{args} } );
}

sub makeashorterlink { shift->shorten(@_) }
sub short_link       { shift->shorten(@_) }

sub unshorten {
  my $self = shift;
  my ($url) = @_;

  $self->call_method( "makealongerlink", $url, @{ $self->{args} } );
}

sub makealongerlink { shift->unshorten(@_) }
sub long_link       { shift->unshorten(@_) }

sub call_method {
  my ( $self, $method, @args ) = @_;

  no strict 'refs';
  &{ $self->{impl} . "::$method" }(@args);
}

1;
__END__

