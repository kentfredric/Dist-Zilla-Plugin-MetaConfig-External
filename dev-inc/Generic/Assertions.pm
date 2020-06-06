use 5.006;
use strict;
use warnings;

package Generic::Assertions;

our $VERSION = '0.001002';

# ABSTRACT: A Generic Assertion checking class

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Carp qw( croak carp );

sub new {
  my ( $class, @args ) = @_;
  if ( @args % 2 == 1 and not ref $args[0] ) {
    croak '->new() expects even number of arguments or a hash reference, got ' . scalar @args . ' argument(s)';
  }
  my $hash;
  if ( ref $args[0] ) {
    $hash = { args => $args[0] };
  }
  else {
    $hash = { args => {@args} };
  }
  my $self = bless $hash, $class;
  $self->BUILD;
  return $self;
}

sub BUILD {
  my ($self) = @_;
  my $tests = $self->_tests;
  for my $test ( keys %{$tests} ) {
    croak 'test ' . $test . ' must be a CodeRef' if not 'CODE' eq ref $tests->{$test};
  }
  my $handlers = $self->_handlers;
  for my $handler ( keys %{$handlers} ) {
    croak 'handler ' . $handler . ' must be a CodeRef' if not 'CODE' eq ref $handlers->{$handler};
  }
  croak 'input_transformer must be a CodeRef' if not 'CODE' eq ref $self->_input_transformer;
  return;
}

sub _args {
  my ($self) = @_;
  return $self->{args} if exists $self->{args};
  return ( $self->{args} = {} );
}

sub _tests {
  my ( $self, ) = @_;
  return $self->{tests} if exists $self->{tests};
  my %tests;
  for my $key ( grep { !/\A-/msx } keys %{ $self->_args } ) {
    $tests{$key} = $self->_args->{$key};
  }
  return ( $self->{tests} = { %tests, %{ $self->_args->{'-tests'} || {} } } );
}

sub _handlers {
  my ( $self, ) = @_;
  return $self->{handlers} if exists $self->{handlers};
  return ( $self->{handlers} = { %{ $self->_handler_defaults }, %{ $self->_args->{'-handlers'} || {} } } );
}

sub _handler_defaults {
  return {
    test => sub {
      my ($status) = @_;
      return $status;
    },
    log => sub {
      my ( $status, $message, $name, @slurpy ) = @_;
      carp sprintf 'Assertion < log %s > = %s : %s', $name, ( $status || '0' ), $message;
      return $slurpy[0];
    },
    should => sub {
      my ( $status, $message, $name, @slurpy ) = @_;
      carp "Assertion < should $name > failed: $message" unless $status;
      return $slurpy[0];
    },
    should_not => sub {
      my ( $status, $message, $name, @slurpy ) = @_;
      carp "Assertion < should_not $name > failed: $message" if $status;
      return $slurpy[0];
    },
    must => sub {
      my ( $status, $message, $name, @slurpy ) = @_;
      croak "Assertion < must $name > failed: $message" unless $status;
      return $slurpy[0];
    },
    must_not => sub {
      my ( $status, $message, $name, @slurpy ) = @_;
      croak "Assertion < must_not $name > failed: $message" if $status;
      return $slurpy[0];
    },
  };
}

sub _transform_input {
  my ( $self, $name, @slurpy ) = @_;
  return $self->_input_transformer->( $name, @slurpy );
}

sub _input_transformer {
  my ( $self, ) = @_;
  return $self->{input_transformer} if exists $self->{input_transformer};
  if ( exists $self->_args->{'-input_transformer'} ) {
    return ( $self->{input_transformer} = $self->_args->{'-input_transformer'} );
  }
  return ( $self->{input_transformer} = $self->_input_transformer_default );
}

sub _input_transformer_default {
  return sub { shift; return @_ };
}

# Dispatch the result of test name $test_name
sub _handle {    ## no critic (Subroutines::ProhibitManyArgs)
  my ( $self, $handler_name, $status_code, $message, $test_name, @slurpy ) = @_;
  return $self->_handlers->{$handler_name}->( $status_code, $message, $test_name, @slurpy );
}

# Perform $test_name and return its result
sub _test {
  my ( $self, $test_name, @slurpy ) = @_;
  my $tests = $self->_tests;
  if ( not exists $tests->{$test_name} ) {
    croak sprintf q[INVALID ASSERTION %s ( avail: %s )], $test_name, ( join q[,], keys %{$tests} );
  }
  return $tests->{$test_name}->(@slurpy);
}

# Long form
# ->_assert( should => exist => path('./foo'))
# ->should( exist => path('./foo'))
sub _assert {
  my ( $self, $handler_name, $test_name, @slurpy ) = @_;
  my (@input) = $self->_transform_input( $test_name, @slurpy );
  my ( $status, $message ) = $self->_test( $test_name, @input );
  return $self->_handle( $handler_name, $status, $message, $test_name, @input );
}

for my $handler (qw( should must should_not must_not test log )) {
  my $code = sub {
    my ( $self, $name, @slurpy ) = @_;
    return $self->_assert( $handler, $name, @slurpy );
  };
  {
    ## no critic (TestingAndDebugging::ProhibitNoStrict])
    no strict 'refs';
    *{ __PACKAGE__ . q[::] . $handler } = $code;
  }
}

1;

__END__

