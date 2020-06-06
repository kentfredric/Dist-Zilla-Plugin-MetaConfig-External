#!perl
use strict;
use warnings;

use Path::Tiny qw(path);

my (@modules) = (
  'Beam::Emitter',                                       'Beam::Event',
  'Data::DPath',                                         'Data::DPath::Attrs',
  'Data::DPath::Context',                                'Data::DPath::Filters',
  'Data::DPath::Path',                                   'Data::DPath::Point',
  'Data::DPath::Step',                                   'Data::Dump',
  'Data::Dump::FilterContext',                           'Data::Dump::Filtered',
  'Data::Visitor',                                       'Data::Visitor::Callback',
  'Devel::CheckBin',                                     'Dist::Zilla::MetaProvides::ProvideRecord',
  'Dist::Zilla::MetaProvides::Types',                    'Dist::Zilla::Plugin::Authority',
  'Dist::Zilla::Plugin::Author::KENTNL::CONTRIBUTING',   'Dist::Zilla::Plugin::Author::KENTNL::RecommendFixes',
  'Dist::Zilla::Plugin::Author::KENTNL::TravisCI',       'Dist::Zilla::Plugin::BumpVersionAfterRelease',
  'Dist::Zilla::Plugin::BumpVersionAfterRelease::_Util', 'Dist::Zilla::Plugin::CheckPrereqsIndexed',
  'Dist::Zilla::Plugin::CopyFilesFromBuild',             'Dist::Zilla::Plugin::GatherDir',
  'Dist::Zilla::Plugin::GenerateFile::FromShareDir',     'Dist::Zilla::Plugin::Git::Check',
  'Dist::Zilla::Plugin::Git::Commit',                    'Dist::Zilla::Plugin::Git::CommitBuild',
  'Dist::Zilla::Plugin::Git::Contributors',              'Dist::Zilla::Plugin::Git::GatherDir',
  'Dist::Zilla::Plugin::GithubMeta',                     'Dist::Zilla::Plugin::Git::NextRelease',
  'Dist::Zilla::Plugin::Git::Tag',                       'Dist::Zilla::Plugin::License',
  'Dist::Zilla::Plugin::Manifest',                       'Dist::Zilla::Plugin::ManifestSkip',
  'Dist::Zilla::Plugin::MetaData::BuiltWith',            'Dist::Zilla::Plugin::MetaJSON',
  'Dist::Zilla::Plugin::MetaProvides::Package',          'Dist::Zilla::Plugin::MetaTests',
  'Dist::Zilla::Plugin::MetaYAML',                       'Dist::Zilla::Plugin::MetaYAML::Minimal',
  'Dist::Zilla::Plugin::MinimumPerl',                    'Dist::Zilla::Plugin::PodCoverageTests',
  'Dist::Zilla::Plugin::PodSyntaxTests',                 'Dist::Zilla::Plugin::PodWeaver',
  'Dist::Zilla::Plugin::ReadmeAnyFromPod',               'Dist::Zilla::Plugin::Readme::Brief',
  'Dist::Zilla::Plugin::RemovePrereqs::Provided',        'Dist::Zilla::Plugin::RewriteVersion',
  'Dist::Zilla::Plugin::RewriteVersion::Sanitized',      'Dist::Zilla::Plugin::RunExtraTests',
  'Dist::Zilla::Plugin::Test::Compile::PerFile',         'Dist::Zilla::Plugin::Test::CPAN::Changes',
  'Dist::Zilla::Plugin::Test::EOL',                      'Dist::Zilla::Plugin::Test::Kwalitee',
  'Dist::Zilla::Plugin::Test::MinimumVersion',           'Dist::Zilla::Plugin::Test::Perl::Critic',
  'Dist::Zilla::Plugin::Test::ReportPrereqs',            'Dist::Zilla::Plugin::TravisCI',
  'Dist::Zilla::Plugin::Twitter',                        'Dist::Zilla::Role::File::ChangeNotification',
  'Dist::Zilla::Role::FileWatcher',                      'Dist::Zilla::Role::GitConfig',
  'Dist::Zilla::Role::Git::DirtyFiles',                  'Dist::Zilla::Role::Git::Repo',
  'Dist::Zilla::Role::Git::StringFormatter',             'Dist::Zilla::Role::MetaProvider::Provider',
  'Dist::Zilla::Role::ModuleMetadata',                   'Dist::Zilla::Role::RepoFileInjector',
  'Dist::Zilla::Role::Version::Sanitize',                'Dist::Zilla::Util::ConfigDumper',
  'Eval::TypeTiny',                                      'File::chdir',
  'Generic::Assertions',                                 'Git::Wrapper',
  'Git::Wrapper::Exception',                             'Git::Wrapper::File::RawModification',
  'Git::Wrapper::Log',                                   'Git::Wrapper::Plus',
  'Git::Wrapper::Plus::Branches',                        'Git::Wrapper::Plus::Ref',
  'Git::Wrapper::Plus::Ref::Branch',                     'Git::Wrapper::Plus::Refs',
  'Git::Wrapper::Plus::Support',                         'Git::Wrapper::Plus::Support::Commands',
  'Git::Wrapper::Plus::Support::Range',                  'Git::Wrapper::Plus::Support::RangeDictionary',
  'Git::Wrapper::Plus::Support::RangeSet',               'Git::Wrapper::Plus::Util',
  'Git::Wrapper::Plus::Versions',                        'Git::Wrapper::Status',
  'Git::Wrapper::Statuses',                              'Iterator',
  'Iterator::Util',                                      'List::UtilsBy',
  'MooseX::Has::Sugar',                                  'MooseX::SlurpyConstructor',
  'MooseX::SlurpyConstructor::Role::Object',             'MooseX::SlurpyConstructor::Trait::Attribute',
  'MooseX::SlurpyConstructor::Trait::Class',             'MooseX::Types::Path::Class',
  'MooseX::Types::Path::Tiny',                           'MooseX::Types::Stringlike',
  'MooseX::Types::URI',                                  'MooX::Lsub',
  'Net::Twitter',                                        'Net::Twitter::Core',
  'Net::Twitter::Error',                                 'Path::Class',
  'Path::Class::Dir',                                    'Path::Class::Entity',
  'Path::Class::File',                                   'Perl::Critic::Exception',
  'Perl::Critic::Exception::Fatal',                      'Perl::Critic::Exception::Fatal::Generic',
  'Perl::Critic::Utils',                                 'Perl::Critic::Utils::PPI',
  'Perl::MinimumVersion',                                'Perl::MinimumVersion::Reason',
  'Pod::Elemental',                                      'Pod::Elemental::Autoblank',
  'Pod::Elemental::Autochomp',                           'Pod::Elemental::Command',
  'Pod::Elemental::Document',                            'Pod::Elemental::Element::Generic::Blank',
  'Pod::Elemental::Element::Generic::Command',           'Pod::Elemental::Element::Generic::Nonpod',
  'Pod::Elemental::Element::Generic::Text',              'Pod::Elemental::Element::Nested',
  'Pod::Elemental::Element::Pod5::Command',              'Pod::Elemental::Element::Pod5::Data',
  'Pod::Elemental::Element::Pod5::Nonpod',               'Pod::Elemental::Element::Pod5::Ordinary',
  'Pod::Elemental::Element::Pod5::Region',               'Pod::Elemental::Element::Pod5::Verbatim',
  'Pod::Elemental::Flat',                                'Pod::Elemental::Node',
  'Pod::Elemental::Objectifier',                         'Pod::Elemental::Paragraph',
  'Pod::Elemental::PerlMunger',                          'Pod::Elemental::Selectors',
  'Pod::Elemental::Transformer',                         'Pod::Elemental::Transformer::Gatherer',
  'Pod::Elemental::Transformer::Nester',                 'Pod::Elemental::Transformer::Pod5',
  'Pod::Elemental::Types',                               'Pod::Eventual',
  'Pod::Eventual::Simple',                               'Pod::Markdown',
  'Pod::Weaver',                                         'Pod::Weaver::Config',
  'Pod::Weaver::Config::Assembler',                      'Pod::Weaver::Config::Finder',
  'Pod::Weaver::PluginBundle::CorePrep',                 'Pod::Weaver::Plugin::EnsurePod5',
  'Pod::Weaver::Plugin::H1Nester',                       'Pod::Weaver::Plugin::SingleEncoding',
  'Pod::Weaver::Role::Dialect',                          'Pod::Weaver::Role::Finalizer',
  'Pod::Weaver::Role::Plugin',                           'Pod::Weaver::Role::Preparer',
  'Pod::Weaver::Role::Section',                          'Pod::Weaver::Role::StringFromComment',
  'Pod::Weaver::Role::Transformer',                      'Pod::Weaver::Section::Authors',
  'Pod::Weaver::Section::Collect',                       'Pod::Weaver::Section::Generic',
  'Pod::Weaver::Section::Leftovers',                     'Pod::Weaver::Section::Legal',
  'Pod::Weaver::Section::Name',                          'Pod::Weaver::Section::Region',
  'Pod::Weaver::Section::Version',                       'PPIx::DocumentName',
  'Readonly',                                            'Safe::Isa',
  'Set::Scalar',                                         'Set::Scalar::Base',
  'Set::Scalar::Null',                                   'Set::Scalar::Real',
  'Set::Scalar::Universe',                               'Set::Scalar::Virtual',
  'Sort::Versions',                                      'String::Truncate',
  'Tie::ToObject',                                       'Type::Coercion',
  'Type::Library',                                       'Types::Standard',
  'Types::TypeTiny',                                     'Type::Tiny',
  'Type::Tiny::Role',                                    'WWW::Shorten',
  'WWW::Shorten::generic',                               'WWW::Shorten::Simple',
  'WWW::Shorten::TinyURL',                               'WWW::Shorten::UserAgent',
);
my (@share_dists) = (
  'Dist-Zilla-Plugin-Author-KENTNL-CONTRIBUTING',
  'Dist-Zilla-Plugin-Test-Compile-PerFile',
);

