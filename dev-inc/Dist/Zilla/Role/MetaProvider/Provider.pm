use 5.006;
use strict;
use warnings;

package Dist::Zilla::Role::MetaProvider::Provider;

our $VERSION = '2.002004';

# ABSTRACT: A Role for Metadata providers specific to the 'provider' key.

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moose::Role qw( with requires has around );
use MooseX::Types::Moose qw( Bool );
use namespace::autoclean;

with 'Dist::Zilla::Role::MetaProvider';

requires 'provides';

has inherit_version => (
  is            => 'ro',
  isa           => Bool,
  default       => 1,
  documentation => 'Whether or not to treat the global version as an authority',
);

has inherit_missing => (
  is            => 'ro',
  isa           => Bool,
  default       => 1,
  documentation => <<'DOC',
How to behave when we are trusting modules to have versions and one is missing one
DOC
);

has meta_noindex => (
  is            => 'ro',
  isa           => Bool,
  default       => 1,
  documentation => <<'DOC',
Scan for the meta_noindex metadata key and do not add provides records for things in it
DOC
);

sub _resolve_version {
  my $self    = shift;
  my $version = shift;
  if ( $self->inherit_version
    or ( $self->inherit_missing and not defined $version ) )
  {
    return ( 'version', $self->zilla->version );
  }
  if ( not defined $version ) {
    return ();
  }
  return ( 'version', $version );
}

sub _try_regen_metadata {
  my ($self) = @_;

  my $meta = {};

  for my $plugin ( @{ $self->zilla->plugins } ) {
    next unless $plugin->isa('Dist::Zilla::Plugin::MetaNoIndex');
    require Hash::Merge::Simple;
    $meta = Hash::Merge::Simple::merge( $meta, $plugin->metadata );
  }
  return $meta;
}

sub _apply_meta_noindex {
  my ( $self, @items ) = @_;

  # meta_noindex application is disabled
  if ( not $self->meta_noindex ) {
    return @items;
  }

  my $meta = $self->_try_regen_metadata;

  if ( not keys %{$meta} or not exists $meta->{no_index} ) {
    $self->log_debug( q{No no_index attribute found while trying to apply meta_noindex for} . $self->plugin_name );
    return @items;
  }
  else {
    $self->log_debug(q{no_index found in metadata, will apply rules});
  }

  my $noindex = {

    # defaults
    file      => [],
    package   => [],
    namespace => [],
    dir       => [],
    %{ $meta->{'no_index'} },
  };
  $noindex->{dir} = $noindex->{directory} if exists $noindex->{directory};

  for my $file ( @{ $noindex->{file} } ) {
    @items = grep { $_->file ne $file } @items;
  }
  for my $module ( @{ $noindex->{'package'} } ) {
    @items = grep { $_->module ne $module } @items;
  }
  for my $dir ( @{ $noindex->{'dir'} } ) {
    ## no critic (RegularExpressions ProhibitPunctuationVars)
    @items = grep { $_->file !~ qr{^\Q$dir\E($|/)} } @items;
  }
  for my $namespace ( @{ $noindex->{'namespace'} } ) {
    ## no critic (RegularExpressions ProhibitPunctuationVars)
    @items = grep { $_->module !~ qr{^\Q$namespace\E::} } @items;
  }
  return @items;
}

around dump_config => sub {
  my ( $orig, $self, @args ) = @_;
  my $config  = $orig->( $self, @args );
  my $payload = $config->{ +__PACKAGE__ } = {};

  $payload->{inherit_version} = $self->inherit_version;
  $payload->{inherit_missing} = $self->inherit_missing;
  $payload->{meta_noindex}    = $self->meta_noindex;

  $payload->{ q[$] . __PACKAGE__ . '::VERSION' } = $VERSION;
  return $config;
};

no Moose::Role;

sub metadata {
  my ($self)          = @_;
  my $discover        = {};
  my (%all_filenames) = map { $_->name => 1 } @{ $self->zilla->files || [] };
  my (%missing_files);
  my (%unmapped_modules);

  for my $provide_record ( $self->provides ) {
    my $file   = $provide_record->file;
    my $module = $provide_record->module;

    if ( not exists $all_filenames{$file} ) {
      $missing_files{$file} = 1;
      $self->log_debug( 'Provides entry states missing file <' . $file . '>' );
    }

    my $notional_filename = do { ( join q[/], split /::|'/sx, $module ) . '.pm' };
    if ( $file !~ /\b\Q$notional_filename\E\z/sx ) {
      $unmapped_modules{$module} = 1;
      $self->log_debug( 'Provides entry for module <'
          . $module
          . '> mapped to problematic <'
          . $file
          . '> ( want: <.*/'
          . $notional_filename
          . '> )' );
    }

    $provide_record->copy_into($discover);
  }

  ## no critic (RestrictLongStrings)
  if ( my $nkeys = scalar keys %missing_files ) {
    $self->log( "$nkeys provide map entries did not map to distfiles: " . join q[, ], sort keys %missing_files );
  }
  if ( my $nkeys = scalar keys %unmapped_modules ) {
    $self->log( "$nkeys provide map entries did not map to .pm files and may not be loadable at install time: " . join q[, ],
      sort keys %unmapped_modules );
  }
  return { provides => $discover };
}

1;

__END__

