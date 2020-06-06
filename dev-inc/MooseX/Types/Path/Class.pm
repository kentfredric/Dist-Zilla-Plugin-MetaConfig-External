use strict;
use warnings;

package MooseX::Types::Path::Class;    # git description: v0.08-5-gc1e201f

# ABSTRACT: A Path::Class type library for Moose

our $VERSION = '0.09';

use Path::Class 0.16 ();

use MooseX::Types -declare => [qw( Dir File )];

use MooseX::Types::Moose qw(Str ArrayRef);
use if MooseX::Types->VERSION >= 0.42, 'namespace::autoclean';

class_type('Path::Class::Dir');
class_type('Path::Class::File');

subtype Dir,  as 'Path::Class::Dir';
subtype File, as 'Path::Class::File';

for my $type ( 'Path::Class::Dir', Dir ) {
  coerce $type, from Str, via { Path::Class::Dir->new($_) }, from ArrayRef, via { Path::Class::Dir->new(@$_) };
}

for my $type ( 'Path::Class::File', File ) {
  coerce $type, from Str, via { Path::Class::File->new($_) }, from ArrayRef, via { Path::Class::File->new(@$_) };
}

# optionally add Getopt option type
eval { require MooseX::Getopt; };
if ( !$@ ) {
  MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_, '=s', ) for ( 'Path::Class::Dir', 'Path::Class::File', Dir, File, );
}

1;

__END__