for my $module ( sort @modules ) {
  bundle_module_to( $module, './dev-inc' );
}
for my $dist ( sort @share_dists ) {
  bundle_sharedir_to( $dist, './dev-inc' );
}

sub bundle_module_to {
  my ( $module, $dir ) = @_;
  my $output_path = path($dir)->child( module_to_path($module) );
  my $input_path  = get_module_path($module);
  return unless defined $input_path;
  my $content = path($input_path)->slurp_raw;
  $content = pod_strip($content);
  $content = perl_tidy($content);

  # $content = perl_strip($content);
  $output_path->parent->mkpath;
  $output_path->spew_raw($content);
  warn "Written $output_path, @{[ length $content ]} b\n";
  return 1;
}

sub bundle_sharedir_to {
  my ($dist, $dir) = @_;
  my $output_dir = path($dir)->child("auto/share/dist")->child($dist);
  my $input_dir  = get_dist_dir( $dist );
  return unless defined $input_dir;
  my $visitor = sub {
    my ( $path, $state ) = @_;
    return 1 if $path->basename eq '.keep';
    my $relpath = $path->relative($input_dir);
    my $outfile = $relpath->absolute($output_dir);
    $outfile->parent->mkpath;
    warn "Copying $relpath from $input_dir to $output_dir\n";
    $path->copy($outfile);
  };
  path($input_dir)->visit( $visitor, { recurse => 1 } );
}

