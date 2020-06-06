package Data::DPath;

# git description: v0.56-7-g681b3f6

our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: DPath is not XPath!
$Data::DPath::VERSION = '0.57';
use 5.008;
use strict;
use warnings;

our $DEBUG       = 0;
our $USE_SAFE    = 1;
our $PARALLELIZE = 0;

use Data::DPath::Path;
use Data::DPath::Context;

sub build_dpath {
  return sub ($) {
    my ($path_str) = @_;
    Data::DPath::Path->new( path => $path_str );
  };
}

sub build_dpathr {
  return sub ($) {
    my ($path_str) = @_;
    Data::DPath::Path->new( path => $path_str, give_references => 1 );
  };
}

sub build_dpathi {
  return sub ($) {
    my ( $data, $path_str ) = @_;

    Data::DPath::Context->new->current_points( [ Data::DPath::Point->new->ref( \$data ) ] )
      ->_search( Data::DPath::Path->new( path => "/" ) )->_iter->value;    # there is always exactly one root "/"
  };
}

use Sub::Exporter -setup => {
  exports => [
    dpath  => \&build_dpath,
    dpathr => \&build_dpathr,
    dpathi => \&build_dpathi,
  ],
  groups => { all => [ 'dpath', 'dpathr' ] },
};

sub match {
  my ( $class, $data, $path_str ) = @_;
  Data::DPath::Path->new( path => $path_str )->match($data);
}

sub matchr {
  my ( $class, $data, $path_str ) = @_;
  Data::DPath::Path->new( path => $path_str )->matchr($data);
}

# ------------------------------------------------------------

1;

__END__

