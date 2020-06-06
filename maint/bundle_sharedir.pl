#!perl
use strict;
use warnings;

use Pod::Strip;
use Path::Tiny qw(path);
use Perl::Strip;

my ( $dist, ) = @ARGV;

die "Please specify a dist name" unless defined $dist and length $dist;

my $distname = distify($dist);
my $distdir  = get_dist_dir($distname);
my $outdir   = path('./dev-inc/auto/share/dist/')->child($distname);

path($distdir)->visit(
  sub {
    my ( $path, $state ) = @_;
    return 1 if $path->basename eq '.keep';
    my $outfile = $path->relative($distdir)->absolute($outdir);
    $outfile->parent()->mkpath;
    warn "Copying:\n\t-     $path\n\t- to: $outfile\n";
    $path->copy($outfile);
  },
  {
    recurse => 1,
  }
);

sub distify {
  my ($module) = @_;
  $module =~ s/::/-/g;
  return $module;
}

sub get_dist_dir {
  my ($dist) = @_;
  for my $prefix (@INC) {
    my $guess = $prefix . q[/auto/share/dist/] . $dist;
    if ( -e $guess and -d $guess ) {
      warn "Found $dist in $guess\n";
      return $guess;
    }
  }
  die "Did not find $dist in \@INC, is it installed?";

}
