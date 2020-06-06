use strict;

package Path::Class;
{
  $Path::Class::VERSION = '0.37';
}

{
  ## no critic
  no strict 'vars';
  @ISA       = qw(Exporter);
  @EXPORT    = qw(file dir);
  @EXPORT_OK = qw(file dir foreign_file foreign_dir tempdir);
}

use Exporter;
use Path::Class::File;
use Path::Class::Dir;
use File::Temp ();

sub file         { Path::Class::File->new(@_) }
sub dir          { Path::Class::Dir->new(@_) }
sub foreign_file { Path::Class::File->new_foreign(@_) }
sub foreign_dir  { Path::Class::Dir->new_foreign(@_) }
sub tempdir      { Path::Class::Dir->new( File::Temp::tempdir(@_) ) }

1;
__END__

