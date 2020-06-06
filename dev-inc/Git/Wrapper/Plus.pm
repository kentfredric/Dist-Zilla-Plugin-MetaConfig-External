use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus;

our $VERSION = '0.004011';

# ABSTRACT: A Toolkit for working with Git::Wrapper in an Object Oriented Way.

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );
use Scalar::Util qw( blessed );

sub BUILDARGS {
  my ( undef, @args ) = @_;
  if ( 1 == @args ) {
  blesscheck: {
      if ( blessed $args[0] ) {
        if ( $args[0]->isa('Path::Tiny') ) {
          $args[0] = q[] . $args[0];
          last blesscheck;
        }
        if ( $args[0]->isa('Path::Class::Dir') ) {
          $args[0] = q[] . $args[0];
          last blesscheck;
        }
        if ( $args[0]->isa('Path::Class::File') ) {
          $args[0] = q[] . $args[0];
          last blesscheck;
        }
        return { git => $args[0] };
      }
    }
    return $args[0] if ref $args[0];

    require Git::Wrapper;
    return { git => Git::Wrapper->new( $args[0] ) };
  }
  return {@args};
}

has git => ( is => ro =>, required => 1 );

has refs => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_refs {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Refs;
  return Git::Wrapper::Plus::Refs->new( git => $self->git );
}

has tags => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_tags {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Tags;
  return Git::Wrapper::Plus::Tags->new( git => $self->git );
}

has branches => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_branches {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Branches;
  return Git::Wrapper::Plus::Branches->new( git => $self->git );
}

has versions => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_versions {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Versions;
  return Git::Wrapper::Plus::Versions->new( git => $self->git );
}

has support => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_support {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Support;
  return Git::Wrapper::Plus::Support->new( git => $self->git );
}

1;

__END__

