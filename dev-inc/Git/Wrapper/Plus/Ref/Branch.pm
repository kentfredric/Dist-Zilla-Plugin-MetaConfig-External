use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Ref::Branch;

our $VERSION = '0.004011';

# ABSTRACT: A Branch object

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( extends );
extends 'Git::Wrapper::Plus::Ref';

our @CARP_NOT;

## no critic (ProhibitMixedCaseSubs)
sub new_from_Ref {
  my ( $class, $source_object ) = @_;
  if ( not $source_object->can('name') ) {
    require Carp;
    return Carp::croak("Object $source_object does not respond to ->name, cannot Ref -> Branch");
  }
  my $name = $source_object->name;
  ## no critic ( Compatibility::PerlMinimumVersionAndWhy )
  if ( $name =~ qr{\Arefs/heads/(.+\z)}msx ) {
    return $class->new(
      git  => $source_object->git,
      name => $1,
    );
  }
  require Carp;
  Carp::croak("Path $name is not in refs/heads/*, cannot convert to Branch object");
}

sub refname {
  my ($self) = @_;
  return 'refs/heads/' . $self->name;
}

## no critic (ProhibitBuiltinHomonyms)

sub delete {
  my ( $self, $params ) = @_;
  if ( $params->{force} ) {
    return $self->git->branch( '-D', $self->name );
  }
  return $self->git->branch( '-d', $self->name );

}

sub move {
  my ( $self, $new_name, $params ) = @_;
  if ( not defined $new_name or not length $new_name ) {
    require Carp;
    ## no critic (ProhibitLocalVars)
    local @CARP_NOT = __PACKAGE__;
    Carp::croak(q[Move requires a defined argument to move to, with length >= 1 ]);
  }
  if ( $params->{force} ) {
    return $self->git->branch( '-M', $self->name, $new_name );
  }
  return $self->git->branch( '-m', $self->name, $new_name );
}

no Moo;
1;

__END__

