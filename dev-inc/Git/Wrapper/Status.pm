use 5.006;
use strict;
use warnings;

package Git::Wrapper::Status;

# ABSTRACT: A specific status information in the Git
$Git::Wrapper::Status::VERSION = '0.047';
my %modes = (
  M   => 'modified',
  A   => 'added',
  D   => 'deleted',
  R   => 'renamed',
  C   => 'copied',
  U   => 'conflict',
  '?' => 'unknown',
  DD  => 'both deleted',
  AA  => 'both added',
  UU  => 'both modified',
  AU  => 'added by us',
  DU  => 'deleted by us',
  UA  => 'added by them',
  UD  => 'deleted by them',
);

sub new {
  my ( $class, $mode, $from, $to ) = @_;

  return bless {
    mode => $mode,
    from => $from,
    to   => $to,
  } => $class;
}

sub mode { $modes{ shift->{mode} } }

sub from { shift->{from} }

sub to { defined( $_[0]->{to} ) ? $_[0]->{to} : '' }

1;

__END__

