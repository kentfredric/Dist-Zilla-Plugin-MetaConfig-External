#
# This file is part of Dist-Zilla-Plugin-MinimumPerl
#
# This software is copyright (c) 2014 by Apocalypse.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;

package Dist::Zilla::Plugin::MinimumPerl;

# git description: release-1.005-7-g9a97c25
$Dist::Zilla::Plugin::MinimumPerl::VERSION = '1.006';
our $AUTHORITY = 'cpan:APOCAL';

# ABSTRACT: Detects the minimum version of Perl required for your dist

use Moose 1.03;
use Perl::MinimumVersion 1.26;
use MooseX::Types::Perl 0.101340 qw( LaxVersionStr );

with(
  'Dist::Zilla::Role::PrereqSource'   => { -version => '5.006' },    # for the updated encoding system in dzil, RJBS++
  'Dist::Zilla::Role::FileFinderUser' => {
    finder_arg_names => ['runtime_finder'],
    method           => 'found_runtime',
    default_finders  => [ ':InstallModules', ':ExecFiles' ]
  },
  'Dist::Zilla::Role::FileFinderUser' => {
    finder_arg_names => ['test_finder'],
    method           => 'found_tests',
    default_finders  => [':TestFiles']
  },
  'Dist::Zilla::Role::FileFinderUser' => {
    -version         => '4.200006',                                  # for :IncModules
    finder_arg_names => ['configure_finder'],
    method           => 'found_configure',
    default_finders  => [':IncModules']
  },
);

#pod =attr perl
#pod
#pod Specify a version of perl required for the dist. Please specify it in a format that Build.PL/Makefile.PL understands!
#pod If this is specified, this module will not attempt to automatically detect the minimum version of Perl.
#pod
#pod The default is: undefined ( automatically detect it )
#pod
#pod Example: 5.008008
#pod
#pod =cut

{
  use Moose::Util::TypeConstraints 1.01;

  has perl => (
    is  => 'ro',
    isa => subtype(
      'Str' => where { LaxVersionStr->check($_) }
      => message { "Perl must be in a valid version format - see version.pm" }
    ),
    predicate => '_has_perl',
  );

  no Moose::Util::TypeConstraints;
}

has _scanned_perl => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub register_prereqs {
  my ($self) = @_;

  # TODO should we check to see if it was already set in the metadata?

  # Okay, did the user set a perl version explicitly?
  if ( $self->_has_perl ) {
    foreach my $p (qw( runtime configure test )) {
      $self->zilla->register_prereqs( { phase => $p }, 'perl' => $self->perl, );
    }
  }
  else {
    # Go through our 3 phases
    $self->_scan_file( 'runtime', $_ ) for @{ $self->found_runtime };
    $self->_finalize('runtime');
    $self->_scan_file( 'configure', $_ ) for @{ $self->found_configure };
    $self->_finalize('configure');
    $self->_scan_file( 'test', $_ ) for @{ $self->found_tests };
    $self->_finalize('test');
  }
}

sub _scan_file {
  my ( $self, $phase, $file ) = @_;

  # We don't parse files marked with the 'bytes' encoding as they're special - see RT#96071
  return if $file->is_bytes;

  # TODO skip "bad" files and not die, just warn?
  my $pmv = Perl::MinimumVersion->new( \$file->content );
  if ( !defined $pmv ) {
    $self->log_fatal( "Unable to parse '" . $file->name . "'" );
  }
  my $ver = $pmv->minimum_version;
  if ( !defined $ver ) {
    $self->log_fatal( "Unable to extract MinimumPerl from '" . $file->name . "'" );
  }

  # cache it, letting _finalize take care of it
  if ( !exists $self->_scanned_perl->{$phase} || $self->_scanned_perl->{$phase}->[0] < $ver ) {
    $self->_scanned_perl->{$phase} = [ $ver, $file ];
  }
}

sub _finalize {
  my ( $self, $phase ) = @_;

  my $v;

  # determine the version we will use
  if ( !exists $self->_scanned_perl->{$phase} ) {

    # We don't complain for test and inc!
    $self->log_fatal('Found no perl files, check your dist?') if $phase eq 'runtime';

    # ohwell, we just copy the runtime perl
    $self->log_debug( "Determined that the MinimumPerl required for '$phase' is v"
        . $self->_scanned_perl->{'runtime'}->[0]
        . " via defaulting to runtime" );
    $v = $self->_scanned_perl->{'runtime'}->[0];
  }
  else {
    $self->log_debug( "Determined that the MinimumPerl required for '$phase' is v"
        . $self->_scanned_perl->{$phase}->[0] . " via "
        . $self->_scanned_perl->{$phase}->[1]->name );
    $v = $self->_scanned_perl->{$phase}->[0];
  }

  $self->zilla->register_prereqs( { phase => $phase }, 'perl' => $v, );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

