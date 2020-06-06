use strict;
use warnings;

package Dist::Zilla::Plugin::Git::Contributors;    # git description: v0.031-2-gf4f7111

# vim: set ts=8 sts=4 sw=4 tw=115 et :
# ABSTRACT: Add contributor names from git to your distribution
# KEYWORDS: plugin distribution metadata git contributors authors commits

our $VERSION = '0.032';

use Moose;
with 'Dist::Zilla::Role::MetaProvider', 'Dist::Zilla::Role::PrereqSource';

use List::Util 1.33 qw(none any);
use Git::Wrapper 0.035;
use Try::Tiny;
use Path::Tiny 0.048;
use Moose::Util::TypeConstraints 'enum';
use List::UtilsBy 0.04 'uniq_by';
use Unicode::Collate 0.53;
use version;
use namespace::autoclean;

sub mvp_multivalue_args { qw(paths remove) }
sub mvp_aliases         { return { path => 'paths' } }

has include_authors => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has include_releaser => (
  is      => 'ro',
  isa     => 'Bool',
  default => 1,
);

has order_by => (
  is      => 'ro',
  isa     => enum( [qw(name commits)] ),
  default => 'name',
);

has paths => (
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  default => sub { [] },
  traits  => ['Array'],
  handles => { paths => 'elements' },
);

has remove => (
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  default => sub { [] },
  traits  => ['Array'],
  handles => { remove => 'elements' },
);

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  my $dist_root = path( $self->zilla->root )->realpath;

  $config->{ +__PACKAGE__ } = {
    include_authors  => $self->include_authors  ? 1 : 0,
    include_releaser => $self->include_releaser ? 1 : 0,
    order_by         => $self->order_by,
    paths            => [
      sort map {
        my $p = path($_)->realpath;
        ( $dist_root->subsumes($p) ? $p->relative($dist_root) : $p )->stringify
      } $self->paths
    ],
    $self->remove ? ( remove => '...' ) : (),
    git_version => $self->_git('version'),
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

sub metadata {
  my $self = shift;

  my $contributors = $self->_contributors;
  return if not @$contributors;

  $self->_check_podweaver;
  +{ x_contributors => $contributors };
}

sub register_prereqs {
  my $self = shift;

  return if none { /[^[:ascii:]]/ } @{ $self->_contributors };

  my $prereqs = $self->zilla->prereqs;
  my $all_prereqs =
    $prereqs->requirements_for(qw(runtime requires))
    ->clone->add_requirements( $prereqs->requirements_for(qw(configure requires)) )
    ->add_requirements( $prereqs->requirements_for(qw(build requires)) )
    ->add_requirements( $prereqs->requirements_for(qw(test requires)) )->as_string_hash;

  my $perl_prereq = $all_prereqs->{perl};

  $self->log_debug(
    [
      'found non-ascii characters in contributor names; perl prereq so far is %s',
      defined $perl_prereq ? $perl_prereq : 'unknown'
    ]
  );
  $perl_prereq = 0 if not defined $perl_prereq;
  $perl_prereq = version->parse($perl_prereq)->numify;
  return if "$perl_prereq" >= '5.008006';

  # many Dist::Zilla-using distributions don't have an explicit minimum
  # perl, but we know that Dist::Zilla doesn't work until 5.8.7
  return if any { /^Dist::Zilla/ } keys %$all_prereqs;

# if dynamic_config is set, the user gets another chance to read the file, via fallback code:
# < haarg> eumm loads META, updates prereqs, and writes out MYMETA
# < haarg> so in a working system, x_contributors will be included
# < haarg> in a broken system, it will fail to load META, regenerate it from parameters including META_ADD/MERGE, then write it out
# < haarg> so if there isn't any utf8 data in the parameters given to EUMM, it will produce a file that can be read by a "bad" JSON::PP
  return if $self->zilla->distmeta->{dynamic_config};

  # see https://github.com/makamaka/JSON-PP/pull/9 for for details
  $self->log(
'Warning: distribution has non-ascii characters in contributor names. META.json will be unparsable on perls <= 5.8.6 when JSON::PP is lower than 2.27300'
  );

  $self->zilla->register_prereqs(
    {
      phase => 'configure',
      type  => 'suggests',
    },
    'JSON::PP' => '2.27300',
  );
}

# should not be called before the MetaProvider phase
has _contributors => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  builder => '_build_contributors',
);

