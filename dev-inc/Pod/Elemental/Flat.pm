package Pod::Elemental::Flat;

# ABSTRACT: a content-only pod paragraph
$Pod::Elemental::Flat::VERSION = '0.103004';
use Moose::Role;

use namespace::autoclean;

#pod =head1 OVERVIEW
#pod
#pod Pod::Elemental::Flat is a role that is included to indicate that a class
#pod represents a Pod paragraph that will have no children, and represents only its
#pod own content.  Generally it is used for text paragraphs.
#pod
#pod =cut

with 'Pod::Elemental::Paragraph';
excludes 'Pod::Elemental::Node';

sub as_debug_string {
  my ($self) = @_;

  my $moniker = ref $self;
  $moniker =~ s/\APod::Elemental::Element:://;

  my $summary = $self->_summarize_string( $self->content );

  return "$moniker <$summary>";
}

1;

__END__

