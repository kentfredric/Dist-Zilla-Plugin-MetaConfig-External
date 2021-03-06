package Dist::Zilla::Plugin::TravisCI;
our $AUTHORITY = 'cpan:GETTY';

# ABSTRACT: Integrating the generation of .travis.yml into your dzil
$Dist::Zilla::Plugin::TravisCI::VERSION = '0.010';
use Moose;
use Path::Tiny qw( path );
use Dist::Zilla::File::FromCode;

with 'Dist::Zilla::Role::FileGatherer', 'Dist::Zilla::Role::AfterBuild', 'Beam::Emitter';

our @phases = (
  ( map { my $phase = $_; ( 'before_' . $phase, $phase, 'after_' . $phase ) } qw( install script ) ),
  'after_success', 'after_failure'
);
our @emptymvarrayattr = qw( notify_email notify_irc requires env script_env extra_dep apt_package );

has $_ => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] } ) for ( @phases, @emptymvarrayattr );

our @bools = qw( verbose test_deps test_authordeps no_notify_email coveralls );

has $_ => ( is => 'ro', isa => 'Bool', default => sub { 0 } ) for @bools;

has irc_template => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub {
    [ "%{branch}#%{build_number} by %{author}: %{message} (%{build_url})", ]
  }
);

has perl_version => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub {
    [ "5.22", "5.20", "5.18", "5.16", "5.14", "5.12", "5.10", ]
  }
);

has 'write_to' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { ['root'] } );

our @core_env = ("HARNESS_OPTIONS=j10:c HARNESS_TIMER=1");

around mvp_multivalue_args => sub {
  my ( $orig, $self ) = @_;

  my @start = $self->$orig;
  return @start, @phases, @emptymvarrayattr, qw( irc_template perl_version write_to );
};

sub gather_files {
  my $self = shift;
  return unless grep { $_ eq 'build' } @{ $self->write_to };
  require YAML;
  my $file = Dist::Zilla::File::FromCode->new(
    name             => '.travis.yml',
    code_return_type => 'text',          # YAML::Dump returns text
    code             => sub {
      return $self->build_travis_yml_str;
    },
  );
  $self->add_file($file);
  return;
}

sub after_build {
  my $self = shift;
  return unless grep { $_ eq 'root' } @{ $self->write_to };
  path( $self->zilla->root, '.travis.yml' )->spew_utf8( $self->build_travis_yml_str );
  return;
}

sub _get_exports {
  shift;
  map { "export " . $_ } @_;
}

sub build_travis_yml_str {
  my ($self) = @_;
  my $structure = $self->build_travis_yml;
  require YAML;
  local $YAML::QuoteNumericStrings = 1;
  return YAML::Dump($structure);
}

sub build_travis_yml {
  my ( $self, $is_build_branch ) = @_;

  my $zilla     = $self->zilla;
  my %travisyml = ( language => "perl", perl => $self->perl_version );
  my $rmeta     = $zilla->distmeta->{resources};

  my %notifications;

  my @emails = grep { $_ } @{ $self->notify_email };
  if ( $self->no_notify_email ) {
    $notifications{email} = \"false";
  }
  elsif ( scalar @emails ) {
    $notifications{email} = \@emails;
  }

  if (%notifications) {
    $travisyml{notifications} = \%notifications;
  }

  if ( @{ $self->apt_package() } ) {
    $travisyml{addons}->{apt_packages} = $self->apt_package();
  }

  my %phases_commands = map { $_ => $self->$_ } @phases;

  my $verbose = $self->verbose ? ' --verbose ' : ' --quiet ';

  unshift @{ $phases_commands{before_install} },
    (
    'git config --global user.name "Dist Zilla Plugin TravisCI"',
    'git config --global user.email $HOSTNAME":not-for-mail@travis-ci.org"',
    );

  my @extra_deps = @{ $self->extra_dep };

  my $needs_cover;

  if ( $self->coveralls ) {
    push @extra_deps, 'Devel::Cover::Report::Coveralls';
    unshift @{ $phases_commands{after_success} }, 'cover -report coveralls';
    $needs_cover = 1;
  }

  if ($needs_cover) {
    push @{ $self->env }, 'HARNESS_PERL_SWITCHES=-MDevel::Cover=-db,$TRAVIS_BUILD_DIR/cover_db';
  }

  my @env_exports = $self->_get_exports( @core_env, @{ $self->env } );

  unless ( @{ $phases_commands{install} } ) {
    push @{ $phases_commands{install} },
      (
      "cpanm " . $verbose . " --notest --skip-installed Dist::Zilla",
      "dzil authordeps | grep -ve '^\\W' | xargs -n 5 -P 10 cpanm "
        . $verbose . " "
        . ( $self->test_authordeps ? "" : " --notest " )
        . " --skip-installed",
      "dzil listdeps | grep -ve '^\\W' | cpanm "
        . $verbose . " "
        . ( $self->test_deps ? "" : " --notest " )
        . " --skip-installed",
      );
    if (@extra_deps) {
      push @{ $phases_commands{install} },
        ( "cpanm " . $verbose . " " . ( $self->test_deps ? "" : " --notest " ) . " " . join( " ", @extra_deps ), );
    }
  }

  unless ( @{ $phases_commands{script} } ) {
    push @{ $phases_commands{script} }, "dzil smoke --release --author";
  }

  unshift @{ $phases_commands{script} }, $self->_get_exports( @{ $self->script_env } );

  unless ( @{ $phases_commands{install} } ) {
    $phases_commands{install} =
      [ 'cpanm --installdeps ' . $verbose . ' ' . ( $self->test_deps ? "" : "--notest" ) . ' --skip-installed .', ];
  }

  if ( @{ $self->requires } ) {
    unshift @{ $phases_commands{before_install} }, "sudo apt-get install -qq " . join( " ", @{ $self->requires } );
  }

  unshift @{ $phases_commands{before_install} }, ( 'rm .travis.yml', );

  push @{ $phases_commands{install} }, @{ delete $phases_commands{after_install} };

  unshift @{ $phases_commands{script} }, $self->_get_exports( @{ $self->script_env } );

  my $first = 0;
  for (@phases) {
    next unless defined $phases_commands{$_};
    my @commands = @{ $phases_commands{$_} };
    if (@commands) {
      $travisyml{$_} = [
        $first
        ? ()
        : (@env_exports), @commands,
      ];
      $first = 1;
    }
  }

  return $self->emit(
    'modify_travis_yml',
    class      => 'Dist::Zilla::Event::TravisCI::YML',
    travis_yml => { $self->modify_travis_yml(%travisyml) }
  )->travis_yml;
}

sub modify_travis_yml {
  my ( $self, %args ) = @_;
  return %args;
}

__PACKAGE__->meta->make_immutable;

package    # Hidden
  Dist::Zilla::Event::TravisCI::YML;

use Moose;
extends 'Beam::Event';

has 'travis_yml' => ( is => 'rw', isa => 'HashRef', required => 1 );

__PACKAGE__->meta->make_immutable;

1;

__END__

