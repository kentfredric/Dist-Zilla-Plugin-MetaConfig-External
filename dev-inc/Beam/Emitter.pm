package Beam::Emitter;
our $VERSION = '1.007';

# ABSTRACT: Role for event emitting classes

#pod =head1 SYNOPSIS
#pod
#pod     # A simple custom event class to perform data validation
#pod     { package My::Event;
#pod         use Moo;
#pod         extends 'Beam::Event';
#pod         has data => ( is => 'ro' );
#pod     }
#pod
#pod     # A class that reads and writes data, allowing event handlers to
#pod     # process the data
#pod     { package My::Emitter;
#pod         use Moo;
#pod         with 'Beam::Emitter';
#pod
#pod         sub write_data {
#pod             my ( $self, @data ) = @_;
#pod
#pod             # Give event listeners a chance to perform further processing of
#pod             # data
#pod             my $event = $self->emit( "process_data",
#pod                 class => 'My::Event',
#pod                 data => \@data,
#pod             );
#pod
#pod             # Give event listeners a chance to stop the write
#pod             return if $event->is_default_stopped;
#pod
#pod             # Write the data
#pod             open my $file, '>', 'output';
#pod             print { $file } @data;
#pod             close $file;
#pod
#pod             # Notify listeners we're done writing and send them the data
#pod             # we wrote
#pod             $self->emit( 'after_write', class => 'My::Event', data => \@data );
#pod         }
#pod     }
#pod
#pod     # An event handler that increments every input value in our data
#pod     sub increment {
#pod         my ( $event ) = @_;
#pod         my $data = $event->data;
#pod         $_++ for @$data;
#pod     }
#pod
#pod     # An event handler that performs data validation and stops the
#pod     # processing if invalid
#pod     sub prevent_negative {
#pod         my ( $event ) = @_;
#pod         my $data = $event->data;
#pod         $event->prevent_default if grep { $_ < 0 } @$data;
#pod     }
#pod
#pod     # An event handler that logs the data to STDERR after we've written in
#pod     sub log_data {
#pod         my ( $event ) = @_;
#pod         my $data = $event->data;
#pod         print STDERR "Wrote data: " . join( ',', @$data );
#pod     }
#pod
#pod     # Wire up our event handlers to a new processing object
#pod     my $processor = My::Emitter->new;
#pod     $processor->on( process_data => \&increment );
#pod     $processor->on( process_data => \&prevent_negative );
#pod     $processor->on( after_write => \&log_data );
#pod
#pod     # Process some data
#pod     $processor->process_data( 1, 2, 3, 4, 5 );
#pod     $processor->process_data( 1, 3, 7, -9, 11 );
#pod
#pod     # Log data before and after writing
#pod     my $processor = My::Emitter->new;
#pod     $processor->on( process_data => \&log_data );
#pod     $processor->on( after_write => \&log_data );
#pod
#pod =head1 DESCRIPTION
#pod
#pod This role is used by classes that want to add callback hooks to allow
#pod users to add new behaviors to their objects. These hooks are called
#pod "events". A subscriber registers a callback for an event using the
#pod L</subscribe> or L</on> methods. Then, the class can call those
#pod callbacks by L<emitting an event with the emit() method|/emit>.
#pod
#pod Using the L<Beam::Event> class, subscribers can stop an event from being
#pod processed, or prevent the default action from happening.
#pod
#pod =head2 Using Beam::Event
#pod
#pod L<Beam::Event> is an event object with some simple methods to allow subscribers
#pod to influence the handling of the event. By calling L<the stop
#pod method|Beam::Event/stop>, subscribers can stop all futher handling of the
#pod event. By calling the L<the stop_default method|Beam::Event/stop_default>,
#pod subscribers can allow other subscribers to be notified about the event, but let
#pod the emitter know that it shouldn't continue with what it was going to do.
#pod
#pod For example, let's build a door that notifies when someone tries to open it.
#pod Different instances of a door should allow different checks before the door
#pod opens, so we'll emit an event before we decide to open.
#pod
#pod     package Door;
#pod     use Moo;
#pod     with 'Beam::Emitter';
#pod
#pod     sub open {
#pod         my ( $self, $who ) = @_;
#pod         my $event = $self->emit( 'before_open' );
#pod         return if $event->is_default_stopped;
#pod         $self->open_the_door;
#pod     }
#pod
#pod     package main;
#pod     my $door = Door->new;
#pod     $door->open;
#pod
#pod Currently, our door will open for anybody. But let's build a door that only
#pod open opens after noon (to keep us from having to wake up in the morning).
#pod
#pod     use Time::Piece;
#pod     my $restful_door = Door->new;
#pod
#pod     $restful_door->on( before_open => sub {
#pod         my ( $event ) = @_;
#pod
#pod         my $time = Time::Piece->now;
#pod         if ( $time->hour < 12 ) {
#pod             $event->stop_default;
#pod         }
#pod
#pod     } );
#pod
#pod     $restful_door->open;
#pod
#pod By calling L<stop_default|Beam::Event/stop_default>, we set the
#pod L<is_default_stopped|Beam::Event/is_default_stopped> flag, which the door sees
#pod and decides not to open.
#pod
#pod =head2 Using Custom Events
#pod
#pod The default C<Beam::Event> is really only useful for notifications. If you want
#pod to give your subscribers some data, you need to create a custom event class.
#pod This allows you to add attributes and methods to your events (with all
#pod the type constraints and coersions you want).
#pod
#pod Let's build a door that can keep certain people out. Right now, our door
#pod doesn't care who is trying to open it, and our subscribers do not get enough
#pod information to deny entry to certain people.
#pod
#pod So first we need to build an event object that can let our subscribers know
#pod who is knocking on the door.
#pod
#pod     package Door::Knock;
#pod     use Moo;
#pod     extends 'Beam::Event';
#pod
#pod     has who => (
#pod         is => 'ro',
#pod         required => 1,
#pod     );
#pod
#pod Now that we can represent who is knocking, let's notify our subscribers.
#pod
#pod     package Door;
#pod     use Moo;
#pod     use Door::Knock; # Our emitter must load the class, Beam::Emitter will not
#pod     with 'Beam::Emitter';
#pod
#pod     sub open {
#pod         my ( $self, $who ) = @_;
#pod         my $event = $self->emit( 'before_open', class => 'Door::Knock', who => $who );
#pod         return if $event->is_default_stopped;
#pod         $self->open_the_door;
#pod     }
#pod
#pod Finally, let's build a listener that knows who is allowed in the door.
#pod
#pod     my $private_door = Door->new;
#pod     $private_door->on( before_open => sub {
#pod         my ( $event ) = @_;
#pod
#pod         if ( $event->who ne 'preaction' ) {
#pod             $event->stop_default;
#pod         }
#pod
#pod     } );
#pod
#pod     $private_door->open;
#pod
#pod =head2 Without Beam::Event
#pod
#pod Although checking C<is_default_stopped> is completely optional, if you do not
#pod wish to use the C<Beam::Event> object, you can instead call L<emit_args>
#pod instead of L<emit> to give arbitrary arguments to your listeners.
#pod
#pod     package Door;
#pod     use Moo;
#pod     with 'Beam::Emitter';
#pod
#pod     sub open {
#pod         my ( $self, $who ) = @_;
#pod         $self->emit_args( 'open', $who );
#pod         $self->open_the_door;
#pod     }
#pod
#pod There's no way to stop the door being opened, but you can at least notify
#pod someone before it does.
#pod
#pod =head1 SEE ALSO
#pod
#pod =over 4
#pod
#pod =item L<Beam::Event>
#pod
#pod =item L<Beam::Emitter::Cookbook>
#pod
#pod This document contains some useful patterns for your event emitters and
#pod listeners.
#pod
#pod =item L<http://perladvent.org/2013/2013-12-16.html>
#pod
#pod Coordinating Christmas Dinner with Beam::Emitter by Yanick Champoux.
#pod
#pod =back
#pod
#pod =cut

