use strict;
use warnings;

package MooseX::Types::URI;    # git description: v0.07-13-g73c0cd8

# ABSTRACT: URI related types and coercions for Moose
# KEYWORDS: moose types constraints coercions uri path web

our $VERSION = '0.08';

use Scalar::Util qw(blessed);

use URI;
use URI::QueryParam;
use URI::WithBase;

use MooseX::Types::Moose qw{Str ScalarRef HashRef};
use MooseX::Types::Path::Class qw{File Dir};

use MooseX::Types 0.40 -declare => [qw(Uri _UriWithBase _Uri FileUri DataUri)];
use if MooseX::Types->VERSION >= 0.42, 'namespace::autoclean';

my $uri = Moose::Meta::TypeConstraint->new(
  name   => Uri,
  parent => Moose::Meta::TypeConstraint::Union->new(
    name             => join( "|", _Uri, _UriWithBase ),
    type_constraints => [ class_type( _Uri, { class => "URI" } ), class_type( _UriWithBase, { class => "URI::WithBase" } ), ],
  ),
  (
    $Moose::VERSION >= 2.0100
    ? ( inline_as =>
        sub { 'local $@; blessed(' . $_[1] . ') && ( ' . $_[1] . '->isa("URI") || ' . $_[1] . '->isa("URI::WithBase") )' } )
    : ( optimized => sub { local $@; blessed( $_[0] ) && ( $_[0]->isa("URI") || $_[0]->isa("URI::WithBase") ) } )
  ),
);

register_type_constraint($uri);

coerce( Uri,
  from Str,
  via { URI->new($_) },
  from "Path::Class::File",
  via { require URI::file; URI::file::->new($_) },
  from "Path::Class::Dir",
  via { require URI::file; URI::file::->new($_) },
  from File,
  via { require URI::file; URI::file::->new($_) },
  from Dir,
  via { require URI::file; URI::file::->new($_) },
  from ScalarRef,
  via { my $u = URI->new("data:"); $u->data($$_); $u },
  from HashRef,
  via { require URI::FromHash; URI::FromHash::uri_object(%$_) },
);

class_type FileUri, { class => "URI::file", parent => $uri };

coerce( FileUri,
  from Str,
  via { require URI::file; URI::file::->new($_) },
  from File,
  via { require URI::file; URI::file::->new($_) },
  from Dir,
  via { require URI::file; URI::file::->new($_) },
  from "Path::Class::File",
  via { require URI::file; URI::file::->new($_) },
  from "Path::Class::Dir",
  via { require URI::file; URI::file::->new($_) },
);

class_type DataUri, { class => "URI::data" };

coerce( DataUri, from Str,
  via { my $u = URI->new("data:"); $u->data($_); $u },
  from ScalarRef,
  via { my $u = URI->new("data:"); $u->data($$_); $u },
);

1;

__END__

