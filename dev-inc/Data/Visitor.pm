package Data::Visitor;

BEGIN {
  $Data::Visitor::AUTHORITY = 'cpan:NUFFIN';
}
{
  $Data::Visitor::VERSION = '0.30';
}
use Moose;

# ABSTRACT: Visitor style traversal of Perl data structures

use Scalar::Util qw/blessed refaddr reftype weaken isweak/;
use overload ();
use Symbol   ();

use Class::Load 'load_optional_class';
use Tie::ToObject;

no warnings 'recursion';

use namespace::clean -except => 'meta';

# the double not makes this no longer undef, so exempt from useless constant warnings in older perls
use constant DEBUG => not not our $DEBUG || $ENV{DATA_VISITOR_DEBUG};

use constant HAS_DATA_ALIAS => load_optional_class('Data::Alias');

has tied_as_objects => (
  isa => "Bool",
  is  => "rw",
);

# currently broken
has weaken => (
  isa     => "Bool",
  is      => "rw",
  default => 0,
);

sub trace {
  my ( $self, $category, @msg ) = @_;

  our %DEBUG;

  if ( $DEBUG{$category} or !exists( $DEBUG{$category} ) ) {
    $self->_print_trace( "$self: "
        . join( "", ( "    " x ( $self->{depth} - 1 ) ), ( join( " ", "$category:", map { overload::StrVal($_) } @msg ) ), ) );
  }
}

sub _print_trace {
  my ( $self, @msg ) = @_;
  warn "@msg\n";
}

sub visit {
  my $self = shift;

  local $self->{depth} = ( ( $self->{depth} || 0 ) + 1 ) if DEBUG;
  my $seen_hash = local $self->{_seen} = ( $self->{_seen} || {} );    # delete it after we're done with the whole visit

  my @ret;

  foreach my $data (@_) {
    $self->trace( flow => visit => $data ) if DEBUG;

    if ( my $refaddr = ref($data) && refaddr($data) ) {               # only references need recursion checks
      $seen_hash->{weak} ||= isweak($data) if $self->weaken;

      if ( exists $seen_hash->{$refaddr} ) {
        $self->trace( mapping => found_mapping => from => $data, to => $seen_hash->{$refaddr} ) if DEBUG;
        push @ret, $self->visit_seen( $data, $seen_hash->{$refaddr} );
        next;
      }
      else {
        $self->trace( mapping => no_mapping => $data ) if DEBUG;
      }
    }

    if ( defined wantarray ) {
      push @ret, scalar( $self->visit_no_rec_check($data) );
    }
    else {
      $self->visit_no_rec_check($data);
    }
  }

  return ( @_ == 1 ? $ret[0] : @ret );
}

sub visit_seen {
  my ( $self, $data, $result ) = @_;
  return $result;
}

sub _get_mapping {
  my ( $self, $data ) = @_;
  $self->{_seen}{ refaddr($data) };
}

sub _register_mapping {
  my ( $self, $data, $new_data ) = @_;
  return $new_data unless ref $data;
  $self->trace( mapping => register_mapping => from => $data, to => $new_data, in => ( caller(1) )[3] ) if DEBUG;
  $self->{_seen}{ refaddr($data) } = $new_data;
}

sub visit_no_rec_check {
  my ( $self, $data ) = @_;

  if ( blessed($data) ) {
    return $self->visit_object( $_[1] );
  }
  elsif ( ref $data ) {
    return $self->visit_ref( $_[1] );
  }

  return $self->visit_value( $_[1] );
}

sub visit_object {
  my ( $self, $object ) = @_;
  $self->trace( flow => visit_object => $object ) if DEBUG;

  if ( not defined wantarray ) {
    $self->_register_mapping( $object, $object );
    $self->visit_value( $_[1] );
    return;
  }
  else {
    return $self->_register_mapping( $object, $self->visit_value( $_[1] ) );
  }
}

sub visit_ref {
  my ( $self, $data ) = @_;

  local $self->{depth} = ( ( $self->{depth} || 0 ) + 1 ) if DEBUG;

  $self->trace( flow => visit_ref => $data ) if DEBUG;

  my $reftype = reftype $data;

  $reftype = "SCALAR" if $reftype =~ /^(?:REF|LVALUE|VSTRING)$/;

  my $method = $self->can( lc "visit_$reftype" ) || "visit_value";

  return $self->$method( $_[1] );
}

sub visit_value {
  my ( $self, $value ) = @_;
  $self->trace( flow => visit_value => $value ) if DEBUG;
  return $value;
}

