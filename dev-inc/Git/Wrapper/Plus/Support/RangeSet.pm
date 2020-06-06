use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Support::RangeSet;

our $VERSION = '0.004011';

# ABSTRACT: A set of ranges of supported things

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

has 'items' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_items {
  return [];
}

sub add_range_object {
  my ( $self, $range_object ) = @_;
  push @{ $self->items }, $range_object;
  return $self;
}

sub add_range {
  my ( $self, @args ) = @_;
  my $config;
  if ( 1 == @args ) {
    $config = $args[0];
  }
  else {
    $config = {@args};
  }
  require Git::Wrapper::Plus::Support::Range;
  return $self->add_range_object( Git::Wrapper::Plus::Support::Range->new($config) );
}

sub supports_version {
  my ( $self, $version_object ) = @_;
  for my $item ( @{ $self->items } ) {
    my $cmp = $item->supports_version($version_object);
    return $cmp if defined $cmp;
  }
  return;
}

no Moo;
1;

__END__

