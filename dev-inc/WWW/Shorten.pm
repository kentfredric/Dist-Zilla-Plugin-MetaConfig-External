package WWW::Shorten;

use 5.008001;
use strict;
use warnings;

use base qw(WWW::Shorten::generic);
use Carp ();

our $DEFAULT_SERVICE = 'TinyURL';
our @EXPORT          = qw(makeashorterlink makealongerlink);
our $VERSION         = '3.093';
$VERSION = eval $VERSION;

my $style;

sub import {
  my $class = shift;
  $style = shift;
  $style = $DEFAULT_SERVICE unless defined $style;
  my $package = "${class}::${style}";
  eval {
    my $file = $package;
    $file =~ s/::/\//g;
    require "$file.pm";
  };
  Carp::croak($@) if $@;
  $package->import(@_);
}

1;

