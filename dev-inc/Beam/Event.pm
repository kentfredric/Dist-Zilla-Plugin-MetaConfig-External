package Beam::Event;
our $VERSION = '1.007';

# ABSTRACT: Base Event class

#pod =head1 SYNOPSIS
#pod
#pod     # My::Emitter consumes the Beam::Emitter role
#pod     my $emitter = My::Emitter->new;
#pod     $emitter->on( "foo", sub {
#pod         my ( $event ) = @_;
#pod         print "Foo happened!\n";
#pod         # stop this event from continuing
#pod         $event->stop;
#pod     } );
#pod     my $event = $emitter->emit( "foo" );
#pod
#pod =head1 DESCRIPTION
#pod
#pod This is the base event class for C<Beam::Emitter> objects.
#pod
#pod The base class is only really useful for notifications. Create a subclass
#pod to add data attributes.
#pod
#pod =head1 SEE ALSO
#pod
#pod =over 4
#pod
#pod =item L<Beam::Emitter>
#pod
#pod =back
#pod
#pod =cut

use strict;
use warnings;

use Moo;
use Types::Standard qw(:all);

#pod =attr name
#pod
#pod The name of the event. This is the string that is given to L<Beam::Emitter/on>.
#pod
#pod =cut

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

#pod =attr emitter
#pod
#pod The emitter of this event. This is the object that created the event.
#pod
#pod =cut

has emitter => (
  is       => 'ro',
  isa      => ConsumerOf ['Beam::Emitter'],
  required => 1,
);

#pod =attr is_default_stopped
#pod
#pod This is true if anyone called L</stop_default> on this event.
#pod
#pod Your L<emitter|Beam::Emitter> should check this attribute before trying to do
#pod what the event was notifying about.
#pod
#pod =cut

has is_default_stopped => (
  is      => 'rw',
  isa     => Bool,
  default => sub { 0 },
);

#pod =attr is_stopped
#pod
#pod This is true if anyone called L</stop> on this event.
#pod
#pod When using L<the emit method|Beam::Emitter/emit>, this is checked automatically
#pod after every callback, and event processing is stopped if this is true.
#pod
#pod =cut

has is_stopped => (
  is      => 'rw',
  isa     => Bool,
  default => sub { 0 },
);

#pod =method stop_default ()
#pod
#pod Calling this will cause the default behavior of this event to be stopped.
#pod
#pod B<NOTE:> Your event-emitting object must check L</is_default_stopped> for this
#pod behavior to work.
#pod
#pod =cut

sub stop_default {
  my ($self) = @_;
  $self->is_default_stopped(1);
}

#pod =method stop ()
#pod
#pod Calling this will immediately stop any further processing of this event.
#pod Also calls L</stop_default>.
#pod
#pod =cut

sub stop {
  my ($self) = @_;
  $self->stop_default;
  $self->is_stopped(1);
}

1;

__END__

