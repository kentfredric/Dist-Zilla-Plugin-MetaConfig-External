use 5.006;
use strict;
use warnings;

package Dist::Zilla::Util::ConfigDumper;

our $VERSION = '0.003009';

# ABSTRACT: A Dist::Zilla plugin configuration extraction utility

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Carp qw( croak );
use Try::Tiny qw( try catch );
use Sub::Exporter::Progressive -setup => { exports => [qw( config_dumper dump_plugin )], };

sub config_dumper {
  my ( $package, @methodnames ) = @_;
  if ( not defined $package or ref $package ) {
    ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
    croak('config_dumper(__PACKAGE__, @recipie ): Arg 1 must not be ref or undef');
    ## use critic
  }

  my (@tests) = map { _mk_test( $package, $_ ) } @methodnames;
  my $CFG_PACKAGE = __PACKAGE__;
  return sub {
    my ( $orig, $self, @rest ) = @_;
    my $cnf     = $self->$orig(@rest);
    my $payload = {};
    my @fails;
    for my $test (@tests) {
      $test->( $self, $payload, \@fails );
    }
    if ( keys %{$payload} ) {
      $cnf->{$package} = $payload;
    }
    if (@fails) {
      $cnf->{$CFG_PACKAGE} = {} unless exists $cnf->{$CFG_PACKAGE};
      $cnf->{$CFG_PACKAGE}->{$package} = {} unless exists $cnf->{$CFG_PACKAGE};
      $cnf->{$CFG_PACKAGE}->{$package}->{failed} = \@fails;
    }
    return $cnf;
  };
}

sub dump_plugin {
  my ($plugin) = @_;
  my $object_config = {};
  $object_config->{class}   = $plugin->meta->name  if $plugin->can('meta') and $plugin->meta->can('name');
  $object_config->{name}    = $plugin->plugin_name if $plugin->can('plugin_name');
  $object_config->{version} = $plugin->VERSION     if $plugin->can('VERSION');
  if ( $plugin->can('dump_config') ) {
    my $finder_config = $plugin->dump_config;
    $object_config->{config} = $finder_config if keys %{$finder_config};
  }
  return $object_config;
}

sub _mk_method_test {
  my ( undef, $methodname ) = @_;
  return sub {
    my ( $instance, $payload, $fails ) = @_;
    try {
      my $value = $instance->$methodname();
      $payload->{$methodname} = $value;
    }
    catch {
      push @{$fails}, $methodname;
    };
  };
}

sub _mk_attribute_test {
  my ( undef, $attrname ) = @_;
  return sub {
    my ( $instance, $payload, $fails ) = @_;
    try {
      my $metaclass           = $instance->meta;
      my $attribute_metaclass = $metaclass->find_attribute_by_name($attrname);
      if ( $attribute_metaclass->has_value($instance) ) {
        $payload->{$attrname} = $attribute_metaclass->get_value($instance);
      }
    }
    catch {
      push @{$fails}, $attrname;
    };
  };
}

sub _mk_hash_test {
  my ( $package, $hash ) = @_;
  my @out;
  if ( exists $hash->{attrs} and 'ARRAY' eq ref $hash->{attrs} ) {
    push @out, map { _mk_attribute_test( $package, $_ ) } @{ $hash->{attrs} };
  }
  return @out;
}

sub _mk_test {
  my ( $package, $methodname ) = @_;
  return _mk_method_test( $package, $methodname ) if not ref $methodname;
  return $methodname                              if 'CODE' eq ref $methodname;
  return _mk_hash_test( $package, $methodname )   if 'HASH' eq ref $methodname;
  croak "Don't know what to do with $methodname";
}

1;

__END__