sub visit_hash {
  my ( $self, $hash ) = @_;

  local $self->{depth} = ( ( $self->{depth} || 0 ) + 1 ) if DEBUG;

  if ( defined( tied(%$hash) ) and $self->tied_as_objects ) {
    return $self->visit_tied_hash( tied(%$hash), $_[1] );
  }
  else {
    return $self->visit_normal_hash( $_[1] );
  }
}

sub visit_normal_hash {
  my ( $self, $hash ) = @_;

  if ( defined wantarray ) {
    my $new_hash = {};
    $self->_register_mapping( $hash, $new_hash );

    %$new_hash = $self->visit_hash_entries( $_[1] );

    return $self->retain_magic( $_[1], $new_hash );
  }
  else {
    $self->_register_mapping( $hash, $hash );
    $self->visit_hash_entries( $_[1] );
    return;
  }
}

sub visit_tied_hash {
  my ( $self, $tied, $hash ) = @_;

  if ( defined wantarray ) {
    my $new_hash = {};
    $self->_register_mapping( $hash, $new_hash );

    if ( blessed( my $new_tied = $self->visit_tied( $_[1], $_[2] ) ) ) {
      $self->trace( data => tying => var => $new_hash, to => $new_tied ) if DEBUG;
      tie %$new_hash, 'Tie::ToObject', $new_tied;
      return $self->retain_magic( $_[2], $new_hash );
    }
    else {
      return $self->visit_normal_hash( $_[2] );
    }
  }
  else {
    $self->_register_mapping( $hash, $hash );
    $self->visit_tied( $_[1], $_[2] );
    return;
  }
}

sub visit_hash_entries {
  my ( $self, $hash ) = @_;

  if ( not defined wantarray ) {
    $self->visit_hash_entry( $_, $hash->{$_}, $hash ) for keys %$hash;
  }
  else {
    return map { $self->visit_hash_entry( $_, $hash->{$_}, $hash ) } keys %$hash;
  }
}

sub visit_hash_entry {
  my ( $self, $key, $value, $hash ) = @_;

  $self->trace( flow => visit_hash_entry => key => $key, value => $value ) if DEBUG;

  if ( not defined wantarray ) {
    $self->visit_hash_key( $key, $value, $hash );
    $self->visit_hash_value( $_[2], $key, $hash );
  }
  else {
    return ( $self->visit_hash_key( $key, $value, $hash ), $self->visit_hash_value( $_[2], $key, $hash ), );
  }
}

sub visit_hash_key {
  my ( $self, $key, $value, $hash ) = @_;
  $self->visit($key);
}

sub visit_hash_value {
  my ( $self, $value, $key, $hash ) = @_;
  $self->visit( $_[1] );
}

sub visit_array {
  my ( $self, $array ) = @_;

  if ( defined( tied(@$array) ) and $self->tied_as_objects ) {
    return $self->visit_tied_array( tied(@$array), $_[1] );
  }
  else {
    return $self->visit_normal_array( $_[1] );
  }
}

sub visit_normal_array {
  my ( $self, $array ) = @_;

  if ( defined wantarray ) {
    my $new_array = [];
    $self->_register_mapping( $array, $new_array );

    @$new_array = $self->visit_array_entries( $_[1] );

    return $self->retain_magic( $_[1], $new_array );
  }
  else {
    $self->_register_mapping( $array, $array );
    $self->visit_array_entries( $_[1] );

    return;
  }
}

sub visit_tied_array {
  my ( $self, $tied, $array ) = @_;

  if ( defined wantarray ) {
    my $new_array = [];
    $self->_register_mapping( $array, $new_array );

    if ( blessed( my $new_tied = $self->visit_tied( $_[1], $_[2] ) ) ) {
      $self->trace( data => tying => var => $new_array, to => $new_tied ) if DEBUG;
      tie @$new_array, 'Tie::ToObject', $new_tied;
      return $self->retain_magic( $_[2], $new_array );
    }
    else {
      return $self->visit_normal_array( $_[2] );
    }
  }
  else {
    $self->_register_mapping( $array, $array );
    $self->visit_tied( $_[1], $_[2] );

    return;
  }
}

sub visit_array_entries {
  my ( $self, $array ) = @_;

  if ( not defined wantarray ) {
    $self->visit_array_entry( $array->[$_], $_, $array ) for 0 .. $#$array;
  }
  else {
    return map { $self->visit_array_entry( $array->[$_], $_, $array ) } 0 .. $#$array;
  }
}

sub visit_array_entry {
  my ( $self, $value, $index, $array ) = @_;
  $self->visit( $_[1] );
}

sub visit_scalar {
  my ( $self, $scalar ) = @_;

  if ( defined( tied($$scalar) ) and $self->tied_as_objects ) {
    return $self->visit_tied_scalar( tied($$scalar), $_[1] );
  }
  else {
    return $self->visit_normal_scalar( $_[1] );
  }
}

