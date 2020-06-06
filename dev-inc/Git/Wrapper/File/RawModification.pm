package Git::Wrapper::File::RawModification;

# ABSTRACT: Modification of a file in a commit
$Git::Wrapper::File::RawModification::VERSION = '0.047';
use 5.006;
use strict;
use warnings;

sub new {
  my ( $class, $filename, $type, $perms_from, $perms_to, $blob_from, $blob_to ) = @_;

  my $score;
  if ( defined $type && $type =~ s{^(.)([0-9]+)$}{$1} ) {
    $score = $2;
    ( undef, $filename ) = split( qr{\s+}, $filename, 2 );
  }

  return bless {
    filename   => $filename,
    type       => $type,
    score      => $score,
    perms_from => $perms_from,
    perms_to   => $perms_to,
    blob_from  => $blob_from,
    blob_to    => $blob_to,
  } => $class;
}

sub filename { shift->{filename} }
sub type     { shift->{type} }
sub score    { shift->{score} }

sub perms_from { shift->{perms_from} }
sub perms_to   { shift->{perms_to} }

sub blob_from { shift->{blob_from} }
sub blob_to   { shift->{blob_to} }

1;

__END__