use strict;
use warnings;

use Types::Standard qw(:all);
use Scalar::Util qw( weaken refaddr );
use Carp qw( croak );
use Beam::Event;
use Module::Runtime qw( use_module );
use Moo::Role;    # Put this last to ensure proper, automatic cleanup

# The event listeners on this object, a hashref of arrayrefs of
# EVENT_NAME => [ Beam::Listener object, ... ]

has _listeners => (
  is      => 'ro',
  isa     => HashRef,
  default => sub { {} },
);

#pod =method subscribe ( event_name, subref, [ %args ] )
#pod
#pod Subscribe to an event from this object. C<event_name> is the name of the event.
#pod C<subref> is a subroutine reference that will get either a L<Beam::Event> object
#pod (if using the L<emit> method) or something else (if using the L<emit_args> method).
#pod
#pod Returns a coderef that, when called, unsubscribes the new subscriber.
#pod
#pod     my $unsubscribe = $emitter->subscribe( open_door => sub {
#pod         warn "ding!";
#pod     } );
#pod     $emitter->emit( 'open_door' );  # ding!
#pod     $unsubscribe->();
#pod     $emitter->emit( 'open_door' );  # no ding
#pod
#pod This unsubscribe subref makes it easier to stop our subscription in a safe,
#pod non-leaking way:
#pod
#pod     my $unsub;
#pod     $unsub = $emitter->subscribe( open_door => sub {
#pod         $unsub->(); # Only handle one event
#pod     } );
#pod     $emitter->emit( 'open_door' );
#pod
#pod The above code does not leak memory, but the following code does:
#pod
#pod     # Create a memory cycle which must be broken manually
#pod     my $cb;
#pod     $cb = sub {
#pod         my ( $event ) = @_;
#pod         $event->emitter->unsubscribe( open_door => $cb ); # Only handle one event
#pod         # Because the callback sub ($cb) closes over a reference to itself
#pod         # ($cb), it can never be cleaned up unless something breaks the
#pod         # cycle explicitly.
#pod     };
#pod     $emitter->subscribe( open_door => $cb );
#pod     $emitter->emit( 'open_door' );
#pod
#pod The way to fix this second example is to explicitly C<undef $cb> inside the callback
#pod sub. Forgetting to do that will result in a leak. The returned unsubscribe coderef
#pod does not have this issue.
#pod
#pod By default, the emitter only stores the subroutine reference in an
#pod object of class L<Beam::Listener>.  If more information should be
#pod stored, create a custom subclass of L<Beam::Listener> and use C<%args>
#pod to specify the class name and any attributes to be passed to its
#pod constructor:
#pod
#pod   {
#pod     package MyListener;
#pod     extends 'Beam::Listener';
#pod
#pod     # add metadata with subscription time
#pod     has sub_time => is ( 'ro',
#pod 			  init_arg => undef,
#pod 			  default => sub { time() },
#pod     );
#pod   }
#pod
#pod   # My::Emitter consumes the Beam::Emitter role
#pod   my $emitter = My::Emitter->new;
#pod   $emitter->on( "foo",
#pod     sub { print "Foo happened!\n"; },
#pod    class => MyListener
#pod   );
#pod
#pod The L</listeners> method can be used to examine the subscribed listeners.
#pod
#pod
#pod =cut

