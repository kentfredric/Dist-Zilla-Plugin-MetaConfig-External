use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Ref;

our $VERSION = '0.004011';

# ABSTRACT: An Abstract REF node

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

has 'name' => ( is => ro =>, required => 1 );
has 'git'  => ( is => ro =>, required => 1 );

sub refname {
  my ($self) = @_;
  return $self->name;
}

sub sha1 {
  my ($self)    = @_;
  my ($refname) = $self->refname;
  my (@sha1s)   = $self->git->rev_parse($refname);
  if ( scalar @sha1s > 1 ) {
    require Carp;
    return Carp::confess( q[Fatal: rev-parse ] . $refname . q[ returned multiple values] );
  }
  return shift @sha1s;
}

no Moo;
1;

__END__

