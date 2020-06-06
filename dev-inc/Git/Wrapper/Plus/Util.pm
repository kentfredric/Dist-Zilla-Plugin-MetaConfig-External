use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Util;

our $VERSION = '0.004011';

# ABSTRACT: Misc plumbing tools for Git::Wrapper::Plus

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Sub::Exporter::Progressive -setup => {
  exports => [qw( exit_status_handler )],
  groups  => {
    default => [qw( exit_status_handler )],
  },
};

use Try::Tiny qw( try catch );
use Scalar::Util qw(blessed);

sub exit_status_handler {
  my ( $callback, $status_map ) = @_;
  my $return = 1;
  try {
    $callback->();
  }
  catch {
    ## no critic (ErrorHandling::RequireUseOfExceptions)
    undef $return;
    die $_ unless ref;
    die $_ unless blessed $_;
    die $_ unless $_->isa('Git::Wrapper::Exception');
    for my $status ( sort keys %{$status_map} ) {
      if ( $status == $_->status ) {
        $return = $status_map->{$status}->($_);
        return;
      }
    }
    die $_;
  };
  return 1 if $return;
  return;
}

1;

__END__

