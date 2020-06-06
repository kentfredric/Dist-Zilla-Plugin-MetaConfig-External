use strict;
use warnings;

package MooseX::Types::Path::Tiny;    # git description: v0.011-21-g8796f45

# ABSTRACT: Path::Tiny types and coercions for Moose
# KEYWORDS: moose type constraint path filename directory
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.012';

use Moose 2;
use MooseX::Types::Stringlike qw/Stringable/;
use MooseX::Types::Moose qw/Str ArrayRef/;
use MooseX::Types -declare => [
  qw/
    Path AbsPath
    File AbsFile
    Dir AbsDir
    Paths AbsPaths
    /
];
use Path::Tiny ();
use if MooseX::Types->VERSION >= 0.42, 'namespace::autoclean';

#<<<
subtype Path,    as 'Path::Tiny';
subtype AbsPath, as Path, where { $_->is_absolute };

subtype File,    as Path, where { $_->is_file }, message { "File '$_' does not exist" };
subtype Dir,     as Path, where { $_->is_dir },  message { "Directory '$_' does not exist" };

subtype AbsFile, as AbsPath, where { $_->is_file }, message { "File '$_' does not exist" };
subtype AbsDir,  as AbsPath, where { $_->is_dir },  message { "Directory '$_' does not exist" };

subtype Paths,   as ArrayRef[Path];
subtype AbsPaths, as ArrayRef[AbsPath];
#>>>

for my $type ( 'Path::Tiny', Path, File, Dir ) {
  coerce(
    $type,
    from Str()        => via { Path::Tiny::path($_) },
    from Stringable() => via { Path::Tiny::path($_) },
    from ArrayRef()   => via { Path::Tiny::path(@$_) },
  );
}

for my $type ( AbsPath, AbsFile, AbsDir ) {
  coerce(
    $type,
    from
      'Path::Tiny' => via { $_->absolute },
    from Str()        => via { Path::Tiny::path($_)->absolute },
    from Stringable() => via { Path::Tiny::path($_)->absolute },
    from ArrayRef()   => via { Path::Tiny::path(@$_)->absolute },
  );
}

coerce(
  Paths,
  from Path()       => via { [$_] },
  from Str()        => via { [ Path::Tiny::path($_) ] },
  from Stringable() => via { [ Path::Tiny::path($_) ] },
  from ArrayRef()   => via {
    [ map { Path::Tiny::path($_) } @$_ ]
  },
);

coerce(
  AbsPaths,
  from AbsPath()    => via { [$_] },
  from Str()        => via { [ Path::Tiny::path($_)->absolute ] },
  from Stringable() => via { [ Path::Tiny::path($_)->absolute ] },
  from ArrayRef()   => via {
    [ map { Path::Tiny::path($_)->absolute } @$_ ]
  },
);

# optionally add Getopt option type (adapted from MooseX::Types:Path::Class)
if ( eval { require MooseX::Getopt; 1 } ) {
  for my $type ( 'Path::Tiny', Path, AbsPath, File, AbsFile, Dir, AbsDir, Paths, AbsPaths, ) {
    MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $type, '=s', );
  }
}

1;

__END__

