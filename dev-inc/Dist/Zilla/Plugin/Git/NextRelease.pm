use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Git::NextRelease;

our $VERSION = '0.004001';

# ABSTRACT: Use time-stamp from Git instead of process start time.

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moose qw( extends has around );
extends 'Dist::Zilla::Plugin::NextRelease';

use Git::Wrapper::Plus 0.003100;    # Fixed shallow commits
use DateTime;
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );

use String::Formatter 0.100680 stringf => {
  -as => '_format_version',

  input_processor => 'require_single_input',
  string_replacer => 'method_replace',
  codes           => {
    v => sub { $_[0]->zilla->version },
    d => sub {
      my $t = $_[0]->_git_timestamp;
      $t = $t->set_time_zone( $_[0]->time_zone );
      return $t->format_cldr( $_[1] ),;
    },
    t => sub { "\t" },
    n => sub { "\n" },
    E => sub { $_[0]->_user_info('email') },
    U => sub { $_[0]->_user_info('name') },
    T => sub {
      $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[];
    },
    V => sub {
      $_[0]->zilla->version . ( $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[] );
    },
    'H' => sub { $_[0]->_git_sha1 },
    'h' => sub { $_[0]->_git_sha1_abbrev },
  },
};

has 'branch' => (
  is         => ro =>,
  lazy_build => 1,
);

has 'default_branch' => (
  is         => ro =>,
  lazy_build => 1,
  predicate  => 'has_default_branch',
);

sub _build_default_branch {
  my ($self) = @_;
  return $self->log_fatal('default_branch was used but not specified');
}

has _git_timestamp => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);
has '_gwp' => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);

around dump_config => config_dumper( __PACKAGE__, { attrs => [ 'default_branch', 'branch' ] } );

sub _build__gwp {
  my ($self) = @_;
  return Git::Wrapper::Plus->new( q[] . $self->zilla->root );
}

sub _build_branch {
  my ($self) = @_;
  my $cb = $self->_gwp->branches->current_branch;
  if ( not $cb ) {
    if ( not $self->has_default_branch ) {
      $self->log_fatal(
        [
              q[Cannot determine branch to get timestamp from when not on a branch.]
            . q[Specify default_branch if you want this to work here.],
        ],
      );
    }
    return $self->default_branch;
  }
  return $cb->name;
}

has '_branch_object'   => ( is => ro =>, init_arg => undef, lazy_build => 1 );
has '_branch_commit'   => ( is => ro =>, init_arg => undef, lazy_build => 1 );
has '_git_sha1'        => ( is => ro =>, init_arg => undef, lazy_build => 1 );
has '_git_sha1_abbrev' => ( is => ro =>, init_arg => undef, lazy_build => 1 );

sub _build__branch_object {
  my ($self) = @_;
  my ( $branch, ) = $self->_gwp->branches->get_branch( $self->branch );
  if ( not $branch ) {
    $self->log_fatal( [ q[Branch %s does not exist], $self->branch ] );
  }
  return $branch;
}

sub _build__git_sha1 {
  my ($self) = @_;
  return $self->_branch_object->sha1;
}

sub _build__git_sha1_abbrev {
  my ($self) = @_;
  return substr $self->_git_sha1, 0, 7;
}

sub _build__branch_commit {
  my ($self) = @_;
  return [ $self->_gwp->git->cat_file( 'commit', $self->_git_sha1 ) ];
}

sub _build__git_timestamp {
  my ($self) = @_;
  my ( $committer, ) = grep { /\Acommitter /msx } @{ $self->_branch_commit };
  chomp $committer;
  ## no critic ( Compatibility::PerlMinimumVersionAndWhy )
  if ( $committer =~ qr/\s+(\d+)\s+(\S+)\z/msx ) {
    return DateTime->from_epoch( epoch => $1, time_zone => $2 );
  }
  return $self->log_fatal( [ q[Could not parse timestamp and timezone from string <%s>], $committer ] );
}

sub section_header {
  my ($self) = @_;

  return _format_version( $self->format, $self );
}
__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

