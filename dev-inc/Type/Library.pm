package Type::Library;

use 5.006001;
use strict;
use warnings;

BEGIN {
  $Type::Library::AUTHORITY = 'cpan:TOBYINK';
  $Type::Library::VERSION   = '1.002001';
}

use Eval::TypeTiny qw< eval_closure >;
use Scalar::Util qw< blessed refaddr >;
use Type::Tiny;
use Types::TypeTiny qw< TypeTiny to_TypeTiny >;

require Exporter::Tiny;
our @ISA = 'Exporter::Tiny';

BEGIN {
  *NICE_PROTOTYPES = ( $] >= 5.014 ) ? sub () { !!1 } : sub () { !!0 }
}

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

{
  my $subname;
  my %already;    # prevent renaming established functions

  sub _subname ($$) {
    $subname =
        eval { require Sub::Util } ? \&Sub::Util::set_subname
      : eval { require Sub::Name } ? \&Sub::Name::subname
      : 0
      if not defined $subname;
    !$already{ refaddr( $_[1] ) }++ and return ( $subname->(@_) )
      if $subname;
    return $_[1];
  }
}

sub _exporter_validate_opts {
  my $class = shift;

  no strict "refs";
  my $into = $_[0]{into};
  push @{"$into\::ISA"}, $class if $_[0]{base};

  return $class->SUPER::_exporter_validate_opts(@_);
}

sub _exporter_expand_tag {
  my $class = shift;
  my ( $name, $value, $globals ) = @_;

  $name eq 'types'     and return map [ "$_"        => $value ], $class->type_names;
  $name eq 'is'        and return map [ "is_$_"     => $value ], $class->type_names;
  $name eq 'assert'    and return map [ "assert_$_" => $value ], $class->type_names;
  $name eq 'to'        and return map [ "to_$_"     => $value ], $class->type_names;
  $name eq 'coercions' and return map [ "$_"        => $value ], $class->coercion_names;

  if ( $name eq 'all' ) {
    no strict "refs";
    return (
      map( [ "+$_" => $value ], $class->type_names, ),
      map( [ $_ => $value ], $class->coercion_names, @{"$class\::EXPORT"}, @{"$class\::EXPORT_OK"}, ),
    );
  }

  return $class->SUPER::_exporter_expand_tag(@_);
}

sub _mksub {
  my $class = shift;
  my ( $type, $post_method ) = @_;
  $post_method ||= q();

  my $source = $type->is_parameterizable
    ? sprintf(
    q{
				sub (%s) {
					return $_[0]->complete($type) if ref($_[0]) eq 'Type::Tiny::_HalfOp';
					my $params; $params = shift if ref($_[0]) eq q(ARRAY);
					my $t = $params ? $type->parameterize(@$params) : $type;
					@_ && wantarray ? return($t%s, @_) : return $t%s;
				}
			},
    NICE_PROTOTYPES ? q(;$) : q(;@),
    $post_method,
    $post_method,
    )
    : sprintf( q{ sub () { $type%s if $] } }, $post_method, );

  return _subname(
    $type->qualified_name,
    eval_closure(
      source      => $source,
      description => sprintf( "exportable function '%s'", $type ),
      environment => { '$type' => \$type },
    ),
  );
}

sub _exporter_permitted_regexp {
  my $class = shift;

  my $inherited = $class->SUPER::_exporter_permitted_regexp(@_);
  my $types     = join "|", map quotemeta, sort { length($b) <=> length($a) or $a cmp $b } $class->type_names;
  my $coercions = join "|", map quotemeta, sort { length($b) <=> length($a) or $a cmp $b } $class->coercion_names;

  qr{^(?:
		$inherited
		| (?: (?:is_|to_|assert_)? (?:$types) )
		| (?:$coercions)
	)$}xms;
}

sub _exporter_expand_sub {
  my $class = shift;
  my ( $name, $value, $globals ) = @_;

  if ( $name =~ /^\+(.+)/ and $class->has_type($1) ) {
    my $type   = $1;
    my $value2 = +{ %{ $value || {} } };

    return map $class->_exporter_expand_sub( $_, $value2, $globals ), $type, "is_$type", "assert_$type", "to_$type";
  }

  if ( my $type = $class->get_type($name) ) {
    my $post_method = q();
    $post_method = '->mouse_type' if $globals->{mouse};
    $post_method = '->moose_type' if $globals->{moose};
    return ( $name => $class->_mksub( $type, $post_method ) ) if $post_method;
  }

  return $class->SUPER::_exporter_expand_sub(@_);
}

