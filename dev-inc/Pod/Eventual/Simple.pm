use strict;
use warnings;

package Pod::Eventual::Simple;
{
  $Pod::Eventual::Simple::VERSION = '0.094001';
}
use Pod::Eventual;
BEGIN { our @ISA = 'Pod::Eventual' }

# ABSTRACT: just get an array of the stuff Pod::Eventual finds

sub new {
  my ($class) = @_;
  bless [] => $class;
}

sub read_handle {
  my ( $self, $handle, $arg ) = @_;
  $self = $self->new unless ref $self;
  $self->SUPER::read_handle( $handle, $arg );
  return [@$self];
}

sub handle_event {
  my ( $self, $event ) = @_;
  push @$self, $event;
}

BEGIN {
  *handle_blank  = \&handle_event;
  *handle_nonpod = \&handle_event;
}

1;

__END__

