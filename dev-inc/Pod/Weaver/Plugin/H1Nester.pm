package Pod::Weaver::Plugin::H1Nester;

# ABSTRACT: structure the input pod document into head1-grouped sections
$Pod::Weaver::Plugin::H1Nester::VERSION = '4.015';
use Moose;
with 'Pod::Weaver::Role::Transformer';

use namespace::autoclean;

use Pod::Elemental::Selectors -all;
use Pod::Elemental::Transformer::Nester;

#pod =head1 OVERVIEW
#pod
#pod This plugin is very, very simple:  it uses the
#pod L<Pod::Elemental::Transformer::Nester> to restructure the document under its
#pod C<=head1> elements.
#pod
#pod =cut

sub transform_document {
  my ( $self, $document ) = @_;

  my $nester = Pod::Elemental::Transformer::Nester->new(
    {
      top_selector      => s_command( [qw(head1)] ),
      content_selectors => [ s_flat, s_command( [qw(head2 head3 head4 over item back)] ), ],
    }
  );

  $nester->transform_node($document);

  return;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

