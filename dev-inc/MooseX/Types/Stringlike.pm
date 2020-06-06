use 5.008001;
use strict;
use warnings;

package MooseX::Types::Stringlike;

# ABSTRACT: Moose type constraints for strings or string-like objects
our $VERSION = '0.003';    # VERSION

use MooseX::Types -declare => [qw/Stringable Stringlike ArrayRefOfStringable ArrayRefOfStringlike /];
use MooseX::Types::Moose qw/Str Object ArrayRef/;
use overload ();

# Thanks ilmari for suggesting something like this
subtype Stringable, as Object, where { overload::Method( $_, '""' ) };

subtype Stringlike, as Str;

coerce Stringlike, from Stringable, via { "$_" };

subtype ArrayRefOfStringable, as ArrayRef [Stringable];

subtype ArrayRefOfStringlike, as ArrayRef [Stringlike];

coerce ArrayRefOfStringlike, from ArrayRefOfStringable, via {
  [ map { "$_" } @$_ ]
};

1;

# vim: ts=2 sts=2 sw=2 et:

__END__

