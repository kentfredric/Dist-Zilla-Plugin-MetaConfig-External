package Pod::Weaver::Role::StringFromComment;

# ABSTRACT: Extract a string from a specially formatted comment
$Pod::Weaver::Role::StringFromComment::VERSION = '4.015';
use Moose::Role;
use namespace::autoclean;

#pod =head1 OVERVIEW
#pod
#pod This role assists L<Pod::Weaver sections|Pod::Weaver::Role::Section> by
#pod allowing them to pull strings from the source comments formatted like:
#pod
#pod     # KEYNAME: Some string...
#pod
#pod This is probably the most familiar to people using lines like the following to
#pod allow the L<Name section|Pod::Weaver::Section::Name> to determine a module's
#pod abstract:
#pod
#pod     # ABSTRACT: Provides the HypnoToad with mind-control powers
#pod
#pod It will extract these strings by inspecting the C<ppi_document> which
#pod must be given.
#pod
#pod =head1 PRIVATE METHODS
#pod
#pod This role supplies only methods meant to be used internally by its consumer.
#pod
#pod =head2 _extract_comment_content($ppi_doc, $key)
#pod
#pod Given a key, try to find a comment matching C<# $key:> in the C<$ppi_document>
#pod and return everything but the prefix.
#pod
#pod e.g., given a document with a comment in it of the form:
#pod
#pod     # ABSTRACT: Yada yada...
#pod
#pod ...and this is called...
#pod
#pod     $self->_extract_comment_content($ppi, 'ABSTRACT')
#pod
#pod ...it returns to us:
#pod
#pod     Yada yada...
#pod
#pod =cut

sub _extract_comment_content {
  my ( $self, $ppi_document, $key ) = @_;

  my $regex = qr/^\s*#+\s*$key:\s*(.+)$/m;

  my $content;
  my $finder = sub {
    my $node = $_[1];
    return 0 unless $node->isa('PPI::Token::Comment');
    if ( $node->content =~ $regex ) {
      $content = $1;
      return 1;
    }
    return 0;
  };

  $ppi_document->find_first($finder);

  return $content;
}

1;

__END__

