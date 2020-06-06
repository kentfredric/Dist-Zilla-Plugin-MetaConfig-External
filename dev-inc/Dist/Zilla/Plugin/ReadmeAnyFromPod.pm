use strict;
use warnings;

package Dist::Zilla::Plugin::ReadmeAnyFromPod;

# ABSTRACT: Automatically convert POD to a README in any format for Dist::Zilla
$Dist::Zilla::Plugin::ReadmeAnyFromPod::VERSION = '0.163250';
use List::Util 1.33 qw( none first );
use Moose::Util::TypeConstraints qw(enum);
use Moose;
use MooseX::Has::Sugar;
use Path::Tiny 0.004;
use Scalar::Util 'blessed';

with 'Dist::Zilla::Role::AfterBuild',
  'Dist::Zilla::Role::AfterRelease',
  'Dist::Zilla::Role::FileGatherer',
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::FilePruner',
  'Dist::Zilla::Role::FileWatcher',
  'Dist::Zilla::Role::PPI',
  ;

# TODO: Should these be separate modules?
our $_types = {
  pod => {
    filename => 'README.pod',
    parser   => sub {
      return $_[0];
    },
  },
  text => {
    filename => 'README',
    parser   => sub {
      my $pod = $_[0];

      require Pod::Simple::Text;
      Pod::Simple::Text->VERSION('3.23');
      my $parser = Pod::Simple::Text->new;
      $parser->output_string( \my $content );
      $parser->parse_characters(1);
      $parser->parse_string_document($pod);
      return $content;
    },
  },
  markdown => {
    filename => 'README.mkdn',
    parser   => sub {
      my $pod = $_[0];

      require Pod::Markdown;
      Pod::Markdown->VERSION('2.000');
      my $parser = Pod::Markdown->new();
      $parser->output_string( \my $content );
      $parser->parse_characters(1);
      $parser->parse_string_document($pod);
      return $content;
    },
  },
  gfm => {
    filename => 'README.md',
    parser   => sub {
      my $pod = $_[0];

      require Pod::Markdown::Github;
      Pod::Markdown->VERSION('0.01');
      my $parser = Pod::Markdown::Github->new();
      $parser->output_string( \my $content );
      $parser->parse_characters(1);
      $parser->parse_string_document($pod);
      return $content;
    },
  },
  html => {
    filename => 'README.html',
    parser   => sub {
      my $pod = $_[0];

      require Pod::Simple::HTML;
      Pod::Simple::HTML->VERSION('3.23');
      my $parser = Pod::Simple::HTML->new;
      $parser->output_string( \my $content );
      $parser->parse_characters(1);
      $parser->parse_string_document($pod);
      return $content;
    }
  }
};

has type => (
  ro, lazy,
  isa     => enum( [ keys %$_types ] ),
  default => sub { $_[0]->__from_name()->[0] || 'text' },
);

has filename => (
  ro, lazy,
  isa     => 'Str',
  default => sub { $_types->{ $_[0]->type }->{filename}; }
);

has source_filename => (
  ro, lazy,
  isa     => 'Str',
  builder => '_build_source_filename',
);

sub _build_source_filename {
  my $self = shift;
  my $pm   = $self->zilla->main_module->name;
  ( my $pod = $pm ) =~ s/\.pm$/\.pod/;
  return -e $pod ? $pod : $pm;
}

has location => (
  ro, lazy,
  isa     => enum( [qw(build root)] ),
  default => sub { $_[0]->__from_name()->[1] || 'build' },
);

has phase => (
  ro, lazy,
  isa     => enum( [qw(build release)] ),
  default => 'build',
);

sub BUILD {
  my $self = shift;

  $self->log_fatal('You cannot use location=build with phase=release!')
    if $self->location eq 'build' and $self->phase eq 'release';

  $self->log(
    'You are creating a .pod directly in the build - be aware that this will be installed like a .pm file and as a manpage')
    if $self->location eq 'build' and $self->type eq 'pod';
}

sub gather_files {
  my ($self) = @_;

  my $filename = $self->filename;
  if (
    $self->location eq 'build'

    # allow for the file to also exist in the dist
    and none { $_->name eq $filename } @{ $self->zilla->files }
    )
  {
    require Dist::Zilla::File::InMemory;
    my $file = Dist::Zilla::File::InMemory->new(
      {
        content => 'this will be overwritten',
        name    => $self->filename,
      }
    );

    $self->add_file($file);
  }
  return;
}

sub prune_files {
  my ($self) = @_;

  # leave the file in the dist if another instance of us is adding it there.
  if ( $self->location eq 'root'
    and not grep { blessed($self) eq blessed($_) and $_->location eq 'build' and $_->filename eq $self->filename }
    @{ $self->zilla->plugins } )
  {
    for my $file ( @{ $self->zilla->files } ) {
      next unless $file->name eq $self->filename;
      $self->log_debug( [ 'pruning %s', $file->name ] );
      $self->zilla->prune_file($file);
    }
  }
  return;
}

