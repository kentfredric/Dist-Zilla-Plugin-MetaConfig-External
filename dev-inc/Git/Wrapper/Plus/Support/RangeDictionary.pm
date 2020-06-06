use 5.006;    # our
use strict;
use warnings;

package Git::Wrapper::Plus::Support::RangeDictionary;

our $VERSION = '0.004011';

# ABSTRACT: A key -> range list mapping for support features

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moo qw( has );

has 'dictionary' => ( is => ro =>, lazy => 1, builder => 1 );

sub _build_dictionary {
  return {};
}

sub _dictionary_set {
  my ( $self, $name, $set_object ) = @_;
  $self->dictionary->{$name} = $set_object;
  return $self;
}

sub _dictionary_get {
  my ( $self, $name ) = @_;
  return unless $self->_dictionary_exists($name);
  return $self->dictionary->{$name};
}

sub _dictionary_exists {
  my ( $self, $name ) = @_;
  return exists $self->dictionary->{$name};
}

sub _dictionary_ensure_item {
  my ( $self, $name ) = @_;
  return if $self->_dictionary_exists($name);
  require Git::Wrapper::Plus::Support::RangeSet;
  $self->_dictionary_set( $name, Git::Wrapper::Plus::Support::RangeSet->new() );
  return;
}

sub _dictionary_item_add_range_object {
  my ( $self, $name, $range ) = @_;
  $self->_dictionary_ensure_item($name);
  $self->_dictionary_get($name)->add_range_object($range);
  return;
}

sub add_range {
  my ( $self, $name, @args ) = @_;
  $self->_dictionary_ensure_item($name);
  $self->_dictionary_get($name)->add_range(@args);
  return;
}

sub has_entry {
  my ( $self, $name ) = @_;
  return $self->_dictionary_exists($name);
}

sub entries {
  my ($self)    = @_;
  my (@entries) = sort keys %{ $self->dictionary };
  return @entries;
}

sub entry_supports {
  my ( $self, $name, $version_object ) = @_;
  return unless $self->_dictionary_exists($name);
  return $self->_dictionary_get($name)->supports_version($version_object);
}

no Moo;

1;

__END__

