use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Compile::PerFile;

our $VERSION = '0.004000';

# ABSTRACT: Create a single .t for each compilable file in a distribution

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use B ();

BEGIN {
  ## no critic (ProhibitCallsToUnexportedSubs)
  *_HAVE_PERLSTRING = defined &B::perlstring ? sub() { 1 } : sub() { 0 };
}
use Moose qw( with around has );
use MooseX::LazyRequire;

with 'Dist::Zilla::Role::FileGatherer', 'Dist::Zilla::Role::TextTemplate';

use Path::Tiny qw(path);
use File::ShareDir qw(dist_dir);
use Moose::Util::TypeConstraints qw(enum);

## no critic (ProhibitPackageVars)
our %path_translators;

$path_translators{base64_filter} = sub {
  my ($file) = @_;
  $file =~ s/[^-[:alnum:]_]+/_/msxg;
  return $file;
};

$path_translators{mimic_source} = sub {
  my ($file) = @_;
  return $file;
};

##
#
# This really example code, because this notation is so unrecommended, as Colons in file names
# are highly non-portable.
#
# Edit this to = 1 if you're 100% serious you want this.
#
##

if (0) {
  $path_translators{module_names} = sub {
    my ($file) = @_;
    return $file if $file !~ /\Alib\//msx;
    return $file if $file !~ /[.]pm\z/msx;
    $file =~ s{\Alib/}{}msx;
    $file =~ s{[.]pm\z}{}msx;
    $file =~ s{/}{::}msxg;
    $file = 'module/' . $file;
    return $file;
  };
}

our %templates = ();

{
  my $dist_dir     = dist_dir('Dist-Zilla-Plugin-Test-Compile-PerFile');
  my $template_dir = path($dist_dir);
  for my $file ( $template_dir->children ) {
    next if $file =~ /\A[.]/msx;    # Skip hidden files
    next if -d $file;               # Skip directories
    $templates{ $file->basename } = $file;
  }
}

around mvp_multivalue_args => sub {
  my ( $orig, $self, @args ) = @_;
  return ( 'finder', 'file', 'skip', $self->$orig(@args) );
};

around mvp_aliases => sub {
  my ( $orig, $self, @args ) = @_;
  my $hash = $self->$orig(@args);
  $hash = {} if not defined $hash;
  $hash->{files} = 'file';
  return $hash;
};

around dump_config => sub {
  my ( $orig, $self, @args ) = @_;
  my $config    = $self->$orig(@args);
  my $localconf = $config->{ +__PACKAGE__ } = {};

  $localconf->{finder}          = $self->finder if $self->has_finder;
  $localconf->{xt_mode}         = $self->xt_mode;
  $localconf->{prefix}          = $self->prefix;
  $localconf->{file}            = [ sort @{ $self->file } ];
  $localconf->{skip}            = $self->skip;
  $localconf->{path_translator} = $self->path_translator;
  $localconf->{test_template}   = $self->test_template;

  $localconf->{ q[$] . __PACKAGE__ . '::VERSION' } = $VERSION
    unless __PACKAGE__ eq ref $self;

  return $config;
};

sub BUILD {
  my ($self) = @_;
  return if $self->has_file;
  return if $self->has_finder;
  $self->_finder_objects;
  return;
}

has xt_mode => ( is => ro =>, isa => Bool =>, lazy_build => 1 );

has prefix => ( is => ro =>, isa => Str =>, lazy_build => 1 );

has file => ( is => ro =>, isa => 'ArrayRef[Str]', lazy_build => 1, );

has skip => ( is => ro =>, isa => 'ArrayRef[Str]', lazy_build => 1, );

has finder => ( is => ro =>, isa => 'ArrayRef[Str]', lazy_required => 1, predicate => 'has_finder' );

has path_translator => ( is => ro =>, isa => enum( [ sort keys %path_translators ] ), lazy_build => 1 );

has test_template => ( is => ro =>, isa => enum( [ sort keys %templates ] ), lazy_build => 1 );

sub _quoted {
  no warnings 'numeric';
  ## no critic (ProhibitBitwiseOperators,ProhibitCallsToUndeclaredSubs)
  ## no critic (ProhibitCallsToUnexportedSubs,ProhibitUnusedVarsStricter)
  !defined $_[0]
    ? 'undef()'
    : ( length( ( my $dummy = q[] ) & $_[0] ) && 0 + $_[0] eq $_[0] && $_[0] * 0 == 0 ) ? $_[0]    # numeric detection
    : _HAVE_PERLSTRING ? B::perlstring( $_[0] )
    :                    qq["\Q$_[0]\E"];
}

