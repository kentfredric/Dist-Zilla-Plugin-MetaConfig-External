package Pod::Weaver::Section::Authors;

# ABSTRACT: a section listing authors
$Pod::Weaver::Section::Authors::VERSION = '4.015';
use Moose;
with 'Pod::Weaver::Role::Section';

use Pod::Elemental::Element::Nested;
use Pod::Elemental::Element::Pod5::Verbatim;

#pod =head1 OVERVIEW
#pod
#pod This section adds a listing of the documents authors.  It expects a C<authors>
#pod input parameter to be an arrayref of strings.  If no C<authors> parameter is
#pod given, it will do nothing.  Otherwise, it produces a hunk like this:
#pod
#pod   =head1 AUTHORS
#pod
#pod     Author One <a1@example.com>
#pod     Author Two <a2@example.com>
#pod
#pod =attr header
#pod
#pod The title of the header to be added.
#pod (default: "AUTHOR" or "AUTHORS")
#pod
#pod =cut

has header => (
  is  => 'ro',
  isa => 'Maybe[Str]',
);

sub weave_section {
  my ( $self, $document, $input ) = @_;

  return unless $input->{authors};

  my $multiple_authors = @{ $input->{authors} } > 1;

  # I think I might like to have header be a callback or something, so that you
  # can get pluralization for your own custom header. -- rjbs, 2015-03-17
  my $name = $self->header || ( $multiple_authors ? 'AUTHORS' : 'AUTHOR' );

  $self->log_debug("adding $name section");
  $self->log_debug("author = $_") for @{ $input->{authors} };

  my $authors = [ map { Pod::Elemental::Element::Pod5::Ordinary->new( { content => $_, } ), } @{ $input->{authors} } ];

  $authors = [
    Pod::Elemental::Element::Pod5::Command->new(
      {
        command => 'over',
        content => '4',
      }
    ),
    ( map { Pod::Elemental::Element::Pod5::Command->new( { command => 'item', content => '*', } ), $_, } @$authors ),
    Pod::Elemental::Element::Pod5::Command->new(
      {
        command => 'back',
        content => '',
      }
    ),
    ]
    if $multiple_authors;

  push @{ $document->children },
    Pod::Elemental::Element::Nested->new(
    {
      type     => 'command',
      command  => 'head1',
      content  => $name,
      children => $authors,
    }
    );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