sub _build_contributors {
  my $self = shift;

  # note that ->status does something different.
  return [] if not $self->_git( RUN => 'status' );

  my @data = $self->_git(
    shortlog => {
      email   => 1,
      summary => 1,
      $self->order_by eq 'commits' ? ( numbered => 1 ) : (),
    },
    'HEAD',
    '--',
    $self->paths,
  );

  my @contributors = map { m/^\s*\d+\s*(.*)$/g; } @data;

  $self->log_debug(
    [
      'extracted contributors from git: %s',
      sub { require Data::Dumper; Data::Dumper->new( [ \@contributors ] )->Indent(2)->Terse(1)->Dump }
    ]
  );

  my $fc =
    "$]" >= '5.016001'
    ? \&CORE::fc
    : do {
    $self->log_debug('case-folding not available; falling back to lower-cased comparisons');
    sub { lc $_[0] }    # not callable via \&CORE::lc
    };

  # remove duplicates by email address, keeping the latest associated name
  @contributors = uniq_by { $fc->( (/(<[^>]+>)/g)[-1] ) } @contributors;

  @contributors = Unicode::Collate->new( level => 1 )->sort(@contributors) if $self->order_by eq 'name';

  if ( not $self->include_authors ) {
    my @author_emails = map { /(<[^>]+>)/g } @{ $self->zilla->authors };
    @contributors = grep {
      my $contributor = $_;
      none { $contributor =~ /\Q$_\E/i } @author_emails;
    } @contributors;
  }

  if ( not $self->include_releaser and my $releaser = $self->_releaser ) {
    @contributors = grep { $fc->($_) ne $fc->($releaser) } @contributors;
  }

  if ( $self->remove ) {
    @contributors = grep {
      my $contributor = $_;
      none { $contributor =~ /\Q$_\E/ } $self->remove
    } @contributors;
  }

  return \@contributors;
}

sub _releaser {
  my $self = shift;

  my ( $username, $email );
  try {
    ($username) = $self->_git( config => 'user.name' );
    ($email)    = $self->_git( config => 'user.email' );
  };
  if ( not $username or not $email ) {
    $self->log('could not extract user.name and user.email configs from git');
    return;
  }
  $username . ' <' . $email . '>';
}

sub _check_podweaver {
  my $self = shift;

  # check if the module is loaded, not just that it is installed
  $self->log(
'WARNING! You appear to be using Pod::Weaver::Section::Contributors, but it is not new enough to take data directly from distmeta. Upgrade to version 0.008!'
    )
    if eval      { Pod::Weaver::Section::Contributors->VERSION(0);        1 }
    and not eval { Pod::Weaver::Section::Contributors->VERSION(0.007001); 1 };
}

has __git => (
  is      => 'ro',
  isa     => 'Git::Wrapper',
  lazy    => 1,
  default => sub { Git::Wrapper->new( path( shift->zilla->root )->absolute->stringify ) },
);

sub _git {
  my ( $self, $command, @args ) = @_;

  die 'no command?!' if not $command;
  my $git    = $self->__git;
  my @result = try {
    $git->$command(@args);
  }
  catch {
    $self->log( blessed($_) && $_->isa('Git::Wrapper::Exception') ? $_->error : $_ );
    ();
  };
  my $err = $git->ERR;
  $self->log(@$err) if $err and @$err;

  # TODO Git::Wrapper should really be decoding this for us, via a new
  # (defaulting-to-false) utf8 flag
  utf8::decode($_) foreach @result;
  return @result;
}

__PACKAGE__->meta->make_immutable;

__END__

