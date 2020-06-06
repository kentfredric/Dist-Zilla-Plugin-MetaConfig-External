package Data::DPath::Context;
our $AUTHORITY = 'cpan:SCHWIGON';

# ABSTRACT: Abstraction for a current context that enables incremental searches
$Data::DPath::Context::VERSION = '0.57';
use strict;
use warnings;

use Data::Dumper;
use aliased 'Data::DPath::Point';
use aliased 'Data::DPath::Attrs';
use List::MoreUtils 'uniq';
use Scalar::Util 'reftype';
use Data::DPath::Filters;
use Iterator::Util;
use List::Util 'min';

#use Sys::CPU;
use POSIX ();
use Safe;

# run filter expressions in own Safe.pm compartment
our $COMPARTMENT;
our $THREADCOUNT;

BEGIN {
  #$THREADCOUNT = $Data::DPath::PARALLELIZE ? Sys::CPU::cpu_count : 1;
  #print "THREADCOUNT: $THREADCOUNT\n";
  package Data::DPath::Filters;

  $COMPARTMENT = Safe->new;
  $COMPARTMENT->permit(qw":base_core");
  $COMPARTMENT->reval('no warnings;');    # just so warnings is loaded
  if ( $] >= 5.010 ) {
    $COMPARTMENT->deny(qw":load");
  }
  else {
    $COMPARTMENT->deny(qw"require dofile caller");
  }

  # map DPath filter functions into new namespace
  $COMPARTMENT->share(
    qw(affe
      idx
      size
      key
      value
      isa
      reftype
      is_reftype
      )
  );
}

# print "use $]\n" if $] >= 5.010; # allow new-school Perl inside filter expressions
# eval "use $]" if $] >= 5.010; # allow new-school Perl inside filter expressions

use Class::XSAccessor::Array
  chained     => 1,
  constructor => 'new',
  accessors   => {
  current_points  => 0,
  give_references => 1,
  };

use constant {
  HASH             => 'HASH',
  ARRAY            => 'ARRAY',
  SCALAR           => 'SCALAR',
  ROOT             => 'ROOT',
  ANYWHERE         => 'ANYWHERE',
  KEY              => 'KEY',
  ANYSTEP          => 'ANYSTEP',
  NOSTEP           => 'NOSTEP',
  PARENT           => 'PARENT',
  ANCESTOR         => 'ANCESTOR',
  ANCESTOR_OR_SELF => 'ANCESTOR_OR_SELF',
};

sub _splice_threads {
  my ($cargo) = @_;

  my $nr_cargo = @$cargo;

  return [ [] ] unless $nr_cargo;

  my $threadcount = $THREADCOUNT || 1;
  my $blocksize   = POSIX::ceil( $nr_cargo / $threadcount );

  my @result = map {
    my $first = $_ * $blocksize;
    my $last  = min( ( $_ + 1 ) * $blocksize - 1, $nr_cargo - 1 );
    ( $first <= $last ) ? [ @$cargo[ $first .. $last ] ] : ();
  } 0 .. $threadcount - 1;

  return \@result;
}

# only finds "inner" values; if you need the outer start value
# then just wrap it into one more level of array brackets.
sub _any {
  my ( $out, $in, $lookahead_key ) = @_;

  no warnings 'uninitialized';

  $in = defined $in ? $in : [];
  return $out unless @$in;

  my @newin;
  my $tmp_ref;
  my $tmp_deref;
  my $tmp_reftype;

  foreach my $point (@$in) {
    my @values;
    next unless defined $point;
    my $ref = $point->ref;

    # speed optimization: first try faster ref, then reftype
    if ( ref($$ref) eq HASH or reftype($$ref) eq HASH ) {
      push @$out, map {
        my $newpoint = Point->new->ref( \( $$ref->{$_} ) )->parent($point)->attrs( Attrs->new( key => $_ ) );
        push @newin, $newpoint;    # remember added points
        $newpoint;
        }
        grep {
        # speed optimization: only consider a key if lookahead looks promising
        not defined $lookahead_key
          or $_ eq $lookahead_key
          or ( $tmp_ref = ref( $tmp_deref = $$ref->{$_} ) ) eq HASH
          or $tmp_ref eq ARRAY
          or ( $tmp_reftype = reftype($tmp_deref) ) eq HASH
          or $tmp_reftype eq ARRAY

          # or HASH_or_ARRAY(\($$ref->{$_}))
        }
        keys %{$$ref};
    }
    elsif ( ref($$ref) eq ARRAY or reftype($$ref) eq ARRAY ) {
      my $idx = 0;
      push @$out, map {
        my $newpoint = Point->new->ref( $_->{val_ref} )->parent($point)->attrs( Attrs->new( idx => $idx++ ) );
        push @newin, $newpoint;    # remember added points
        $newpoint;
        }
        map { { val_ref => \$_ } } @{$$ref};
    }
    else {
      next;
    }
  }
  return _any( $out, \@newin, $lookahead_key );
}

