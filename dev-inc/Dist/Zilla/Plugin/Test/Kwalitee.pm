use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Kwalitee;    # git description: v2.11-22-g5782daa

# ABSTRACT: Author tests for kwalitee
# KEYWORDS: plugin testing tests distribution kwalitee CPANTS quality lint errors critic
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '2.12';

use Moose;
use Sub::Exporter::ForMethods 'method_installer';    # method_installer returns a sub.
use Data::Section 0.004                              # fixed header_re
  { installer => method_installer }, '-setup';
use namespace::autoclean;

with
  'Dist::Zilla::Role::FileGatherer',
  'Dist::Zilla::Role::TextTemplate',
  'Dist::Zilla::Role::PrereqSource';

sub mvp_multivalue_args { return qw( skiptest ) }

has skiptest => (
  isa     => 'ArrayRef[Str]',
  traits  => ['Array'],
  default => sub { [] },
  handles => {
    skiptest      => 'sort',
    push_skiptest => 'push'
  },
);

has filename => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { return 'xt/release/kwalitee.t' },
);

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    skiptest => [ $self->skiptest ],
    filename => $self->filename,
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };
  return $config;
};

sub _tk_prereq { '1.21' }

sub register_prereqs {
  my $self = shift;
  $self->zilla->register_prereqs(
    {
      type  => 'requires',
      phase => 'develop',
    },
    'Test::Kwalitee' => $self->_tk_prereq,
  );
}

sub gather_files {
  my ( $self, ) = @_;

  my $test_options = '';

  my @skiptests = $self->skiptest;
  if ( @skiptests > 0 ) {
    my $skip = join ' ', map { "-$_" } @skiptests;
    $test_options = qq{ qw( $skip ) };
  }

  require Dist::Zilla::File::InMemory;

  my $filename = $self->filename;

  my $content = $self->fill_in_string(
    ${ $self->section_data('__TEST__') },
    {
      dist         => \( $self->zilla ),
      plugin       => \$self,
      test_options => \$test_options,
      tk_prereq    => \( $self->_tk_prereq ),
    },
  );

  $self->add_file(
    Dist::Zilla::File::InMemory->new(
      {
        'name'    => $filename,
        'content' => $content,
      }
    ),
  );
}

__PACKAGE__->meta->make_immutable;

#pod =pod
#pod
#pod =head1 SYNOPSIS
#pod
#pod In your F<dist.ini>:
#pod
#pod     [Test::Kwalitee]
#pod     skiptest = use_strict ; Don't test for strictness.
#pod
#pod =head1 DESCRIPTION
#pod
#pod This is an extension of L<Dist::Zilla::Plugin::InlineFiles>, providing the
#pod following file:
#pod
#pod   xt/release/kwalitee.t - a standard Test::Kwalitee test
#pod
#pod =head1 CONFIGURATION OPTIONS
#pod
#pod =for stopwords skiptest
#pod
#pod =head2 skiptest
#pod
#pod The name of a kwalitee metric to skip (see the list in L<Test::Kwalitee>.
#pod Can be used more than once.
#pod
#pod =head2 filename
#pod
#pod The filename of the test to add - defaults to F<xt/release/kwalitee.t>.
#pod
#pod =for Pod::Coverage mvp_multivalue_args register_prereqs gather_files
#pod
#pod =head1 SEE ALSO
#pod
#pod =for :list
#pod * L<Module::CPANTS::Analyse>
#pod * L<App::CPANTS::Lint>
#pod * L<Test::Kwalitee>
#pod * L<Dist::Zilla::App::Command::kwalitee>
#pod * L<Test::Kwalitee::Extra>
#pod * L<Dist::Zilla::Plugin::Test::Kwalitee::Extra>
#pod
#pod =cut

__DATA__
___[ __TEST__ ]___
# this test was generated with {{ ref($plugin) . ' ' . $plugin->VERSION }}
use strict;
use warnings;
use Test::More 0.88;
use Test::Kwalitee {{ $tk_prereq }} 'kwalitee_ok';

kwalitee_ok({{ $test_options }});

done_testing;
