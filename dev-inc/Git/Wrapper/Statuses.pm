package Git::Wrapper::Statuses;

# ABSTRACT: Multiple git statuses information
$Git::Wrapper::Statuses::VERSION = '0.047';
use 5.006;
use strict;
use warnings;

use Git::Wrapper::Status;

sub new { return bless {} => shift }

sub add {
  my ( $self, $type, $mode, $from, $to ) = @_;

  my $status = Git::Wrapper::Status->new( $mode, $from, $to );

  push @{ $self->{$type} }, $status;
}

sub get {
  my ( $self, $type ) = @_;

  return @{ defined $self->{$type} ? $self->{$type} : [] };
}

sub is_dirty {
  my ($self) = @_;

  return keys %$self ? 1 : 0;
}

1;

__END__

