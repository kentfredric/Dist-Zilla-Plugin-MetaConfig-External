package Data::DPath::Path;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Abstraction for a DPath
$Data::DPath::Path::VERSION = '0.57';
use strict;
use warnings;

use Data::Dumper;
use aliased 'Data::DPath::Step';
use aliased 'Data::DPath::Point';
use aliased 'Data::DPath::Context';
use Text::Balanced 2.02 'extract_delimited', 'extract_codeblock';

use Class::XSAccessor
  chained   => 1,
  accessors => {
  path            => 'path',
  _steps          => '_steps',
  give_references => 'give_references',
  };

use constant {
  ROOT             => 'ROOT',
  ANYWHERE         => 'ANYWHERE',
  KEY              => 'KEY',
  ANYSTEP          => 'ANYSTEP',
  NOSTEP           => 'NOSTEP',
  PARENT           => 'PARENT',
  ANCESTOR         => 'ANCESTOR',
  ANCESTOR_OR_SELF => 'ANCESTOR_OR_SELF',
};

sub new {
  my $class = shift;
  my $self  = bless {@_}, $class;
  $self->_build__steps;
  return $self;
}

sub unescape {
  my ($str) = @_;

  return unless defined $str;
  $str =~ s/(?<!\\)\\(["'])/$1/g;    # '"$
  $str =~ s/\\{2}/\\/g;
  return $str;
}

sub unquote {
  my ($str) = @_;
  $str =~ s/^"(.*)"$/$1/g;
  return $str;
}

sub quoted { shift =~ m,^/["'],; }    # "

eval 'use overload "~~" => \&op_match' if $] >= 5.010;

sub op_match {
  my ( $self, $data, $rhs ) = @_;

  return $self->matchr($data);
}

# essentially the Path parser
sub _build__steps {
  my ($self) = @_;

  my $remaining_path = $self->path;
  my $extracted;
  my @steps;

  push @steps, Step->new->part('')->kind(ROOT);

  while ($remaining_path) {
    my $plain_part;
    my $filter;
    my $kind;
    if ( quoted($remaining_path) ) {
      ( $plain_part, $remaining_path ) = extract_delimited( $remaining_path, q/'"/, "/" );    # '
      ( $filter,     $remaining_path ) = extract_codeblock( $remaining_path, "[]" );
      $plain_part = unescape unquote $plain_part;
      $kind       = KEY;                                                                      # quoted is always a key
    }
    else {
      my $filter_already_extracted = 0;
      ( $extracted, $remaining_path ) = extract_delimited( $remaining_path, '/' );

      if ( not $extracted ) {
        ( $extracted, $remaining_path ) = ( $remaining_path, undef );                         # END OF PATH
      }
      else {

        # work around to recognize slashes in filter expressions and handle them:
        #
        # - 1) see if key unexpectedly contains opening "[" but no closing "]"
        # - 2) use the part before "["
        # - 3) unshift the rest to remaining
        # - 4) extract_codeblock() explicitely
        if ( $extracted =~ /(.*)((?<!\\)\[.*)/ and $extracted !~ m|\]/\s*$| ) {
          $remaining_path = $2 . $remaining_path;
          ( $plain_part = $1 ) =~ s|^/||;
          ( $filter, $remaining_path ) = extract_codeblock( $remaining_path, "[]" );
          $filter_already_extracted = 1;
        }
        else {
          $remaining_path = ( chop $extracted ) . $remaining_path;
        }
      }

      ( $plain_part, $filter ) = $extracted =~ m,^/              # leading /
                                                                 (.*?)           # path part
                                                                 (\[.*\])?$      # optional filter
                                                                ,xg unless $filter_already_extracted;
      $plain_part = unescape $plain_part;
    }

    no warnings 'uninitialized';
    if    ( $plain_part eq '' )                   { $kind ||= ANYWHERE }
    elsif ( $plain_part eq '*' )                  { $kind ||= ANYSTEP }
    elsif ( $plain_part eq '.' )                  { $kind ||= NOSTEP }
    elsif ( $plain_part eq '..' )                 { $kind ||= PARENT }
    elsif ( $plain_part eq '::ancestor' )         { $kind ||= ANCESTOR }
    elsif ( $plain_part eq '::ancestor-or-self' ) { $kind ||= ANCESTOR_OR_SELF }
    else                                          { $kind ||= KEY }

    push @steps, Step->new->part($plain_part)->kind($kind)->filter($filter);
  }
  pop @steps if $steps[-1]->kind eq ANYWHERE;    # ignore final '/'
  $self->_steps( \@steps );
}

sub match {
  my ( $self, $data ) = @_;

  return @{ $self->matchr($data) };
}

sub matchr {
  my ( $self, $data ) = @_;

  my $context = Context->new->current_points( [ Point->new->ref( \$data ) ] )->give_references( $self->give_references );
  return $context->matchr($self);
}

1;

__END__