sub _generate_file {
  my ( $self, $name, $file ) = @_;
  my $relpath = ( $file =~ /\Alib\/(.*)\z/msx ? $1 : q[./] . $file );

  $self->log_debug("relpath for $file is: $relpath");

  my $code = sub {
    return $self->fill_in_string(
      $self->_test_template_content,
      {
        file              => $file,
        relpath           => $relpath,
        plugin_module     => $self->meta->name,
        plugin_name       => $self->plugin_name,
        plugin_version    => ( $self->VERSION ? $self->VERSION : '<self>' ),
        test_more_version => '0.89',
        quoted            => \&_quoted,
      },
    );
  };
  return Dist::Zilla::File::FromCode->new(
    name             => $name,
    code_return_type => 'text',
    code             => $code,
  );
}

sub gather_files {
  my ($self) = @_;
  require Dist::Zilla::File::FromCode;

  my $prefix = $self->prefix;
  $prefix =~ s{/?\z}{/}msx;

  my $translator = $self->_path_translator;

  if ( not @{ $self->file } ) {
    $self->log_debug('Did not find any files to add tests for, did you add any files yet?');
    return;
  }
  my $skiplist = {};
  for my $skip ( @{ $self->skip } ) {
    $skiplist->{$skip} = 1;
  }
  for my $file ( @{ $self->file } ) {
    if ( exists $skiplist->{$file} ) {
      $self->log_debug("Skipping compile test generation for $file");
      next;
    }
    my $name = sprintf q[%s%s.t], $prefix, $translator->($file);
    $self->log_debug("Adding $name for $file");
    $self->add_file( $self->_generate_file( $name, $file ) );
  }
  return;
}

has _path_translator       => ( is => ro =>, isa => CodeRef =>, lazy_build => 1, init_arg => undef );
has _test_template         => ( is => ro =>, isa => Defined =>, lazy_build => 1, init_arg => undef );
has _test_template_content => ( is => ro =>, isa => Defined =>, lazy_build => 1, init_arg => undef );
has _finder_objects => ( is => ro =>, isa => 'ArrayRef', lazy_build => 1, init_arg => undef );

__PACKAGE__->meta->make_immutable;
no Moose;
no Moose::Util::TypeConstraints;

sub _build_xt_mode {
  return;
}

sub _build_prefix {
  my ($self) = @_;
  if ( $self->xt_mode ) {
    return 'xt/author/00-compile';
  }
  return 't/00-compile';
}

sub _build_path_translator {
  my ( undef, ) = @_;
  return 'base64_filter';
}

sub _build__path_translator {
  my ($self) = @_;
  my $translator = $self->path_translator;
  return $path_translators{$translator};
}

sub _build_test_template {
  return '01-basic.t.tpl';
}

sub _build__test_template {
  my ($self) = @_;
  my $template = $self->test_template;
  return $templates{$template};
}

sub _build__test_template_content {
  my ($self) = @_;
  my $template = $self->_test_template;
  return $template->slurp_utf8;
}

sub _build_file {
  my ($self) = @_;
  return [ map { $_->name } @{ $self->_found_files } ];
}

sub _build_skip {
  return [];
}

sub _build__finder_objects {
  my ($self) = @_;
  if ( $self->has_finder ) {
    my @out;
    for my $finder ( @{ $self->finder } ) {
      my $plugin = $self->zilla->plugin_named($finder);
      if ( not $plugin ) {
        $self->log_fatal("no plugin named $finder found");
      }
      if ( not $plugin->does('Dist::Zilla::Role::FileFinder') ) {
        $self->log_fatal("plugin $finder is not a FileFinder");
      }
      push @out, $plugin;
    }
    return \@out;
  }
  return [ $self->_vivify_installmodules_pm_finder ];
}

sub _vivify_installmodules_pm_finder {
  my ($self) = @_;
  my $name = $self->plugin_name;
  $name .= '/AUTOVIV/:InstallModulesPM';
  if ( my $plugin = $self->zilla->plugin_named($name) ) {
    return $plugin;
  }
  require Dist::Zilla::Plugin::FinderCode;
  my $plugin = Dist::Zilla::Plugin::FinderCode->new(
    {
      plugin_name => $name,
      zilla       => $self->zilla,
      style       => 'grep',
      code        => sub {
        my ( $file, $self ) = @_;
        local $_ = $file->name;
        ## no critic (RegularExpressions)
        return 1 if m{\Alib/} and m{\.(pm)$};
        return 1 if $_ eq $self->zilla->main_module;
        return;
      },
    },
  );
  push @{ $self->zilla->plugins }, $plugin;
  return $plugin;
}

sub _found_files {
  my ($self) = @_;
  my %by_name;
  for my $plugin ( @{ $self->_finder_objects } ) {
    for my $file ( @{ $plugin->find_files } ) {
      $by_name{ $file->name } = $file;
    }
  }
  return [ values %by_name ];
}

1;

__END__

