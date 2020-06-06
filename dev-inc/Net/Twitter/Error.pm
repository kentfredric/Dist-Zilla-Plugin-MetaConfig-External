package Net::Twitter::Error;
$Net::Twitter::Error::VERSION = '4.01043';
use Moose;
use Try::Tiny;
use Devel::StackTrace;

use overload (

  # We can't use 'error' directly, because overloads are called with three
  # arguments ($self, undef, '') resulting in an error:
  # Cannot assign a value to a read-only accessor
  '""' => sub { shift->error },

  fallback => 1,
);

has http_response => (
  isa      => 'HTTP::Response',
  is       => 'ro',
  required => 1,
  handles  => [qw/code message/],
);

has twitter_error => (
  is        => 'ro',
  predicate => 'has_twitter_error',
);

has stack_trace => (
  is       => 'ro',
  init_arg => undef,
  builder  => '_build_stack_trace',
  handles  => {
    stack_frame => 'frame',
  },
);

sub _build_stack_trace {
  my $seen;
  my $this_sub = ( caller 0 )[3];
  Devel::StackTrace->new(
    frame_filter => sub {
      my $caller = shift->{caller};
      my $in_nt  = $caller->[0] =~ /^Net::Twitter::/ || $caller->[3] eq $this_sub;
      ( $seen ||= $in_nt ) && !$in_nt || 0;
    }
  );
}

has error => (
  is       => 'ro',
  init_arg => undef,
  lazy     => 1,
  builder  => '_build_error',
);

sub _build_error {
  my $self = shift;

  my $error = $self->twitter_error_text || $self->http_response->status_line;
  my ($location) = $self->stack_frame(0)->as_string =~ /( at .*)/;
  return $error . ( $location || '' );
}

sub twitter_error_text {
  my $self = shift;

  # Twitter does not return a consistent error structure, so we have to
  # try each known (or guessed) variant to find a suitable message...

  return '' unless $self->has_twitter_error;
  my $e = $self->twitter_error;

  return ref $e eq 'HASH' && (

    # the newest variant: array of errors
    exists $e->{errors}
    && ref $e->{errors} eq 'ARRAY'
    && exists $e->{errors}[0]
    && ref $e->{errors}[0] eq 'HASH'
    && exists $e->{errors}[0]{message}
    && $e->{errors}[0]{message}

    # it's single error variant
    || exists $e->{error}
    && ref $e->{error} eq 'HASH'
    && exists $e->{error}{message}
    && $e->{error}{message}

    # the original error structure (still applies to some endpoints)
    || exists $e->{error} && $e->{error}

    # or maybe it's not that deep (documentation would be helpful, here,
    # Twitter!)
    || exists $e->{message} && $e->{message}
  ) || '';    # punt
}

sub twitter_error_code {
  my $self = shift;

  return
       $self->has_twitter_error
    && exists $self->twitter_error->{errors}
    && exists $self->twitter_error->{errors}[0]
    && exists $self->twitter_error->{errors}[0]{code}
    && $self->twitter_error->{errors}[0]{code}
    || 0;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

