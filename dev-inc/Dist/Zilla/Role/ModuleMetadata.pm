use strict;
use warnings;

package Dist::Zilla::Role::ModuleMetadata;    # git description: v0.003-16-g7ff5130

# vim: set ts=8 sts=4 sw=4 tw=115 et :
# ABSTRACT: A role for plugins that use Module::Metadata
# KEYWORDS: zilla distribution plugin role metadata cache packages versions

our $VERSION = '0.004';

use Moose::Role;
use Module::Metadata 1.000005;
use Digest::MD5 'md5';
use namespace::autoclean;

# filename => md5 content => MMD object
my %CACHE;

sub module_metadata_for_file {
  my ( $self, $file ) = @_;

  Carp::croak('missing file argument for module_metadata_for_file') if not $file;

  # handle dzil v4 files by assuming no (or latin1) encoding
  my $encoded_content = $file->can('encoded_content') ? $file->encoded_content : $file->content;

  # We cache on the MD5 checksum to detect if the file has been modified
  # by some other plugin since it was last parsed, making our object invalid.
  my $md5      = md5($encoded_content);
  my $filename = $file->name;
  return $CACHE{$filename}{$md5} if $CACHE{$filename}{$md5};

  open( my $fh, ( $file->can('encoding') ? sprintf( '<:encoding(%s)', $file->encoding ) : '<' ), \$encoded_content, )
    or $self->log_fatal( [ 'cannot open handle to %s content: %s', $filename, $! ] );

  $self->log_debug( [ 'parsing %s for Module::Metadata', $filename ] );
  my $mmd = Module::Metadata->new_from_handle( $fh, $filename );
  return ( $CACHE{$filename}{$md5} = $mmd );
}

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    'Module::Metadata' => Module::Metadata->VERSION,
    version            => $VERSION,
  };

  return $config;
};

1;

__END__

