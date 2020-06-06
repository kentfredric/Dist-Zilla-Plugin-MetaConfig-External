use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Support::Range;

our $VERSION = '0.004011';

# ABSTRACT: A record describing a range of supported versions

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

our @CARP_NOT;

has 'min' => ( is => ro =>, predicate => 'has_min' );
has 'max' => ( is => ro =>, predicate => 'has_max' );

has 'min_tag' => ( is => ro =>, predicate => 'has_min_tag' );
has 'max_tag' => ( is => ro =>, predicate => 'has_max_tag' );

has 'min_sha1' => ( is => ro =>, predicate => 'has_min_sha1' );
has 'max_sha1' => ( is => ro =>, predicate => 'has_max_sha1' );

sub BUILD {
  my ($self) = @_;
  if ( not $self->min and not $self->max ) {
    require Carp;
    ## no critic (Variables::ProhibitLocalVars)
    local (@CARP_NOT) = ('Git::Wrapper::Plus::Support::Range');
    Carp::croak('Invalid range, must specify either min or max, or both');
  }
}

sub supports_version {
  my ( $self, $versions_object ) = @_;
  if ( $self->has_min and not $self->has_max ) {
    return 1 if $versions_object->newer_than( $self->min );
    return;
  }
  if ( $self->has_max and not $self->has_min ) {
    return 1 if $versions_object->older_than( $self->max );
    return;
  }
  return unless $versions_object->newer_than( $self->min );
  return unless $versions_object->older_than( $self->max );
  return 1;
}

no Moo;
1;

__END__

