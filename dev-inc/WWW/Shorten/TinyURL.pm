package WWW::Shorten::TinyURL;

use strict;
use warnings;
use Carp ();

use base qw( WWW::Shorten::generic Exporter );
our $_error_message = '';
our @EXPORT         = qw( makeashorterlink makealongerlink );
our $VERSION        = '3.093';
$VERSION = eval $VERSION;

sub makeashorterlink {
  my $url = shift or Carp::croak('No URL passed to makeashorterlink');
  $_error_message = '';

  # terrible, bad!  skip live testing for now.
  if ( $ENV{'WWW-SHORTEN-TESTING'} ) {
    return 'http://tinyurl.com/abc12345'
      if ( $url eq 'https://metacpan.org/release/WWW-Shorten' );
    $_error_message = 'Incorrect URL for testing purposes';
    return undef;
  }

  # back to normality.
  my $ua      = __PACKAGE__->ua();
  my $tinyurl = 'http://tinyurl.com/api-create.php';
  my $resp    = $ua->post( $tinyurl, [ url => $url, source => "PerlAPI-$VERSION", ] );
  return undef unless $resp->is_success;
  my $content = $resp->content;
  if ( $content =~ /Error/ ) {

    if ( $content =~ /<html/ ) {
      $_error_message = 'Error is a html page';
    }
    elsif ( length($content) > 100 ) {
      $_error_message = substr( $content, 0, 100 );
    }
    else {
      $_error_message = $content;
    }
    return undef;
  }
  if ( $resp->content =~ m!(\Qhttp://tinyurl.com/\E\w+)!x ) {
    return $1;
  }
  return;
}

sub makealongerlink {
  my $url = shift
    or Carp::croak('No TinyURL key / URL passed to makealongerlink');
  $_error_message = '';
  $url            = "http://tinyurl.com/$url"
    unless $url =~ m!^http://!i;

  # terrible, bad!  skip live testing for now.
  if ( $ENV{'WWW-SHORTEN-TESTING'} ) {
    return 'https://metacpan.org/release/WWW-Shorten'
      if ( $url eq 'http://tinyurl.com/abc12345' );
    $_error_message = 'Incorrect URL for testing purposes';
    return undef;
  }

  # back to normality
  my $ua = __PACKAGE__->ua();

  my $resp = $ua->get($url);

  unless ( $resp->is_redirect ) {
    my $content = $resp->content;
    if ( $content =~ /Error/ ) {
      if ( $content =~ /<html/ ) {
        $_error_message = 'Error is a html page';
      }
      elsif ( length($content) > 100 ) {
        $_error_message = substr( $content, 0, 100 );
      }
      else {
        $_error_message = $content;
      }
    }
    else {
      $_error_message = 'Unknown error';
    }

    return undef;
  }
  my $long = $resp->header('Location');
  return $long;
}

1;

