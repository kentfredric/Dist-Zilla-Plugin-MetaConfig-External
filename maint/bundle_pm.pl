#!perl
use strict;
use warnings;

use Pod::Strip;
use Path::Tiny qw(path);
use Perl::Strip;

my ( $module, ) = @ARGV;

die "Please specify a module name" unless defined $module and length $module;

my $module_path = get_module_path($module);
my $p           = Pod::Strip->new();

my $output = path('./dev-inc')->child( module_to_path($module) );
$output->parent()->mkpath();

my $content = path($module_path)->slurp_raw;
my $stripped = pod_strip($content);
#$stripped = perl_strip($stripped);

$output->spew_raw( $stripped );
warn "Written $output, @{[ length $stripped ]} b\n";

sub module_to_path {
  my ($module) = @_;
  $module =~ s/::/\//g;
  $module .= '.pm';
  $module;
}

sub get_module_path {
  my ($module) = @_;
  for my $prefix (@INC) {
    my $guess = $prefix . q[/] . module_to_path($module);
    if ( -e $guess ) {
      warn "Found $module in $guess\n";
      return $guess;
    }
  }
  die "Did not find $module in \@INC, is it installed?";
}

sub pod_strip {
  my ($string) = @_;
  my $p = Pod::Strip->new();
  my $out;
  $p->output_string( \$out );
  $p->parse_string_document($string);
  return $out;
}

sub perl_strip {
  my ($string) = @_;
  my $s = Perl::Strip->new(
    optimize_size => 0,

    # not implemented
    keep_nl => 1,
  );
  return $s->strip($string);
}
