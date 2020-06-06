#!/usr/bin/perl

package Tie::ToObject;

use strict;

#use warnings;

use vars qw($VERSION $AUTOLOAD);

use Carp qw(croak);
use Scalar::Util qw(blessed);

$VERSION = "0.03";

sub AUTOLOAD {
  my ( $self, $tied ) = @_;
  my ($method) = ( $AUTOLOAD =~ /([^:]+)$/ );

  if ( $method =~ /^TIE/ ) {
    if ( blessed($tied) ) {
      return $tied;
    }
    else {
      croak "You must supply an object as the argument to tie()";
    }
  }
  else {
    croak "Unsupported method for $method, this module is only for tying to existing objects";
  }
}

__PACKAGE__

__END__

