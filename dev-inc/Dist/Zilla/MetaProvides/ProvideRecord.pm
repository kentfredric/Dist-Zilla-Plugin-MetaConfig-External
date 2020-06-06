use 5.006;
use strict;
use warnings;

package Dist::Zilla::MetaProvides::ProvideRecord;

our $VERSION = '2.002004';

# ABSTRACT: Data Management Record for MetaProvider::Provides Based Class

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moose qw( has );
use MooseX::Types::Moose qw( Str );
use Dist::Zilla::MetaProvides::Types qw( ModVersion ProviderObject );

use namespace::autoclean;

has version => ( isa => ModVersion, is => 'ro', required => 1 );

has module => ( isa => Str, is => 'ro', required => 1 );

has file => ( isa => Str, is => 'ro', required => 1 );

has parent => (
  is       => 'ro',
  required => 1,
  weak_ref => 1,
  isa      => ProviderObject,
  handles  => [ 'zilla', '_resolve_version', ],
);

__PACKAGE__->meta->make_immutable;
no Moose;

sub copy_into {
  my $self  = shift;
  my $dlist = shift;
  $dlist->{ $self->module } = {
    file => $self->file,
    $self->_resolve_version( $self->version ),
  };
  return 1;
}

1;

__END__

