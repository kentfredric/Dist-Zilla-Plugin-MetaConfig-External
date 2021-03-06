#
# This file is part of Dist-Zilla-Plugin-Authority
#
# This software is copyright (c) 2014 by Apocalypse.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;

package Dist::Zilla::Plugin::Authority;

# git description: release-1.008-1-g9f0cbc2
$Dist::Zilla::Plugin::Authority::VERSION = '1.009';
our $AUTHORITY = 'cpan:APOCAL';

# ABSTRACT: Add the $AUTHORITY variable and metadata to your distribution

use Moose 1.03;
use PPI 1.206;
use File::Spec;
use File::HomeDir;
use Dist::Zilla::Util;

with(
  'Dist::Zilla::Role::MetaProvider'   => { -version => '4.102345' },
  'Dist::Zilla::Role::FileMunger'     => { -version => '4.102345' },
  'Dist::Zilla::Role::FileFinderUser' => {
    -version        => '4.102345',
    default_finders => [ ':InstallModules', ':ExecFiles' ],
  },
  'Dist::Zilla::Role::PPI' => { -version => '4.300001' },
);

#pod =attr authority
#pod
#pod The authority you want to use. It should be something like C<cpan:APOCAL>.
#pod
#pod Defaults to the username set in the %PAUSE stash in the global config.ini or dist.ini ( Dist::Zilla v4 addition! )
#pod
#pod If you prefer to not put it in config/dist.ini you can put it in "~/.pause" just like Dist::Zilla did before v4.
#pod
#pod =cut

