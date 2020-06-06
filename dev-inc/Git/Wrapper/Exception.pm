package Git::Wrapper::Exception;

# ABSTRACT: Exception class for Git::Wrapper
$Git::Wrapper::Exception::VERSION = '0.047';
use 5.006;
use strict;
use warnings;

sub new { my $class = shift; bless {@_} => $class }

use overload (
  q("")    => '_stringify',
  fallback => 1,
);

sub _stringify {
  my ($self) = @_;
  my $error = $self->error;
  return $error if $error =~ /\S/;
  return "git exited non-zero but had no output to stderr";
}

sub output {
  join "", map { "$_\n" } @{ shift->{output} };
}

sub error {
  join "", map { "$_\n" } @{ shift->{error} };
}

sub status { shift->{status} }

1;

__END__