sub _all {
  my ($self) = @_;

  return @{ $self->_all_ref };
}

sub _all_ref {
  my ($self) = @_;

  no strict 'refs';
  no warnings 'uninitialized';

  return [
    map { $self->give_references ? $_      : $$_ } uniq
    map { defined $_             ? $_->ref : () } @{ $self->current_points }
  ];
}

# filter current results by array index
sub _filter_points_index {
  my ( $self, $index, $points ) = @_;

  return $points ? [ $points->[$index] ] : [];
}

# filter current results by condition
sub _filter_points_eval {
  my ( $self, $filter, $points ) = @_;

  return [] unless @$points;
  return $points unless defined $filter;

  my $new_points;
  my $res;
  {

    package Data::DPath::Filters;

    local our $idx = 0;
    $new_points = [
      grep {
        local our $p = $_;
        local $_;
        my $pref = $p->ref;
        if ( defined $pref ) {
          $_ = $$pref;
          if ($Data::DPath::USE_SAFE) {

            # 'uninitialized' values are the norm
            # but "no warnings 'uninitialized'" does
            # not work in this restrictive Safe.pm config, so
            # we deactivate warnings completely by localizing $^W.
            # on later Perls, ^W doesn't do the whole trick, so explicitly turn
            # all warnings off.  need to do this in a BEGIN, as some warnings
            # are compile time only.
            $res = $COMPARTMENT->reval( 'BEGIN{ warnings->unimport}; local $^W;' . $filter );
          }
          else {
            # 'uninitialized' values are the norm
            no warnings 'uninitialized';
            no if $] >= 5.018, warnings => 'experimental::smartmatch';
            $res = eval($filter);
          }
          print STDERR ( $@, "\n" ) if $@;
        }
        else {
          $res = 0;
        }
        $idx++;
        $res;
      } @$points
    ];
  }
  return $new_points;
}

sub _filter_points {
  my ( $self, $step, $points ) = @_;

  no strict 'refs';
  no warnings 'uninitialized';

  return [] unless @$points;

  my $filter = $step->filter;
  return $points unless defined $filter;

  $filter =~ s/^\[\s*(.*?)\s*\]$/$1/;    # strip brackets and whitespace

  if ( $filter =~ /^-?\d+$/ ) {
    return $self->_filter_points_index( $filter, $points );    # simple array index
  }
  elsif ( $filter =~ /\S/ ) {
    return $self->_filter_points_eval( $filter, $points );     # full condition
  }
  else {
    return $points;
  }
}

# the root node
# (only makes sense at first step, but currently not asserted)
sub _select_root {
  my ( $self, $step, $current_points, $new_points ) = @_;

  my $step_points = $self->_filter_points( $step, $current_points );
  push @$new_points, @$step_points;
}

# //
# anywhere in the tree
sub _select_anywhere {
  my ( $self, $step, $current_points, $lookahead, $new_points ) = @_;

  # speed optimization: only useful points added
  my $lookahead_key;
  if ( defined $lookahead and $lookahead->kind eq KEY ) {
    $lookahead_key = $lookahead->part;
  }

  # '//'
  # all hash/array nodes of a data structure
  foreach my $point (@$current_points) {
    my @step_points = ( @{ _any( [], [$point], $lookahead_key ) }, $point );
    push @$new_points, @{ $self->_filter_points( $step, \@step_points ) };
  }
}

