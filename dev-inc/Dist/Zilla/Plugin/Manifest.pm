package Dist::Zilla::Plugin::Manifest 6.015;

# ABSTRACT: build a MANIFEST file

use Moose;
with 'Dist::Zilla::Role::FileGatherer';

use namespace::autoclean;

use Dist::Zilla::File::FromCode;

#pod =head1 DESCRIPTION
#pod
#pod If included, this plugin will produce a F<MANIFEST> file for the distribution,
#pod listing all of the files it contains.  For obvious reasons, it should be
#pod included as close to last as possible.
#pod
#pod This plugin is included in the L<@Basic|Dist::Zilla::PluginBundle::Basic>
#pod bundle.
#pod
#pod =head1 SEE ALSO
#pod
#pod Dist::Zilla core plugins:
#pod L<@Basic|Dist::Zilla::PluginBundle::Manifest>,
#pod L<ManifestSkip|Dist::Zilla::Plugin::ManifestSkip>.
#pod
#pod Other modules: L<ExtUtils::Manifest>.
#pod
#pod =cut

sub __fix_filename {
  my ($name) = @_;
  return $name unless $name =~ /[ '\\]/;
  $name                     =~ s/\\/\\\\/g;
  $name                     =~ s/'/\\'/g;
  return qq{'$name'};
}

sub gather_files {
  my ( $self, $arg ) = @_;

  my $zilla = $self->zilla;

  my $file = Dist::Zilla::File::FromCode->new(
    {
      name             => 'MANIFEST',
      code_return_type => 'bytes',
      code             => sub {
        my $generated_by = sprintf "%s v%s", ref($self), $self->VERSION || '(dev)';

        return
            "# This file was automatically generated by $generated_by.\n"
          . join( "\n", map { __fix_filename($_) } sort map { $_->name } @{ $zilla->files } )
          . "\n",;
      },
    }
  );

  $self->add_file($file);
}

__PACKAGE__->meta->make_immutable;
1;

__END__