sub module_to_path {
  my ($module) = @_;
  $module =~ s/::/\//g;
  $module .= '.pm';
  $module;
}

sub get_module_path {
  my ($module) = @_;
  for my $prefix (@INC) {
    my $guess = $prefix . q[/] . module_to_path($module);
    if ( -e $guess ) {
      warn "Found $module in $guess\n";
      return $guess;
    }
  }
  warn "Did not find $module in \@INC, is it installed?\n";
  return;
}
sub get_dist_dir {
  my ( $dist_name ) = @_;
  for my $prefix (@INC) {
    my $guess = $prefix . q[/auto/share/dist/] . $dist_name;
    if ( -e $guess and -d $guess ) {
      return $guess;
    }
  }
  warn "Did not find dist-dir for $dist_name in \@INC, is it installed?\n";
  return;
}

sub perl_tidy {
  my ($string) = @_;
  require Perl::Tidy;
  my $output;
  my $error = Perl::Tidy::perltidy(
    source => \$string,
    destination => \$output,
    argv => '',
  );
  if ( $error ) {
    return $string;
  }
  return $output;
}
sub pod_strip {
  require Pod::Strip;
  my ($string) = @_;
  my $p = Pod::Strip->new();
  my $out;
  $p->output_string( \$out );
  $p->parse_string_document($string);
  return $out;
}

sub perl_strip {
  require Perl::Strip;
  my ($string) = @_;
  my $s = Perl::Strip->new(
    optimize_size => 0,

    # not implemented
    keep_nl => 1,
  );
  return $s->strip($string);
}
