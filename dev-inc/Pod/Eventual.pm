use strict;
use warnings;

package Pod::Eventual;
{
  $Pod::Eventual::VERSION = '0.094001';
}

# ABSTRACT: read a POD document as a series of trivial events
use Mixin::Linewise::Readers 0.102;

use Carp ();

sub read_handle {
  my ( $self, $handle, $arg ) = @_;
  $arg ||= {};

  my $in_pod = $arg->{in_pod} ? 1 : 0;
  my $current;

LINE: while ( my $line = $handle->getline ) {
    if ( $in_pod and $line =~ /^=cut(?:\s*)(.*?)(\n)\z/ ) {
      my $content = "$1$2";
      $in_pod = 0;
      $self->handle_event($current) if $current;
      undef $current;
      $self->handle_event(
        {
          type       => 'command',
          command    => 'cut',
          content    => $content,
          start_line => $handle->input_line_number,
        }
      );
      next LINE;
    }

    if ( $line =~ /\A=[a-z]/i ) {
      if ( $current and not $in_pod ) {
        $self->handle_nonpod($current);
        undef $current;
      }

      $in_pod = 1;
    }

    if ( not $in_pod ) {
      $current ||= {
        type       => 'nonpod',
        start_line => $handle->input_line_number,
        content    => '',
      };

      $current->{content} .= $line;
      next LINE;
    }

    if ( $line =~ /^\s*$/ ) {
      if ( $current and $current->{type} ne 'blank' ) {
        $self->handle_event($current);

        $current = {
          type       => 'blank',
          content    => '',
          start_line => $handle->input_line_number,
        };
      }
    }
    elsif ( $current and $current->{type} eq 'blank' ) {
      $self->handle_blank($current);
      undef $current;
    }

    if ($current) {
      $current->{content} .= $line;
      next LINE;
    }

    if ( $line =~ /^=([a-z]+\S*)(?:\s*)(.*?)(\n)\z/i ) {
      my $command = $1;
      my $content = "$2$3";
      $current = {
        type       => 'command',
        command    => $command,
        content    => $content,
        start_line => $handle->input_line_number,
      };
      next LINE;
    }

    $current = {
      type       => 'text',
      content    => $line,
      start_line => $handle->input_line_number,
    };
  }

  if ($current) {
    my $method =
        $current->{type} eq 'blank'  ? 'handle_blank'
      : $current->{type} eq 'nonpod' ? 'handle_nonpod'
      :                                'handle_event';

    $self->$method($current) if $current;
  }

  return;
}

sub handle_event {
  Carp::confess("handle_event not implemented by $_[0]");
}

sub handle_nonpod { }

sub handle_blank { }

1;

__END__

