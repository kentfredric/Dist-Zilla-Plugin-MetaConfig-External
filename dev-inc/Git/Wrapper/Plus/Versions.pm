use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Versions;

our $VERSION = '0.004011';

# ABSTRACT: Analyze and compare git versions

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );
use Sort::Versions qw( versioncmp );

has git => required => 1, is => ro =>;

sub current_version {
  my ($self) = @_;
  return $self->git->version;
}

sub newer_than {
  my ( $self, $v ) = @_;
  return versioncmp( $self->current_version, $v ) >= 0;
}

sub older_than {
  my ( $self, $v ) = @_;
  return versioncmp( $self->current_version, $v ) < 0;
}

no Moo;
1;

__END__

