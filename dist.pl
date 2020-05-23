#!perl
use strict;
use warnings;

{

  package Dist::Zilla::Plugin::MetaConfig::External;
  use Moose qw( with around has );
  use JSON::MaybeXS;
  with 'Dist::Zilla::Role::FileGatherer';

  sub my_metadata {
    my ($self) = @_;
    my $dump = {};
    my @plugins;
    $dump->{plugins} = \@plugins;

    my $config = $self->zilla->dump_config;
    $dump->{zilla} = {
      class   => $self->zilla->meta->name,
      version => $self->zilla->VERSION,
      ( keys %$config ? ( config => $config ) : () ),
    };
    $dump->{perl} = { version => "$]", };
    for my $plugin ( @{ $self->zilla->plugins } ) {
      my $config = $plugin->dump_config;
      push @plugins,
        {
        class   => $plugin->meta->name,
        name    => $plugin->plugin_name,
        version => $plugin->VERSION,
        ( keys %$config ? ( config => $config ) : () ),
        };
    }
    $dump;
  }

  sub gather_files {
    my ( $self, ) = @_;
    my $zilla = $self->zilla;

    my $file = Dist::Zilla::File::FromCode->new(
      {
        name             => 'META.dzil',
        code_return_type => 'text',
        code             => sub {
          JSON::MaybeXS->new(
            pretty          => 1,
            indent          => 1,
            canonical       => 1,
            convert_blessed => 1,
          )->encode( $self->my_metadata );
        }
      }
    );
    $self->add_file($file);
  }
}

use Dist::Zilla 6.014 ();    # No earlier support for dist.pl that works, sorry

my @config = (
  name             => 'Dist-Zilla-Plugin-MetaConfig-External',
  author           => 'Kent Fredric <kentnl@cpan.org>',
  license          => 'Perl_5',
  copyright_holder => 'Kent Fredric <kentfredric@gmail.com>',
  [
    'GithubMeta' => [ issues => 1 ],
    'MetaProvides::Package',
    'Git::Contributors',
    'Git::GatherDir' => [ include_dotfiles => 1 ],
    'License',
    'MetaJSON',
    'MetaYAML::Minimal',
    'MetaConfig::External',
    'Manifest',
    'MetaTests',
    'Test::ReportPrereqs',
    'Test::Compile::PerFile' => [
      test_template => '02-raw-require.t.tpl'
    ],
    'ManifestSkip',
    'RewriteVersion::Sanitized' => [
      mantissa    => 6,
      normal_form => 'numify',
    ],
    'PodWeaver' => [ replacer => 'replace_with_blank' ],
    'AutoPrereqs',
    'MinimumPerl',
    'Authority' => [
      authority      => 'cpan:KENTNL',
      do_metadata    => 1,
      locate_comment => 1,
    ],
    'MakeMaker' => [ default_jobs => 10 ],
    'Readme::Brief',
    'RunExtraTests' => [ default_jobs => 10 ],
    'TestRelease',
    'ConfirmRelease',
    'BumpVersionAfterRelease',
    'UploadToCPAN',
    'RemovePrereqs::Provided',
  ]
);

@config
