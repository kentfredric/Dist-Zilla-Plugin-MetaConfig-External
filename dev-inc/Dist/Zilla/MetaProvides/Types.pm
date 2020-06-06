use 5.006;
use strict;
use warnings;

package Dist::Zilla::MetaProvides::Types;

our $VERSION = '2.002004';

# ABSTRACT: Utility Types for the MetaProvides Plugin

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use MooseX::Types::Moose qw( Str Undef Object );
use MooseX::Types -declare => [qw( ModVersion ProviderObject )];

## no critic (Bangs::ProhibitBitwiseOperators)
subtype ModVersion, as Str | Undef;

subtype ProviderObject, as Object, where { $_->does('Dist::Zilla::Role::MetaProvider::Provider') };

1;

__END__