sub subscribe {
  my ( $self, $name, $sub, %args ) = @_;

  my $class = delete $args{class} || "Beam::Listener";
  croak("listener object must descend from Beam::Listener")
    unless use_module($class)->isa('Beam::Listener');

  my $listener = $class->new( %args, callback => $sub );

  push @{ $self->_listeners->{$name} }, $listener;
  weaken $self;
  weaken $sub;
  return sub {
    $self->unsubscribe( $name => $sub )
      if defined $self;
  };
}

#pod =method on ( event_name, subref )
#pod
#pod An alias for L</subscribe>. B<NOTE>: Do not use this alias for method
#pod modifiers! If you want to override behavior, override C<subscribe>.
#pod
#pod =cut

sub on { shift->subscribe(@_) }

#pod =method unsubscribe ( event_name [, subref ] )
#pod
#pod Unsubscribe from an event. C<event_name> is the name of the event. C<subref> is
#pod the single listener subref to be removed. If no subref is given, will remove
#pod all listeners for this event.
#pod
#pod =cut

sub unsubscribe {
  my ( $self, $name, $sub ) = @_;
  if ( !$sub ) {
    delete $self->_listeners->{$name};
  }
  else {
    my $listeners = $self->_listeners->{$name};
    my $idx       = 0;
    $idx++ until $idx > $#{$listeners} or refaddr $listeners->[$idx]->callback eq refaddr $sub;
    if ( $idx > $#{$listeners} ) {
      croak "Could not find sub in listeners";
    }
    splice @{ $self->_listeners->{$name} }, $idx, 1;
  }
  return;
}

#pod =method un ( event_name [, subref ] )
#pod
#pod An alias for L</unsubscribe>. B<NOTE>: Do not use this alias for method
#pod modifiers! If you want to override behavior, override C<unsubscribe>.
#pod
#pod =cut

sub un { shift->unsubscribe(@_) }

#pod =method emit ( name, event_args )
#pod
#pod Emit a L<Beam::Event> with the given C<name>. C<event_args> is a list of name => value
#pod pairs to give to the C<Beam::Event> constructor.
#pod
#pod Use the C<class> key in C<event_args> to specify a different Event class.
#pod
#pod =cut

sub emit {
  my ( $self, $name, %args ) = @_;

  my $class = delete $args{class} || "Beam::Event";
  $args{emitter} = $self if !defined $args{emitter};
  $args{name} ||= $name;
  my $event = $class->new(%args);

  return $event unless exists $self->_listeners->{$name};

  # don't use $self->_listeners->{$name} directly, as callbacks may unsubscribe
  # from $name, changing the array, and confusing the for loop
  my @listeners = @{ $self->_listeners->{$name} };

  for my $listener (@listeners) {
    $listener->callback->($event);
    last if $event->is_stopped;
  }
  return $event;
}

#pod =method emit_args ( name, callback_args )
#pod
#pod Emit an event with the given C<name>. C<callback_args> is a list that will be given
#pod directly to each subscribed callback.
#pod
#pod Use this if you want to avoid using L<Beam::Event>, though you miss out on the control
#pod features like L<stop|Beam::Event/stop> and L<stop default|Beam::Event/stop_default>.
#pod
#pod =cut

sub emit_args {
  my ( $self, $name, @args ) = @_;

  return unless exists $self->_listeners->{$name};

  # don't use $self->_listeners->{$name} directly, as callbacks may unsubscribe
  # from $name, changing the array, and confusing the for loop
  my @listeners = @{ $self->_listeners->{$name} };

  for my $listener (@listeners) {
    $listener->callback->(@args);
  }
  return;
}

#pod =method listeners ( event_name )
#pod
#pod Returns a list containing the listeners which have subscribed to the
#pod specified event from this emitter.  The list elements are either
#pod instances of L<Beam::Listener> or of custom classes specified in calls
#pod to L</subscribe>.
#pod
#pod =cut

sub listeners {

  my ( $self, $name ) = @_;

  return @{ $self->_listeners->{$name} || [] };
}

1;

__END__