# /key
# the value of a key
sub _select_key {
  my ( $self, $step, $current_points, $new_points ) = @_;

  foreach my $point (@$current_points) {
    no warnings 'uninitialized';
    next unless defined $point;
    my $pref = $point->ref;
    next
      unless (
      # speed optimization:
      # first try faster ref, then reftype
      ref($$pref) eq HASH or reftype($$pref) eq HASH
      );

    # take point as hash, skip undefs
    my $attrs       = Attrs->new( key => $step->part );
    my $step_points = [];
    if ( exists $$pref->{ $step->part } ) {
      $step_points = [ Point->new->ref( \( $$pref->{ $step->part } ) )->parent($point)->attrs($attrs) ];
    }
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

# '*'
# all leaves of a data tree
sub _select_anystep {
  my ( $self, $step, $current_points, $new_points ) = @_;

  no warnings 'uninitialized';
  foreach my $point (@$current_points) {

    # take point as array
    my $pref        = $point->ref;
    my $ref         = $$pref;
    my $step_points = [];

    # speed optimization: first try faster ref, then reftype
    if ( ref($ref) eq HASH or reftype($ref) eq HASH ) {
      $step_points = [
        map {
          my $v_ref = \( $ref->{$_} );
          my $attrs = Attrs->new( key => $_ );
          Point->new->ref($v_ref)->parent($point)->attrs($attrs)
        } keys %$ref
      ];
    }
    elsif ( ref($ref) eq ARRAY or reftype($ref) eq ARRAY ) {
      my $idx = 0;
      $step_points = [
        map {
          my $attrs = Attrs->new( idx => $idx++ );
          Point->new->ref( \$_ )->parent($point)->attrs($attrs)
        } @$ref
      ];
    }
    else {
      if ( ref($pref) eq SCALAR or reftype($pref) eq SCALAR ) {

        # TODO: without map, it's just one value
        $step_points = [    #map {
          Point->new->ref($pref)->parent($point)    # XXX? why $_? What happens to $pref?
        ];                                          # } $ref ];
      }
    }
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

# '.'
# no step (neither up nor down), just allow filtering
sub _select_nostep {
  my ( $self, $step, $current_points, $new_points ) = @_;

  foreach my $point ( @{$current_points} ) {
    my $step_points = [$point];
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

# '..'
# the parent
sub _select_parent {
  my ( $self, $step, $current_points, $new_points ) = @_;

  foreach my $point ( @{$current_points} ) {
    next unless defined $point;
    my $step_points = [ $point->parent ];
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

# '::ancestor'
# all ancestors (parent, grandparent, etc.) of the current node
sub _select_ancestor {
  my ( $self, $step, $current_points, $new_points ) = @_;

  foreach my $point ( @{$current_points} ) {
    my $step_points = [];
    my $parent      = $point;
    while ( $parent = $parent->parent ) {
      push @$step_points, $parent;    # order matters
    }
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

# '::ancestor-or-self'
# all ancestors (parent, grandparent, etc.) of the current node and the current node itself
sub _select_ancestor_or_self {
  my ( $self, $step, $current_points, $new_points ) = @_;

  foreach my $point ( @{$current_points} ) {
    my $step_points = [$point];
    my $parent      = $point;
    while ( $parent = $parent->parent ) {
      push @$step_points, $parent;    # order matters
    }
    push @$new_points, @{ $self->_filter_points( $step, $step_points ) };
  }
}

sub ref {
  my ($self) = @_;
  $self->first_point->{ref};
}

sub deref {
  my ($self) = @_;
  ${ $self->ref };
}

sub first_point {
  my ($self) = @_;
  $self->current_points->[0];
}

sub all_points {
  my ($self) = @_;
  iarray $self->current_points;
}

sub _iter {
  my ($self) = @_;

  my $iter = iarray $self->current_points;
  return imap { __PACKAGE__->new->current_points( [$_] ) } $iter;
}

sub isearch {
  my ( $self, $path_str ) = @_;
  $self->_search( Data::DPath::Path->new( path => $path_str ) )->_iter;
}

sub _search {
  my ( $self, $dpath ) = @_;

  no strict 'refs';
  no warnings 'uninitialized';

  my $current_points = $self->current_points;
  my $steps          = $dpath->_steps;
  for ( my $i = 0 ; $i < @$steps ; $i++ ) {
    my $step       = $steps->[$i];
    my $lookahead  = $steps->[ $i + 1 ];
    my $new_points = [];

    if ( $step->kind eq ROOT ) {
      $self->_select_root( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq ANYWHERE ) {
      $self->_select_anywhere( $step, $current_points, $lookahead, $new_points );
    }
    elsif ( $step->kind eq KEY ) {
      $self->_select_key( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq ANYSTEP ) {
      $self->_select_anystep( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq NOSTEP ) {
      $self->_select_nostep( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq PARENT ) {
      $self->_select_parent( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq ANCESTOR ) {
      $self->_select_ancestor( $step, $current_points, $new_points );
    }
    elsif ( $step->kind eq ANCESTOR_OR_SELF ) {
      $self->_select_ancestor_or_self( $step, $current_points, $new_points );
    }
    $current_points = $new_points;
  }
  $self->current_points($current_points);
  return $self;
}

sub match {
  my ( $self, $dpath ) = @_;

  $self->_search($dpath)->_all;
}

sub matchr {
  my ( $self, $dpath ) = @_;

  $self->_search($dpath)->_all_ref;
}

1;

__END__