sub visit_normal_scalar {
  my ( $self, $scalar ) = @_;

  if ( defined wantarray ) {
    my $new_scalar;
    $self->_register_mapping( $scalar, \$new_scalar );

    $new_scalar = $self->visit($$scalar);

    return $self->retain_magic( $_[1], \$new_scalar );
  }
  else {
    $self->_register_mapping( $scalar, $scalar );
    $self->visit($$scalar);
    return;
  }

}

sub visit_tied_scalar {
  my ( $self, $tied, $scalar ) = @_;

  if ( defined wantarray ) {
    my $new_scalar;
    $self->_register_mapping( $scalar, \$new_scalar );

    if ( blessed( my $new_tied = $self->visit_tied( $_[1], $_[2] ) ) ) {
      $self->trace( data => tying => var => $new_scalar, to => $new_tied ) if DEBUG;
      tie $new_scalar, 'Tie::ToObject', $new_tied;
      return $self->retain_magic( $_[2], \$new_scalar );
    }
    else {
      return $self->visit_normal_scalar( $_[2] );
    }
  }
  else {
    $self->_register_mapping( $scalar, $scalar );
    $self->visit_tied( $_[1], $_[2] );
    return;
  }
}

sub visit_code {
  my ( $self, $code ) = @_;
  $self->visit_value( $_[1] );
}

sub visit_glob {
  my ( $self, $glob ) = @_;

  if ( defined( tied(*$glob) ) and $self->tied_as_objects ) {
    return $self->visit_tied_glob( tied(*$glob), $_[1] );
  }
  else {
    return $self->visit_normal_glob( $_[1] );
  }
}

sub visit_normal_glob {
  my ( $self, $glob ) = @_;

  if ( defined wantarray ) {
    my $new_glob = Symbol::gensym();
    $self->_register_mapping( $glob, $new_glob );

    no warnings 'misc';    # Undefined value assigned to typeglob
    *$new_glob = $self->visit( *$glob{$_} || next ) for qw/SCALAR ARRAY HASH/;

    return $self->retain_magic( $_[1], $new_glob );
  }
  else {
    $self->_register_mapping( $glob, $glob );
    $self->visit( *$glob{$_} || next ) for qw/SCALAR ARRAY HASH/;
    return;
  }
}

sub visit_tied_glob {
  my ( $self, $tied, $glob ) = @_;

  if ( defined wantarray ) {
    my $new_glob = Symbol::gensym();
    $self->_register_mapping( $glob, \$new_glob );

    if ( blessed( my $new_tied = $self->visit_tied( $_[1], $_[2] ) ) ) {
      $self->trace( data => tying => var => $new_glob, to => $new_tied ) if DEBUG;
      tie *$new_glob, 'Tie::ToObject', $new_tied;
      return $self->retain_magic( $_[2], $new_glob );
    }
    else {
      return $self->visit_normal_glob( $_[2] );
    }
  }
  else {
    $self->_register_mapping( $glob, $glob );
    $self->visit_tied( $_[1], $_[2] );
    return;
  }
}

sub retain_magic {
  my ( $self, $proto, $new ) = @_;

  if ( blessed($proto) and !blessed($new) ) {
    $self->trace( data => blessing => $new, ref $proto ) if DEBUG;
    bless $new, ref $proto;
  }

  my $seen_hash = $self->{_seen};
  if ( $seen_hash->{weak} ) {
    if (HAS_DATA_ALIAS) {
      my @weak_refs;
      foreach my $value ( Data::Alias::deref($proto) ) {
        if ( ref $value and isweak($value) ) {
          push @weak_refs, refaddr $value;
        }
      }

      if (@weak_refs) {
        my %targets = map { refaddr($_) => 1 } @{ $self->{_seen} }{@weak_refs};
        foreach my $value ( Data::Alias::deref($new) ) {
          if ( ref $value and $targets{ refaddr($value) } ) {
            push @{ $seen_hash->{weakened} ||= [] }, $value;    # keep a ref around
            weaken($value);
          }
        }
      }
    }
    else {
      die "Found a weak reference, but Data::Alias is not installed. You must install Data::Alias in order for this to work.";
    }
  }

  # FIXME real magic, too

  return $new;
}

sub visit_tied {
  my ( $self, $tied, $var ) = @_;
  $self->trace( flow => visit_tied => $tied ) if DEBUG;
  $self->visit( $_[1] );    # as an object eventually
}

__PACKAGE__->meta->make_immutable if __PACKAGE__->meta->can("make_immutable");

__PACKAGE__;

__END__