sub _exporter_install_sub {
  my $class = shift;
  my ( $name, $value, $globals, $sym ) = @_;

  my $package = $globals->{into};

  if ( !ref $package and my $type = $class->get_type($name) ) {
    my ($prefix) = grep defined, $value->{-prefix}, $globals->{prefix}, q();
    my ($suffix) = grep defined, $value->{-suffix}, $globals->{suffix}, q();
    my $as = $prefix . ( $value->{-as} || $name ) . $suffix;

    $INC{'Type/Registry.pm'}
      ? 'Type::Registry'->for_class($package)->add_type( $type, $as )
      : ( $Type::Registry::DELAYED{$package}{$as} = $type );
  }

  $class->SUPER::_exporter_install_sub(@_);
}

sub _exporter_fail {
  my $class = shift;
  my ( $name, $value, $globals ) = @_;

  my $into = $globals->{into}
    or _croak("Parameter 'into' not supplied");

  if ( $globals->{declare} ) {
    my $declared = sub (;$) {
      my $params;
      $params = shift if ref( $_[0] ) eq "ARRAY";
      my $type = $into->get_type($name);
      unless ($type) {
        _croak "Cannot parameterize a non-existant type" if $params;
        $type = $name;
      }

      my $t = $params ? $type->parameterize(@$params) : $type;
      @_ && wantarray ? return ( $t, @_ ) : return $t;
    };

    return ( $name, _subname( "$class\::$name", NICE_PROTOTYPES ? sub (;$) { goto $declared } : sub (;@) { goto $declared }, ), );
  }

  return $class->SUPER::_exporter_fail(@_);
}

sub meta {
  no strict "refs";
  no warnings "once";
  return $_[0] if blessed $_[0];
  ${"$_[0]\::META"} ||= bless {}, $_[0];
}

sub add_type {
  my $meta  = shift->meta;
  my $class = blessed($meta);

  my $type =
      ref( $_[0] ) =~ /^Type::Tiny\b/ ? $_[0]
    : blessed( $_[0] )                ? to_TypeTiny( $_[0] )
    : ref( $_[0] ) eq q(HASH)         ? "Type::Tiny"->new( library => $class, %{ $_[0] } )
    :                                   "Type::Tiny"->new( library => $class, @_ );
  my $name = $type->{name};

  $meta->{types} ||= {};
  _croak 'Type %s already exists in this library',       $name if $meta->has_type($name);
  _croak 'Type %s conflicts with coercion of same name', $name if $meta->has_coercion($name);
  _croak 'Cannot add anonymous type to a library' if $type->is_anon;
  $meta->{types}{$name} = $type;

  no strict "refs";
  no warnings "redefine", "prototype";

  my $to_type =
      $type->has_coercion && $type->coercion->frozen
    ? $type->coercion->compiled_coercion
    : sub ($) { $type->coerce( $_[0] ) };

  *{"$class\::$name"}        = $class->_mksub($type);
  *{"$class\::is_$name"}     = _subname "$class\::is_$name", $type->compiled_check;
  *{"$class\::to_$name"}     = _subname "$class\::to_$name", $to_type;
  *{"$class\::assert_$name"} = _subname "$class\::assert_$name", $type->_overload_coderef;

  return $type;
}

sub get_type {
  my $meta = shift->meta;
  $meta->{types}{ $_[0] };
}

sub has_type {
  my $meta = shift->meta;
  exists $meta->{types}{ $_[0] };
}

sub type_names {
  my $meta = shift->meta;
  keys %{ $meta->{types} };
}

sub add_coercion {
  require Type::Coercion;
  my $meta = shift->meta;
  my $c    = blessed( $_[0] ) ? $_[0] : "Type::Coercion"->new(@_);
  my $name = $c->name;

  $meta->{coercions} ||= {};
  _croak 'Coercion %s already exists in this library',   $name if $meta->has_coercion($name);
  _croak 'Coercion %s conflicts with type of same name', $name if $meta->has_type($name);
  _croak 'Cannot add anonymous type to a library' if $c->is_anon;
  $meta->{coercions}{$name} = $c;

  no strict "refs";
  no warnings "redefine", "prototype";

  my $class = blessed($meta);
  *{"$class\::$name"} = $class->_mksub($c);

  return $c;
}

sub get_coercion {
  my $meta = shift->meta;
  $meta->{coercions}{ $_[0] };
}

sub has_coercion {
  my $meta = shift->meta;
  exists $meta->{coercions}{ $_[0] };
}

sub coercion_names {
  my $meta = shift->meta;
  keys %{ $meta->{coercions} };
}

sub make_immutable {
  my $meta  = shift->meta;
  my $class = ref($meta);

  for my $type ( values %{ $meta->{types} } ) {
    $type->coercion->freeze;

    no strict "refs";
    no warnings "redefine", "prototype";

    my $to_type =
        $type->has_coercion && $type->coercion->frozen
      ? $type->coercion->compiled_coercion
      : sub ($) { $type->coerce( $_[0] ) };
    my $name = $type->name;

    *{"$class\::to_$name"} = _subname "$class\::to_$name", $to_type;
  }

  1;
}

1;

__END__

