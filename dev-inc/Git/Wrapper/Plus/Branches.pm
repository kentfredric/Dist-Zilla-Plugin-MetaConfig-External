use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Branches;

our $VERSION = '0.004011';

# ABSTRACT: Extract branches from Git

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );
use Git::Wrapper::Plus::Util qw(exit_status_handler);

has 'git'  => ( is => ro =>, required => 1 );
has 'refs' => ( is => ro =>, lazy     => 1, builder => 1 );

sub _build_refs {
  my ($self) = @_;
  require Git::Wrapper::Plus::Refs;
  return Git::Wrapper::Plus::Refs->new( git => $self->git );
}

sub _to_branch {
  my ( undef, $ref ) = @_;
  require Git::Wrapper::Plus::Ref::Branch;
  return Git::Wrapper::Plus::Ref::Branch->new_from_Ref($ref);
}

sub _to_branches {
  my ( $self, @refs ) = @_;
  return map { $self->_to_branch($_) } @refs;
}

sub branches {
  my ( $self, ) = @_;
  return $self->get_branch(q[**]);
}

sub get_branch {
  my ( $self, $name ) = @_;
  return $self->_to_branches( $self->refs->get_ref( 'refs/heads/' . $name ) );
}

sub _current_branch_name {
  my ($self) = @_;
  my (@current_names);
  return unless exit_status_handler(
    sub {
      (@current_names) = $self->git->symbolic_ref('HEAD');
    },
    {
      128 => sub { return },
    },
  );
  s{\A refs/heads/ }{}msx for @current_names;
  return @current_names;

}

sub current_branch {
  my ( $self, ) = @_;
  my ($ref) = $self->_current_branch_name;
  return if not $ref;
  my (@items) = $self->get_branch($ref);
  return shift @items if 1 == @items;
  require Carp;
  Carp::confess( 'get_branch(' . $ref . ') returned multiple values. Cannot determine current branch' );
}

no Moo;

1;

__END__

