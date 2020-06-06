package Dist::Zilla::Plugin::MetaJSON 6.015;

# ABSTRACT: produce a META.json

use Moose;
with 'Dist::Zilla::Role::FileGatherer';
use Moose::Util::TypeConstraints;

use namespace::autoclean;

#pod =head1 DESCRIPTION
#pod
#pod This plugin will add a F<META.json> file to the distribution.
#pod
#pod This file is meant to replace the old-style F<META.yml>.  For more information
#pod on this file, see L<Module::Build::API> and L<CPAN::Meta>.
#pod
#pod =attr filename
#pod
#pod If given, parameter allows you to specify an alternate name for the generated
#pod file.  It defaults, of course, to F<META.json>.
#pod
#pod =cut

has filename => (
  is      => 'ro',
  isa     => 'Str',
  default => 'META.json',
);

#pod =attr version
#pod
#pod This parameter lets you pick what version of the spec to use when generating
#pod the output.  It defaults to 2 at present, but may be updated to new specs as
#pod they are released and adopted.
#pod
#pod If you want a fixed version, specify it.
#pod
#pod =cut

my $version_type = subtype( as 'Num', where { $_ >= 2 }, message { "MetaJSON version must be 2 or greater" }, );

has version => (
  is      => 'ro',
  isa     => $version_type,
  default => '2',
);

sub gather_files {
  my ( $self, $arg ) = @_;

  my $zilla = $self->zilla;

  require JSON::MaybeXS;
  require Dist::Zilla::File::FromCode;
  require CPAN::Meta::Converter;
  CPAN::Meta::Converter->VERSION(2.101550);    # improved downconversion
  require CPAN::Meta::Validator;
  CPAN::Meta::Validator->VERSION(2.101550);    # improved downconversion

  my $file = Dist::Zilla::File::FromCode->new(
    {
      name             => $self->filename,
      encoding         => 'ascii',
      code_return_type => 'text',
      code             => sub {
        my $distmeta = $zilla->distmeta;

        my $validator = CPAN::Meta::Validator->new($distmeta);

        unless ( $validator->is_valid ) {
          my $msg = "Invalid META structure.  Errors found:\n";
          $msg .= join( "\n", $validator->errors );
          $self->log_fatal($msg);
        }

        my $converter = CPAN::Meta::Converter->new($distmeta);
        my $output    = $converter->convert( version => $self->version );

        my $backend = JSON::MaybeXS::JSON();
        $output->{x_serialization_backend} = sprintf '%s version %s', $backend, $backend->VERSION;

        JSON::MaybeXS->new( canonical => 1, pretty => 1, ascii => 1 )->encode($output) . "\n";
      },
    }
  );

  $self->add_file($file);
  return;
}

__PACKAGE__->meta->make_immutable;
1;

#pod =head1 SEE ALSO
#pod
#pod Core Dist::Zilla plugins:
#pod L<@Basic|Dist::Zilla::PluginBundle::Basic>,
#pod L<Manifest|Dist::Zilla::Plugin::Manifest>.
#pod
#pod Dist::Zilla roles:
#pod L<FileGatherer|Dist::Zilla::Role::FileGatherer>.
#pod
#pod Other modules:
#pod L<CPAN::Meta>,
#pod L<CPAN::Meta::Spec>, L<JSON::MaybeXS>.
#pod
#pod =cut

__END__