{
  use Moose::Util::TypeConstraints 1.01;

  has authority => (
    is  => 'ro',
    isa => subtype(
      'Str' => where { $_ =~ /^\w+\:\S+$/ }
      => message { "Authority must be in the form of 'cpan:PAUSEID'" }
    ),
    lazy    => 1,
    default => sub {
      my $self  = shift;
      my $stash = $self->zilla->stash_named('%PAUSE');
      if ( defined $stash ) {
        $self->log_debug( [ 'using PAUSE id "%s" for AUTHORITY from Dist::Zilla config', uc( $stash->username ) ] );
        return 'cpan:' . uc( $stash->username );
      }
      else {
        # Argh, try the .pause file?
        # Code ripped off from Dist::Zilla::Plugin::UploadToCPAN v4.200001 - thanks RJBS!
        my $file = File::Spec->catfile( File::HomeDir->my_home, '.pause' );
        if ( -f $file ) {
          open my $fh, '<', $file or $self->log_fatal("Unable to open $file - $!");
          while (<$fh>) {
            next if /^\s*(?:#.*)?$/;
            my ( $k, $v ) = /^\s*(\w+)\s+(.+)$/;
            if ( $k =~ /^user$/i ) {
              $self->log_debug( [ 'using PAUSE id "%s" for AUTHORITY from ~/.pause', uc($v) ] );
              return 'cpan:' . uc($v);
            }
          }
          close $fh or $self->log_fatal("Unable to close $file - $!");
          $self->log_fatal('PAUSE user not found in ~/.pause');
        }
        else {
          $self->log_fatal(
'PAUSE credentials not found in "config.ini" or "dist.ini" or "~/.pause"! Please set it or specify an authority for this plugin.'
          );
        }
      }
    },
  );

  no Moose::Util::TypeConstraints;
}

#pod =attr do_metadata
#pod
#pod A boolean value to control if the authority should be added to the metadata.
#pod
#pod Defaults to true.
#pod
#pod =cut

has do_metadata => (
  is      => 'ro',
  isa     => 'Bool',
  default => 1,
);

#pod =attr do_munging
#pod
#pod A boolean value to control if the $AUTHORITY variable should be added to the modules.
#pod
#pod Defaults to true.
#pod
#pod =cut

has do_munging => (
  is      => 'ro',
  isa     => 'Bool',
  default => 1,
);

#pod =attr locate_comment
#pod
#pod A boolean value to control if the $AUTHORITY variable should be added where a
#pod C<# AUTHORITY> comment is found.  If this is set then an appropriate comment
#pod is found, and C<our $AUTHORITY = 'cpan:PAUSEID';> is inserted preceding the
#pod comment on the same line.
#pod
#pod This basically implements what L<OurPkgVersion|Dist::Zilla::Plugin::OurPkgVersion>
#pod does for L<PkgVersion|Dist::Zilla::Plugin::PkgVersion>.
#pod
#pod Defaults to false.
#pod
#pod NOTE: If you use this method, then we will not use the pkg style of declaration! That way, we keep the line numbering consistent.
#pod
#pod =cut

has locate_comment => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

#pod =attr authority_style
#pod
#pod A value to control the type of the $AUTHORITY declaration. There are two styles: 'pkg' or 'our'. In the past
#pod this module defaulted to the 'pkg' style but due to various issues 'our' is now the default. Here's what both styles
#pod would look like in the resulting code:
#pod
#pod 	# pkg
#pod 	BEGIN {
#pod 		$Dist::Zilla::Plugin::Authority::AUTHORITY = 'cpan:APOCAL';
#pod 	}
#pod
#pod 	# our
#pod 	our $AUTHORITY = 'cpan:APOCAL';
#pod
#pod =cut

{
  use Moose::Util::TypeConstraints 1.01;

  has authority_style => (
    is      => 'ro',
    isa     => enum( [qw( pkg our )] ),
    default => 'our',
  );

  no Moose::Util::TypeConstraints;
}

# sanity check ourselves...
my $seen_author;

sub metadata {
  my ($self) = @_;

  return if !$self->do_metadata;

  if ( !defined $seen_author ) {
    $seen_author = $self->authority;
  }
  else {
    if ( $seen_author ne $self->authority ) {
      die "Specifying multiple authorities will not work! We got '$seen_author' and '" . $self->authority . "'";
    }
  }

  $self->log_debug('adding AUTHORITY to metadata');

  return { 'x_authority' => $self->authority, };
}

sub munge_files {
  my ($self) = @_;

  return if !$self->do_munging;

  if ( !defined $seen_author ) {
    $seen_author = $self->authority;
  }
  else {
    if ( $seen_author ne $self->authority ) {
      die "Specifying multiple authorities will not work! We got '$seen_author' and '" . $self->authority . "'";
    }
  }

  $self->_munge_file($_) for @{ $self->found_files };
}

sub _munge_file {
  my ( $self, $file ) = @_;

  return $self->_munge_perl($file) if $file->name    =~ /\.(?:pm|pl)$/i;
  return $self->_munge_perl($file) if $file->content =~ /^#!(?:.*)perl(?:$|\s)/;
  return;
}

# create an 'our' style assignment string of Perl code
# ->_template_our_authority({
#       whitespace => 'some white text preceeding the our',
#		authority  => 'the author to assign authority to',
#       comment    => 'original comment string',
# })
sub _template_our_authority {
  my $variable = "AUTHORITY";
  return sprintf qq[%sour \$%s = '%s'; %s\n], $_[1]->{whitespace}, $variable, $_[1]->{authority}, $_[1]->{comment};
}

# create a 'pkg' style assignment string of Perl code
# ->_template_pkg_authority({
#		package => 'the package the variable is to be created in',
#       authority => 'the author to assign authority to',
# })
sub _template_pkg_authority {
  my $variable = sprintf "%s::AUTHORITY", $_[1]->{package};
  return sprintf qq[BEGIN {\n  \$%s = '%s';\n}\n], $variable, $_[1]->{authority};
}

# Generate a PPI element containing our assignment
sub _make_authority {
  my ( $self, $package ) = @_;

  my $code_hunk;
  if ( $self->authority_style eq 'our' ) {
    $code_hunk = $self->_template_our_authority( { whitespace => '', authority => $self->authority, comment => '' } );
  }
  else {
    $code_hunk = $self->_template_pkg_authority( { package => $package, authority => $self->authority } );
  }

  my $doc      = PPI::Document->new( \$code_hunk );
  my @children = $doc->schildren;
  return $children[0]->clone;
}

# Insert an AUTHORITY assignment inside a <package $package { }> declaration( $block )
sub _inject_block_authority {
  my ( $self, $block, $package ) = @_;
  $self->log_debug( ['Inserting inside a package NAME BLOCK statement'] );

# TODO watch https://github.com/neilbowers/Perl-MinimumVersion/issues/1
# because Perl::MinimumVersion didn't specify 5.14 we got: http://www.cpantesters.org/cpan/report/ffab485c-5e2a-11e4-846d-e015e1bfc7aa
# and tons of FAIL on perls < 5.14 :(
  unshift @{ $block->{children} },
    PPI::Token::Whitespace->new("\n"),
    $self->_make_authority($package),
    PPI::Token::Whitespace->new("\n");
  return;
}

# Insert an AUTHORITY assignment immediately after the <package $package> declaration ( $stmt )
sub _inject_plain_authority {
  my ( $self, $file, $stmt, $package ) = @_;
  $self->log_debug( ['Inserting after a plain package declaration'] );
  Carp::carp( "error inserting AUTHORITY in " . $file->name )
    unless $stmt->insert_after( $self->_make_authority($package) )
    and $stmt->insert_after( PPI::Token::Whitespace->new("\n") );
}

# Replace the content of $line with an AUTHORITY assignment, preceeded by $ws, succeeded by $comment
sub _replace_authority_comment {
  my ( $self, $file, $line, $ws, $comment ) = @_;
  $self->log_debug( [ 'adding $AUTHORITY assignment to line %d in %s', $line->line_number, $file->name ] );
  $line->set_content(
    $self->_template_our_authority( { whitespace => $ws, authority => $self->authority, comment => $comment } ) );
  return;
}

# Uses # AUTHORITY comments to work out where to put declarations
sub _munge_perl_authority_comments {
  my ( $self, $document, $file ) = @_;

  my $comments = $document->find('PPI::Token::Comment');

  return unless ref $comments;

  return unless ref $comments eq 'ARRAY';

  my $found_authority = 0;

  foreach my $line (@$comments) {
    next unless $line =~ /^(\s*)(\#\s+AUTHORITY\b)$/xms;
    $self->_replace_authority_comment( $file, $line, $1, $2 );
    $found_authority = 1;
  }
  if ( not $found_authority ) {
    $self->log( [ 'skipping %s: consider adding a "# AUTHORITY" comment', $file->name ] );
    return;
  }

  $self->save_ppi_document_to_file( $document, $file );
  return 1;
}

# Places Fully Qualified $AUTHORITY values in packages
sub _munge_perl_packages {
  my ( $self, $document, $file ) = @_;

  return unless my $package_stmts = $document->find('PPI::Statement::Package');

  my %seen_pkgs;

  for my $stmt (@$package_stmts) {
    my $package = $stmt->namespace;

    # Thanks to rafl ( Florian Ragwitz ) for this
    if ( $seen_pkgs{$package}++ ) {
      $self->log( [ 'skipping package re-declaration for %s', $package ] );
      next;
    }

    # Thanks to autarch ( Dave Rolsky ) for this
    if ( $stmt->content =~ /package\s*(?:#.*)?\n\s*\Q$package/ ) {
      $self->log( [ 'skipping private package %s', $package ] );
      next;
    }
    $self->log_debug( [ 'adding $AUTHORITY assignment to %s in %s', $package, $file->name ] );

    if ( my $block = $stmt->find_first('PPI::Structure::Block') ) {
      $self->_inject_block_authority( $block, $package );
      next;
    }
    $self->_inject_plain_authority( $file, $stmt, $package );
    next;
  }
  $self->save_ppi_document_to_file( $document, $file );
}

sub _munge_perl {
  my ( $self, $file ) = @_;

  my $document = $self->ppi_document_for_file($file);

  if ( $self->document_assigns_to_variable( $document, '$AUTHORITY' ) ) {
    $self->log( [ 'skipping %s: assigns to $AUTHORITY', $file->name ] );
    return;
  }

  # Should we use the comment to insert the $AUTHORITY or the pkg declaration?
  if ( $self->locate_comment ) {
    return $self->_munge_perl_authority_comments( $document, $file );
  }
  else {
    return $self->_munge_perl_packages( $document, $file );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

