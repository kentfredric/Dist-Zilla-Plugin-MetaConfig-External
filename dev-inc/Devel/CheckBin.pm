package Devel::CheckBin;
use strict;
use warnings;
use 5.008001;
our $VERSION = "0.04";
use parent qw(Exporter);

our @EXPORT = qw(can_run check_bin);

use ExtUtils::MakeMaker;
use File::Spec;
use Config;

# Check if we can run some command
sub can_run {
  my ($cmd) = @_;

  my $_cmd = $cmd;
  return $_cmd if ( -x $_cmd or $_cmd = MM->maybe_command($_cmd) );

  for my $dir ( ( split /$Config::Config{path_sep}/, $ENV{PATH} ), '.' ) {
    next if $dir eq '';
    my $abs = File::Spec->catfile( $dir, $cmd );
    return $abs if ( -x $abs or $abs = MM->maybe_command($abs) );
  }

  return;
}

sub check_bin {
  my ( $bin, $version ) = @_;
  if ($version) {
    die "check_bin does not support versions yet";
  }

  # Locate the bin
  print "Locating bin:$bin...";
  my $found_bin = can_run($bin);
  if ($found_bin) {
    print " found at $found_bin.\n";
    return 1;
  }
  else {
    print " missing.\n";
    print "Unresolvable missing external dependency.\n";
    print "Please install '$bin' seperately and try again.\n";
    print STDERR "NA: Unable to build distribution on this platform.\n";
    exit(0);
  }
}

1;
__END__

