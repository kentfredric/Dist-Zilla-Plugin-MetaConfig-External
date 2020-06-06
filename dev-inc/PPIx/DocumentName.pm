use 5.006;    # our
use strict;
use warnings;

package PPIx::DocumentName;

our $VERSION = '0.001003';

# ABSTRACT: Utility to extract a name from a PPI Document

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use PPI::Util qw( _Document );

sub log_info(&@);
sub log_debug(&@);
sub log_trace(&@);

BEGIN {
  if ( $INC{'Log/Contextual.pm'} ) {
    ## Hide from autoprereqs
    require 'Log/Contextual/WarnLogger.pm';    ## no critic (Modules::RequireBarewordIncludes)
    my $deflogger = Log::Contextual::WarnLogger->new( { env_prefix => 'PPIX_DOCUMENTNAME', } );
    Log::Contextual->import( 'log_info', 'log_debug', 'log_trace', '-default_logger' => $deflogger );
  }
  else {
    require Carp;
    *log_info  = sub (&@) { Carp::carp( $_[0]->() ) };
    *log_debug = sub (&@) { };
    *log_trace = sub (&@) { };
  }
}

## OO

sub extract {
  my ( $self, $ppi_document ) = @_;
  my $docname = $self->extract_via_comment($ppi_document)
    || $self->extract_via_statement($ppi_document);

  return $docname;
}

sub extract_via_statement {
  my ( undef, $ppi_document ) = @_;

  # Keep alive until done
  # https://github.com/adamkennedy/PPI/issues/112
  my $dom      = _Document($ppi_document);
  my $pkg_node = $dom->find_first('PPI::Statement::Package');
  if ( not $pkg_node ) {
    log_debug { "No PPI::Statement::Package found in <<$ppi_document>>" };
    return;
  }
  if ( not $pkg_node->namespace ) {
    log_debug { "PPI::Statement::Package $pkg_node has empty namespace in <<$ppi_document>>" };
    return;
  }
  return $pkg_node->namespace;
}

sub extract_via_comment {
  my ( undef, $ppi_document ) = @_;
  my $regex = qr{ ^ \s* \#+ \s* PODNAME: \s* (.+) $ }x;    ## no critic (RegularExpressions)
  my $content;
  my $finder = sub {
    my $node = $_[1];
    return 0 unless $node->isa('PPI::Token::Comment');
    log_trace { "Found comment node $node" };
    if ( $node->content =~ $regex ) {
      $content = $1;
      return 1;
    }
    return 0;
  };

  # Keep alive until done
  # https://github.com/adamkennedy/PPI/issues/112
  my $dom = _Document($ppi_document);
  $dom->find_first($finder);

  log_debug { "<<$ppi_document>> has no PODNAME comment" } if not $content;

  return $content;
}

1;

__END__