sub munge_files {
  my $self = shift;

  if ( $self->location eq 'build' ) {
    my $filename = $self->filename;
    my $file     = first { $_->name eq $filename } @{ $self->zilla->files };
    if ($file) {
      $self->munge_file($file);
    }
    else {
      $self->log_fatal(
        "Could not find a $filename file during the build" . ' - did you prune it away with a PruneFiles block?' );
    }
  }
  return;
}

my %watching;

sub munge_file {
  my ( $self, $target_file ) = @_;

  # Ensure that we repeat the munging if the source file is modified
  # after we run.
  my $source_file = $self->_source_file();
  $self->watch_file(
    $source_file,
    sub {
      my ( $self, $watched_file ) = @_;

      # recalculate the content based on the updates
      $self->log( 'someone tried to munge ' . $watched_file->name . ' after we read from it. Making modifications again...' );
      $self->munge_file($target_file);
    }
  ) if not $watching{ $source_file->name }++;

  $self->log_debug( [ 'ReadmeAnyFromPod updating contents of %s in dist', $target_file->name ] );
  $target_file->content( $self->get_readme_content );
  return;
}

sub after_build {
  my $self = shift;
  $self->_create_readme if $self->phase eq 'build';
}

sub after_release {
  my $self = shift;
  $self->_create_readme if $self->phase eq 'release';
}

sub _create_readme {
  my $self = shift;

  if ( $self->location eq 'root' ) {
    my $filename = $self->filename;
    $self->log_debug( [ 'ReadmeAnyFromPod updating contents of %s in root', $filename ] );

    my $content = $self->get_readme_content();

    my $destination_file = path( $self->zilla->root )->child($filename);
    if ( -e $destination_file ) {
      $self->log("overriding $filename in root");
    }
    my $encoding = $self->_get_source_encoding();
    $destination_file->spew_raw(
        $encoding eq 'raw'
      ? $content
      : do { require Encode; Encode::encode( $encoding, $content ) }
    );
  }

  return;
}

sub _source_file {
  my ($self) = shift;

  my $filename = $self->source_filename;
  first { $_->name eq $filename } @{ $self->zilla->files };
}

# Holds the contents of the source file as of the last time we
# generated a readme from it. We use this to detect when the source
# file is modified so we can update the README file again.
has _last_source_content => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);

sub _get_source_pod {
  my ($self) = shift;

  my $source_file = $self->_source_file;

  # cache contents before we alter it, for later comparison
  $self->_last_source_content( $source_file->content );

  require PPI::Document;    # for Dist::Zilla::Role::PPI < 5.009
  my $doc = $self->ppi_document_for_file($source_file);

  my $pod_elems   = $doc->find('PPI::Token::Pod');
  my $pod_content = "";
  if ($pod_elems) {

    # Concatenation should stringify it
    $pod_content .= PPI::Token::Pod->merge(@$pod_elems);
  }

  if ( ( my $encoding = $self->_get_source_encoding ) ne 'raw'
    and not eval { Dist::Zilla::Role::PPI->VERSION('6.003') } )
  {
    # older Dist::Zilla::Role::PPI passes encoded content to PPI
    require Encode;
    $pod_content = Encode::decode( $encoding, $pod_content );
  }

  return $pod_content;
}

sub _get_source_encoding {
  my ($self) = shift;
  my $source_file = $self->_source_file;
  return $source_file->can('encoding')
    ? $source_file->encoding
    : 'raw';    # Dist::Zilla pre-5.0
}

sub get_readme_content {
  my ($self)     = shift;
  my $source_pod = $self->_get_source_pod();
  my $parser     = $_types->{ $self->type }->{parser};

  # Save the POD text used to generate the README.
  return $parser->($source_pod);
}

{
  my %cache;

  sub __from_name {
    my ($self) = @_;
    my $name = $self->plugin_name;

    # Use cached values if available
    if ( $cache{$name} ) {
      return $cache{$name};
    }

    # qr{TYPE1|TYPE2|...}
    my $type_regex = join( '|', map { quotemeta } keys %$_types );

    # qr{LOC1|LOC2|...}
    my $location_regex = join( '|', map { quotemeta } qw(build root) );

    # qr{(?:Readme)? (TYPE1|TYPE2|...) (?:In)? (LOC1|LOC2|...) }x
    my $complete_regex = qr{ (?:Readme)? ($type_regex) (?:(?:In)? ($location_regex))? }ix;
    my ( $type, $location ) = ( lc $name ) =~ m{(?:\A|/) \s* $complete_regex \s* \Z}ix;
    $cache{$name} = [ $type, $location ];
    return $cache{$name};
  }
}

__PACKAGE__->meta->make_immutable;

__END__

