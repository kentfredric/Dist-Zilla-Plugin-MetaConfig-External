package Git::Wrapper::Log;

# ABSTRACT: Log line of the Git
$Git::Wrapper::Log::VERSION = '0.047';
use 5.006;
use strict;
use warnings;

sub new {
  my ( $class, $id, %arg ) = @_;
  my $modifications = defined $arg{modifications} ? delete $arg{modifications} : [];
  return bless {
    id            => $id,
    attr          => {},
    modifications => $modifications,
    %arg,
  } => $class;
}

sub id   { shift->{id} }
sub attr { shift->{attr} }

sub modifications {
  my $self = shift;
  if ( @_ > 0 ) {
    $self->{modifications} = [@_];
    return scalar @{ $self->{modifications} };
  }
  else { return @{ $self->{modifications} } }
}

sub message { @_ > 1 ? ( $_[0]->{message} = $_[1] ) : $_[0]->{message} }

sub date { shift->attr->{date} }

sub author { shift->attr->{author} }

1;

__END__

