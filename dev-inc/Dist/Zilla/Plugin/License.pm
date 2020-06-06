package Dist::Zilla::Plugin::License 6.015;

# ABSTRACT: output a LICENSE file

use Moose;
with 'Dist::Zilla::Role::FileGatherer';

use namespace::autoclean;

#pod =head1 DESCRIPTION
#pod
#pod This plugin adds a F<LICENSE> file containing the full text of the
#pod distribution's license, as produced by the C<fulltext> method of the
#pod dist's L<Software::License> object.
#pod
#pod =attr filename
#pod
#pod This attribute can be used to specify a name other than F<LICENSE> to be used.
#pod
#pod =cut

use Dist::Zilla::File::InMemory;

has filename => (
  is      => 'ro',
  isa     => 'Str',
  default => 'LICENSE',
);

sub gather_files {
  my ( $self, $arg ) = @_;

  my $file = Dist::Zilla::File::InMemory->new(
    {
      name    => $self->filename,
      content => $self->zilla->license->fulltext,
    }
  );

  $self->add_file($file);
  return;
}

__PACKAGE__->meta->make_immutable;
1;

#pod =head1 SEE ALSO
#pod
#pod =over 4
#pod
#pod =item *
#pod
#pod the C<license> attribute of the L<Dist::Zilla> object to select the license
#pod to use.
#pod
#pod =item *
#pod
#pod Dist::Zilla roles:
#pod L<FileGatherer|Dist::Zilla::Role::FileGatherer>.
#pod
#pod =item *
#pod
#pod Other modules:
#pod L<Software::License>,
#pod L<Software::License::Artistic_2_0>.
#pod
#pod =back
#pod
#pod =cut

__END__

