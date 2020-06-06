use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Refs;

our $VERSION = '0.004011';

# ABSTRACT: Work with refs

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

has 'git'     => ( required => 1, is => ro => );
has 'support' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_support {
  my ( $self, ) = @_;
  require Git::Wrapper::Plus::Support;
  return Git::Wrapper::Plus::Support->new( git => $self->git );
}

sub _for_each_ref {
  my ( $self, $refspec, $callback ) = @_;

  my $git_dir = $self->git->dir;

  # git for-each-ref refs/heads/** ==
  #     for-each-ref refs/heads/*  ==
  #     ls-remote    refs/heads/*  + exclude refs/heads/*/*
  #
  # git for-each-refs refs/heads/ ==
  #     ls-remote     refs/heads/*
  #
  if ( $self->support->supports_command('for-each-ref') ) {
    ## no critic (Compatibility::PerlMinimumVersionAndWhy)
    if ( $refspec =~ qr{\A(.*)/[*]{1,2}\z}msx ) {
      $refspec = $1;
    }
    for my $line ( $self->git->for_each_ref($refspec) ) {
      if ( $line =~ qr{ \A ([^ ]+) [^\t]+ \t ( .+ ) \z }msx ) {
        $callback->( $1, $2 );
        next;
      }
      require Carp;
      Carp::confess( 'Regexp failed to parse a line from `git for-each-ref` :' . $line );
    }
    return;
  }
  for my $line ( $self->git->ls_remote( $git_dir, $refspec ) ) {
    ## no critic (Compatibility::PerlMinimumVersionAndWhy)
    if ( $line =~ qr{ \A ([^\t]+) \t ( .+ ) \z }msx ) {
      $callback->( $1, $2 );
      next;
    }
    require Carp;
    Carp::confess( 'Regexp failed to parse a line from `git ls-remote` :' . $line );
  }
  return;
}

sub refs {
  my ($self) = @_;
  return $self->get_ref('refs/**');
}

sub get_ref {
  my ( $self, $refspec ) = @_;
  my @out;
  $self->_for_each_ref(
    $refspec => sub {
      my ( $sha_one, $refname ) = @_;
      push @out, $self->_mk_ref( $sha_one, $refname );
    },
  );
  return @out;
}

sub _mk_ref {
  my ( $self, undef, $name ) = @_;
  require Git::Wrapper::Plus::Ref;
  return Git::Wrapper::Plus::Ref->new(
    git  => $self->git,
    name => $name,
  );
}
no Moo;

1;

__END__

