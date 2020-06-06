package Pod::Elemental::Paragraph;

# ABSTRACT: a paragraph in a Pod document
$Pod::Elemental::Paragraph::VERSION = '0.103004';
use namespace::autoclean;
use Moose::Role;

use Encode qw(encode);
use String::Truncate qw(elide);

#pod =head1 OVERVIEW
#pod
#pod This is probably the most important role in the Pod-Elemental distribution.
#pod Classes including this role represent paragraphs in a Pod document.  The
#pod paragraph is the fundamental unit of dividing up Pod documents, so this is a
#pod often-included role.
#pod
#pod =attr content
#pod
#pod This is the textual content of the element, as in a Pod::Eventual event.  In
#pod other words, this Pod:
#pod
#pod   =head2 content
#pod
#pod has a content of "content\n"
#pod
#pod =attr start_line
#pod
#pod This attribute, which may or may not be set, indicates the line in the source
#pod document where the element began.
#pod
#pod =cut

has content    => ( is => 'rw', isa => 'Str', required => 1 );
has start_line => ( is => 'ro', isa => 'Int', required => 0 );

#pod =method as_pod_string
#pod
#pod This returns the element  as a string, suitable for turning elements back into
#pod a document.  Some elements, like a C<=over> command, will stringify to include
#pod extra content like a C<=back> command.  In the case of elements with children,
#pod this method will include the stringified children as well.
#pod
#pod =cut

sub as_pod_string {
  my ($self) = @_;
  return $self->content;
}

#pod =method as_debug_string
#pod
#pod This method returns a string, like C<as_string>, but is meant for getting an
#pod overview of the document structure, and is not suitable for reproducing a
#pod document.  Its exact output is likely to change over time.
#pod
#pod =cut

sub _summarize_string {
  my ( $self, $str, $length ) = @_;
  $length ||= 30;

  use utf8;
  chomp $str;
  my $elided = elide( $str, $length, { truncate => 'middle', marker => '…' } );
  $elided =~ tr/\n\t/␤␉/;

  return encode( 'utf-8', $elided );
}

requires 'as_debug_string';

1;

__END__

