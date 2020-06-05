#!perl
use strict;
use warnings;

use Dist::Zilla 6.015 ();    # No earlier support for dist.pl that works, sorry
use lib './lib';

BEGIN {
  if ( !$ENV{NO_GIT} and -e '.git' and -d '.git' ) {
    *has_git = sub() { 1 };
  }
  else {
    *has_git = sub() { undef };
  }
  if ( $ENV{MINIMAL} ) {
    *is_minimal = sub () { 1 };
  }
  else {
    *is_minimal = sub () { undef };
  }

  *include_if = sub {
    my $cond = shift;
    $cond ? (@_) : ( () );
  };
  *include_or = sub {
    $_[0] ? @{ $_[1] } : @{ $_[2] };
  };
}

my $dist_name = 'Dist-Zilla-Plugin-MetaConfig-External';

my (%common) = (
  authority  => 'cpan:KENTNL',
  jobs       => ( defined $ENV{JOBS} ? $ENV{JOBS} : 10 ),
  skip_files => [
    '^' . $dist_name . '-\d.\d+.tar.gz$', '^README($|\.(mkdn|pod)$)',
    '^CONTRIBUTING\.pod$',                '^Makefile(|.PL|.old)$',
    '^LICENSE$',                          '^(MY|)META\.(yml|json)$',
    '^pm_to_blib$',
  ],
  skip_dirs => [ '^.git$', '^' . $dist_name . '-\d.\d+$', '^blib$', '^tmp$', '^.build$', ],
  hash_tags => q[#perl #cpan #distzilla],
);

my (@distmeta) = (
  name             => 'Dist-Zilla-Plugin-MetaConfig-External',
  author           => 'Kent Fredric <kentnl@cpan.org>',
  license          => 'Perl_5',
  copyright_holder => 'Kent Fredric <kentfredric@gmail.com>',
  main_module      => 'lib/Dist/Zilla/Plugin/MetaConfig/External.pm',
);
my (%prereqs) = (
  develop => {
    requires => {
      'Dist::Zilla' => 6.015,
    }
  }
);

my (@plugins) = (
  include_if( has_git && !is_minimal, 'GithubMeta' => [ issues => 1 ] ),
  include_if(
    !is_minimal, 'MetaProvides::Package' => [ ':version' => '1.14000001' ]
  ),
  include_if(
    !is_minimal,
    'MetaData::BuiltWith' => [
      ':version'        => '1.004000',
      show_config       => 1,
      show_uname        => 1,
      uname_args        => '-s -o -r -m -i',
      use_external_file => 'only',
    ]
  ),
  include_if(
    has_git && !is_minimal,
    'Git::Contributors' => [
      ':version' => '0.006',
    ]
  ),
  include_or(
    has_git && !is_minimal,
    [
      'Git::GatherDir' => [
        include_dotfiles => 1,
        ( map { ( exclude_match => $_ ) } @{ $common{skip_files} } ),
      ]
    ],
    [
      GatherDir => [
        include_dotfiles => 1,
        ( map { ( exclude_match   => $_ ) } @{ $common{skip_files} } ),
        ( map { ( prune_directory => $_ ) } @{ $common{skip_dirs} } ),
      ]
    ],
  ),
  'License'  => [],
  'MetaJSON' => [],
  include_or( !is_minimal, [ 'MetaYAML::Minimal' => [] ], [ 'MetaYAML' => [] ] ),
  include_if( !is_minimal, 'MetaConfig::External' => [], ),
  'Manifest' => [],
  include_if(
    !is_minimal,
    'Author::KENTNL::TravisCI' => [
      ":version" => '0.001002',
      skip_perls => '5.8',
    ]
  ),
  include_if(
    !is_minimal,
    'Author::KENTNL::CONTRIBUTING' => [
      ':version'       => '0.001003',
      -location        => 'root',
      -phase           => 'build',
      document_version => '0.1',
    ],
  ),
  include_if(
    !is_minimal,
    CopyFilesFromBuild => [
      copy => 'LICENSE',
      copy => 'Makefile.PL',
    ]
  ),
  include_if(
    !is_minimal,
    'MetaTests'           => [],
    'PodCoverageTests'    => [],
    'PodSyntaxTests'      => [],
    'Test::ReportPrereqs' => [],
    'Test::Kwalitee'      => [],
    'Test::EOL'           => [
      trailing_whitespace => 1,
    ],
    'Test::MinimumVersion' => [],

    'Test::Compile::PerFile' => [
      ":version"    => '0.003902',
      test_template => '02-raw-require.t.tpl'
    ],
    'Test::Perl::Critic' => [],
  ),
  'ManifestSkip' => [],
  include_or(
    !is_minimal,
    [
      'RewriteVersion::Sanitized' => [
        mantissa    => 6,
        normal_form => 'numify',
      ],
    ],
    [
      RewriteVersion => [],
    ],
  ),
  include_if(
    !is_minimal,
    'PodWeaver'   => [ replacer => 'replace_with_blank' ],
    'AutoPrereqs' => [],
    'MinimumPerl' => [],
    'Authority'   => [
      authority      => $common{authority},
      do_metadata    => 1,
      locate_comment => 1,
    ],
  ),
  MakeMaker => [
    default_jobs => $common{jobs}
  ],
  include_if(
    !is_minimal,
    'Author::KENTNL::RecommendFixes' => [
      ':version' => '0.004002',
    ],
    'Readme::Brief'  => [],
    ReadmeAnyFromPod => [
      filename => 'README.mkdn',
      location => 'root',
      type     => 'markdown',
    ],
    'Test::CPAN::Changes' => [],
    'RunExtraTests'       => [ default_jobs => $common{jobs} ],
    'TestRelease'         => [],
    'ConfirmRelease'      => [],
  ),
  include_if(
    !is_minimal && has_git,
    'Git::Check' => [
      filename => 'Changes',
    ],
    [ 'Git::Commit', 'commit_dirty' ] => [],
    [ 'Git::Tag',    'tag_master' ]   => [
      tag_format => '%v-source',
    ],
    'Git::NextRelease' => [
      ':version'     => '0.004000',
      default_branch => 'master',
      format         => q[%v %{yyyy-MM-dd'T'HH:mm:ss}dZ %h],
      time_zone      => 'UTC',
    ],
  ),
  include_if(
    !is_minimal, 'BumpVersionAfterRelease' => [],
  ),
  include_if(
    !is_minimal && has_git,
    'Git::Commit'      => [ 'allow_dirty_match' => '^lib/' ],
    'Git::CommitBuild' => [ branch              => 'builds', release_branch => 'releases' ],
    'Git::Tag'         => [ branch              => 'releases', tag_format => '%v' ],
  ),
  include_if(
    !is_minimal,
    'UploadToCPAN' => [],
    'Twitter'      => [
      hash_tags     => $common{hash_tags},
      tweet_url     => q[https://metacpan.org/release/{{$AUTHOR_UC}}/{{$DIST}}-{{$VERSION}}{{$TRIAL}}#whatsnew],
      url_shortener => 'none',
    ],
    'RemovePrereqs::Provided' => [],
    'CheckPrereqsIndexed'     => [],
  ),
);

( @distmeta, \@plugins )
