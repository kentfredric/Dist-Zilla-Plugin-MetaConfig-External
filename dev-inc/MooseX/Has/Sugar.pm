use 5.006;    # pragmas, qr
use warnings;
use strict;

package MooseX::Has::Sugar;

our $VERSION = '1.000006';

# ABSTRACT: Sugar Syntax for moose 'has' fields

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Carp ();
use Sub::Exporter::Progressive (
  -setup => {
    exports => [ 'ro', 'rw', 'required', 'lazy', 'lazy_build', 'coerce', 'weak_ref', 'auto_deref', 'bare', ],
    groups  => {
      isattrs => [ 'ro',       'rw',   'bare', ],
      attrs   => [ 'required', 'lazy', 'lazy_build', 'coerce', 'weak_ref', 'auto_deref', ],
      default => [ 'ro',       'rw',   'bare', 'required', 'lazy', 'lazy_build', 'coerce', 'weak_ref', 'auto_deref', ],
    },
  },
);

sub bare() {
  return ( 'is', 'bare' );
}

sub ro() {
  return ( 'is', 'ro' );
}

sub rw() {
  return ( 'is', 'rw' );
}

sub required() {
  return ( 'required', 1 );
}

sub lazy() {
  return ( 'lazy', 1 );
}

sub lazy_build() {
  return ( 'lazy_build', 1 );
}

sub weak_ref() {
  return ( 'weak_ref', 1 );
}

sub coerce() {
  return ( 'coerce', 1 );
}

sub auto_deref() {
  return ( 'auto_deref', 1 );
}
1;

__END__

