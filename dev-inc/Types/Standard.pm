package Types::Standard;

use 5.006001;
use strict;
use warnings;

BEGIN {
  eval { require re };
  if ( $] < 5.008 ) { require Devel::TypeTiny::Perl56Compat }
  if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
  $Types::Standard::AUTHORITY = 'cpan:TOBYINK';
  $Types::Standard::VERSION   = '1.002001';
}

use Type::Library -base;

our @EXPORT_OK = qw( slurpy );

use Scalar::Util qw( blessed looks_like_number );
use Type::Tiny      ();
use Types::TypeTiny ();

BEGIN {
  *_is_class_loaded =
    Type::Tiny::_USE_XS
    ? \&Type::Tiny::XS::Util::is_class_loaded
    : sub {
    return !!0 if ref $_[0];
    return !!0 if not $_[0];
    my $stash = do { no strict 'refs'; \%{"$_[0]\::"} };
    return !!1 if exists $stash->{'ISA'};
    return !!1 if exists $stash->{'VERSION'};
    foreach my $globref ( values %$stash ) {
      return !!1 if *{$globref}{CODE};
    }
    return !!0;
    };
}

my $HAS_RUXS = eval {
  require Ref::Util::XS;
  Ref::Util::XS::->VERSION(0.100);
  1;
};

my $add_core_type = sub {
  my $meta = shift;
  my ($typedef) = @_;

  my $name = $typedef->{name};
  my ( $xsub, $xsubname );

  # We want Map and Tuple to be XSified, even if they're not
  # really core.
  $typedef->{_is_core} = 1
    unless $name eq 'Map' || $name eq 'Tuple';

  if ( Type::Tiny::_USE_XS
    and not( $name eq 'RegexpRef' ) )
  {
    $xsub     = Type::Tiny::XS::get_coderef_for($name);
    $xsubname = Type::Tiny::XS::get_subname_for($name);
  }

  elsif ( Type::Tiny::_USE_MOUSE
    and not( $name eq 'RegexpRef' or $name eq 'Int' or $name eq 'Object' ) )
  {
    require Mouse::Util::TypeConstraints;
    $xsub     = "Mouse::Util::TypeConstraints"->can($name);
    $xsubname = "Mouse::Util::TypeConstraints::$name" if $xsub;
  }

  $typedef->{compiled_type_constraint} = $xsub if $xsub;

  $typedef->{inlined} = sub { "$xsubname\($_[1])" }
    if defined($xsubname) and (

    # These should be faster than their normal inlined
    # equivalents
    $name eq 'Str' or $name eq 'Bool' or $name eq 'ClassName' or $name eq 'RegexpRef' or $name eq 'FileHandle'
    );

  $meta->add_type($typedef);
};

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $meta = __PACKAGE__->meta;

# Stringable and LazyLoad are optimizations that complicate
# this module somewhat, but they have led to performance
# improvements. If Types::Standard wasn't such a key type
# library, I wouldn't use them. I strongly discourage anybody
# from using them in their own code. If you're looking for
# examples of how to write a type library sanely, you're
# better off looking at the code for Types::Common::Numeric
# and Types::Common::String.

sub Stringable (&) {
  package    #private
    Types::Standard::_Stringable;
  use overload q[""] => sub { $_[0]{text} ||= $_[0]{code}->() }, fallback => 1;
  bless +{ code => $_[0] };
}

sub LazyLoad ($$) {
  package    #private
    Types::Standard::LazyLoad;
  use overload
    fallback => 1,
    q[&{}]   => sub {
    my ( $typename, $function ) = @{ $_[0] };
    my $type  = $meta->get_type($typename);
    my $class = "Types::Standard::$typename";
    eval "require $class; 1" or die($@);

    # Majorly break encapsulation for Type::Tiny :-O
    for my $key ( keys %$type ) {
      next unless ref( $type->{$key} ) eq __PACKAGE__;
      my $f = $type->{$key}[1];
      $type->{$key} = $class->can("__$f");
    }
    return $class->can("__$function");
    };
  bless \@_;
}

no warnings;

BEGIN {
  *STRICTNUM = $ENV{PERL_TYPES_STANDARD_STRICTNUM} ? sub() { !!1 } : sub() { !!0 }
}

my $_any = $meta->$add_core_type(
  {
    name    => "Any",
    inlined => sub { "!!1" },
  }
);

my $_item = $meta->$add_core_type(
  {
    name    => "Item",
    inlined => sub { "!!1" },
    parent  => $_any,
  }
);

$meta->$add_core_type(
  {
    name       => "Bool",
    parent     => $_item,
    constraint => sub { !defined $_ or $_ eq q() or $_ eq '0' or $_ eq '1' },
    inlined    => sub { "!defined $_[1] or $_[1] eq q() or $_[1] eq '0' or $_[1] eq '1'" },
  }
);

my $_undef = $meta->$add_core_type(
  {
    name       => "Undef",
    parent     => $_item,
    constraint => sub { !defined $_ },
    inlined    => sub { "!defined($_[1])" },
  }
);

my $_def = $meta->$add_core_type(
  {
    name       => "Defined",
    parent     => $_item,
    constraint => sub { defined $_ },
    inlined    => sub { "defined($_[1])" },
  }
);

my $_val = $meta->$add_core_type(
  {
    name       => "Value",
    parent     => $_def,
    constraint => sub { not ref $_ },
    inlined    => sub { "defined($_[1]) and not ref($_[1])" },
  }
);

my $_str = $meta->$add_core_type(
  {
    name       => "Str",
    parent     => $_val,
    constraint => sub { ref( \$_ ) eq 'SCALAR' or ref( \( my $val = $_ ) ) eq 'SCALAR' },
    inlined    => sub {
      "defined($_[1]) and do { ref(\\$_[1]) eq 'SCALAR' or ref(\\(my \$val = $_[1])) eq 'SCALAR' }";
    },
  }
);

my $_laxnum = $meta->add_type(
  {
    name       => "LaxNum",
    parent     => $_str,
    constraint => sub { looks_like_number $_ },
    inlined    => sub { "defined($_[1]) && !ref($_[1]) && Scalar::Util::looks_like_number($_[1])" },
  }
);

my $_strictnum = $meta->add_type(
  {
    name       => "StrictNum",
    parent     => $_str,
    constraint => sub {
      my $val = $_;
      ( $val =~ /\A[+-]?[0-9]+\z/ )
        || (
        $val =~ /\A(?:[+-]?)                #matches optional +- in the beginning
		(?=[0-9]|\.[0-9])                     #matches previous +- only if there is something like 3 or .3
		[0-9]*                                #matches 0-9 zero or more times
		(?:\.[0-9]+)?                         #matches optional .89 or nothing
		(?:[Ee](?:[+-]?[0-9]+))?              #matches E1 or e1 or e-1 or e+1 etc
		\z/x
        );
    },
    inlined => sub {
      'my $val = '
        . $_[1] . ';'
        . Value()->inline_check('$val')
        . ' && ( $val =~ /\A[+-]?[0-9]+\z/ || '
        . '$val =~ /\A(?:[+-]?)              # matches optional +- in the beginning
			(?=[0-9]|\.[0-9])                 # matches previous +- only if there is something like 3 or .3
			[0-9]*                            # matches 0-9 zero or more times
			(?:\.[0-9]+)?                     # matches optional .89 or nothing
			(?:[Ee](?:[+-]?[0-9]+))?          # matches E1 or e1 or e-1 or e+1 etc
		\z/x ); '
    },
  }
);

my $_num = $meta->add_type(
  {
    name   => "Num",
    parent => ( STRICTNUM ? $_strictnum : $_laxnum ),
  }
);

$meta->$add_core_type(
  {
    name       => "Int",
    parent     => $_num,
    constraint => sub { /\A-?[0-9]+\z/ },
    inlined    => sub { "defined($_[1]) and !ref($_[1]) and $_[1] =~ /\\A-?[0-9]+\\z/" },
  }
);

my $_classn = $meta->add_type(
  {
    name       => "ClassName",
    parent     => $_str,
    constraint => \&_is_class_loaded,
    inlined    => sub { "Types::Standard::_is_class_loaded(do { my \$tmp = $_[1] })" },
  }
);

$meta->add_type(
  {
    name       => "RoleName",
    parent     => $_classn,
    constraint => sub { not $_->can("new") },
    inlined    => sub { "Types::Standard::_is_class_loaded(do { my \$tmp = $_[1] }) and not $_[1]\->can('new')" },
  }
);

my $_ref = $meta->$add_core_type(
  {
    name                 => "Ref",
    parent               => $_def,
    constraint           => sub { ref $_ },
    inlined              => sub { "!!ref($_[1])" },
    constraint_generator => sub {
      return $meta->get_type('Ref') unless @_;

      my $reftype = shift;
      Types::TypeTiny::StringLike->check($reftype)
        or _croak("Parameter to Ref[`a] expected to be string; got $reftype");

      $reftype = "$reftype";
      return sub {
        ref( $_[0] ) and Scalar::Util::reftype( $_[0] ) eq $reftype;
      }
    },
    inline_generator => sub {
      my $reftype = shift;
      return sub {
        my $v = $_[1];
        "ref($v) and Scalar::Util::reftype($v) eq q($reftype)";
      };
    },
    deep_explanation => sub {
      require B;
      my ( $type, $value, $varname ) = @_;
      my $param = $type->parameters->[0];
      return if $type->check($value);
      my $reftype = Scalar::Util::reftype($value);
      return [
        sprintf( '"%s" constrains reftype(%s) to be equal to %s', $type, $varname, B::perlstring($param) ),
        sprintf( 'reftype(%s) is %s', $varname, defined($reftype) ? B::perlstring($reftype) : "undef" ),
      ];
    },
  }
);

$meta->$add_core_type(
  {
    name       => "CodeRef",
    parent     => $_ref,
    constraint => sub { ref $_ eq "CODE" },
    inlined    => $HAS_RUXS
    ? sub { "Ref::Util::XS::is_plain_coderef($_[1])" }
    : sub { "ref($_[1]) eq 'CODE'" },
  }
);

my $_regexp = $meta->$add_core_type(
  {
    name       => "RegexpRef",
    parent     => $_ref,
    constraint => sub { ref($_) && !!re::is_regexp($_) or blessed($_) && $_->isa('Regexp') },
    inlined    => sub { my $v = $_[1]; "ref($v) && !!re::is_regexp($v) or Scalar::Util::blessed($v) && $v\->isa('Regexp')" },
  }
);

$meta->$add_core_type(
  {
    name       => "GlobRef",
    parent     => $_ref,
    constraint => sub { ref $_ eq "GLOB" },
    inlined    => $HAS_RUXS
    ? sub { "Ref::Util::XS::is_plain_globref($_[1])" }
    : sub { "ref($_[1]) eq 'GLOB'" },
  }
);

$meta->$add_core_type(
  {
    name       => "FileHandle",
    parent     => $_ref,
    constraint => sub {
      ( ref($_) eq "GLOB" && Scalar::Util::openhandle($_) )
        or ( blessed($_)  && $_->isa("IO::Handle") );
    },
    inlined => sub {
      "(ref($_[1]) eq \"GLOB\" && Scalar::Util::openhandle($_[1])) "
        . "or (Scalar::Util::blessed($_[1]) && $_[1]\->isa(\"IO::Handle\"))";
    },
  }
);

my $_arr = $meta->$add_core_type(
  {
    name       => "ArrayRef",
    parent     => $_ref,
    constraint => sub { ref $_ eq "ARRAY" },
    inlined    => $HAS_RUXS
    ? sub { "Ref::Util::XS::is_plain_arrayref($_[1])" }
    : sub { "ref($_[1]) eq 'ARRAY'" },
    constraint_generator => LazyLoad( ArrayRef => 'constraint_generator' ),
    inline_generator     => LazyLoad( ArrayRef => 'inline_generator' ),
    deep_explanation     => LazyLoad( ArrayRef => 'deep_explanation' ),
    coercion_generator   => LazyLoad( ArrayRef => 'coercion_generator' ),
  }
);

my $_hash = $meta->$add_core_type(
  {
    name       => "HashRef",
    parent     => $_ref,
    constraint => sub { ref $_ eq "HASH" },
    inlined    => $HAS_RUXS
    ? sub { "Ref::Util::XS::is_plain_hashref($_[1])" }
    : sub { "ref($_[1]) eq 'HASH'" },
    constraint_generator => LazyLoad( HashRef => 'constraint_generator' ),
    inline_generator     => LazyLoad( HashRef => 'inline_generator' ),
    deep_explanation     => LazyLoad( HashRef => 'deep_explanation' ),
    coercion_generator   => LazyLoad( HashRef => 'coercion_generator' ),
    my_methods           => {
      hashref_allows_key => sub {
        my $self = shift;
        Str()->check( $_[0] );
      },
      hashref_allows_value => sub {
        my $self = shift;
        my ( $key, $value ) = @_;

        return !!0 unless $self->my_hashref_allows_key($key);
        return !!1 if $self == HashRef();

        my $href  = $self->find_parent( sub { $_->has_parent && $_->parent == HashRef() } );
        my $param = $href->type_parameter;

        Str()->check($key) and $param->check($value);
      },
    },
  }
);

$meta->$add_core_type(
  {
    name                 => "ScalarRef",
    parent               => $_ref,
    constraint           => sub { ref $_ eq "SCALAR" or ref $_ eq "REF" },
    inlined              => sub { "ref($_[1]) eq 'SCALAR' or ref($_[1]) eq 'REF'" },
    constraint_generator => LazyLoad( ScalarRef => 'constraint_generator' ),
    inline_generator     => LazyLoad( ScalarRef => 'inline_generator' ),
    deep_explanation     => LazyLoad( ScalarRef => 'deep_explanation' ),
    coercion_generator   => LazyLoad( ScalarRef => 'coercion_generator' ),
  }
);

my $_obj = $meta->$add_core_type(
  {
    name       => "Object",
    parent     => $_ref,
    constraint => sub { blessed $_ },
    inlined    => $HAS_RUXS
    ? sub { "Ref::Util::XS::is_blessed_ref($_[1])" }
    : sub { "Scalar::Util::blessed($_[1])" },
  }
);

$meta->$add_core_type(
  {
    name                 => "Maybe",
    parent               => $_item,
    constraint_generator => sub {
      return $meta->get_type('Maybe') unless @_;

      my $param = Types::TypeTiny::to_TypeTiny(shift);
      Types::TypeTiny::TypeTiny->check($param)
        or _croak("Parameter to Maybe[`a] expected to be a type constraint; got $param");

      my $param_compiled_check = $param->compiled_check;
      my @xsub;
      if (Type::Tiny::_USE_XS) {
        my $paramname = Type::Tiny::XS::is_known($param_compiled_check);
        push @xsub, Type::Tiny::XS::get_coderef_for("Maybe[$paramname]")
          if $paramname;
      }
      elsif ( Type::Tiny::_USE_MOUSE and $param->_has_xsub ) {
        require Mouse::Util::TypeConstraints;
        my $maker = "Mouse::Util::TypeConstraints"->can("_parameterize_Maybe_for");
        push @xsub, $maker->($param) if $maker;
      }

      return (
        sub {
          my $value = shift;
          return !!1 unless defined $value;
          return $param->check($value);
        },
        @xsub,
      );
    },
    inline_generator => sub {
      my $param = shift;

      my $param_compiled_check = $param->compiled_check;
      if (Type::Tiny::_USE_XS) {
        my $paramname = Type::Tiny::XS::is_known($param_compiled_check);
        my $xsubname  = Type::Tiny::XS::get_subname_for("Maybe[$paramname]");
        return sub { "$xsubname\($_[1]\)" }
          if $xsubname;
      }

      return unless $param->can_be_inlined;
      return sub {
        my $v           = $_[1];
        my $param_check = $param->inline_check($v);
        "!defined($v) or $param_check";
      };
    },
    deep_explanation => sub {
      my ( $type, $value, $varname ) = @_;
      my $param = $type->parameters->[0];

      return [
        sprintf( '%s is defined', Type::Tiny::_dd($value) ),
        sprintf( '"%s" constrains the value with "%s" if it is defined', $type, $param ),
        @{ $param->validate_explain( $value, $varname ) },
      ];
    },
    coercion_generator => sub {
      my ( $parent, $child, $param ) = @_;
      return unless $param->has_coercion;
      return $param->coercion;
    },
  }
);

my $_map = $meta->$add_core_type(
  {
    name                 => "Map",
    parent               => $_hash,
    constraint_generator => LazyLoad( Map => 'constraint_generator' ),
    inline_generator     => LazyLoad( Map => 'inline_generator' ),
    deep_explanation     => LazyLoad( Map => 'deep_explanation' ),
    coercion_generator   => LazyLoad( Map => 'coercion_generator' ),
    my_methods           => {
      hashref_allows_key => sub {
        my $self = shift;
        my ($key) = @_;

        return Str()->check($key) if $self == Map();

        my $map = $self->find_parent( sub { $_->has_parent && $_->parent == Map() } );
        my ( $kcheck, $vcheck ) = @{ $map->parameters };

        ( $kcheck or Any() )->check($key);
      },
      hashref_allows_value => sub {
        my $self = shift;
        my ( $key, $value ) = @_;

        return !!0 unless $self->my_hashref_allows_key($key);
        return !!1 if $self == Map();

        my $map = $self->find_parent( sub { $_->has_parent && $_->parent == Map() } );
        my ( $kcheck, $vcheck ) = @{ $map->parameters };

        ( $kcheck or Any() )->check($key)
          and ( $vcheck or Any() )->check($value);
      },
    },
  }
);

my $_Optional = $meta->add_type(
  {
    name                 => "Optional",
    parent               => $_item,
    constraint_generator => sub {
      return $meta->get_type('Optional') unless @_;

      my $param = Types::TypeTiny::to_TypeTiny(shift);
      Types::TypeTiny::TypeTiny->check($param)
        or _croak("Parameter to Optional[`a] expected to be a type constraint; got $param");

      sub { $param->check( $_[0] ) }
    },
    inline_generator => sub {
      my $param = shift;
      return unless $param->can_be_inlined;
      return sub {
        my $v = $_[1];
        $param->inline_check($v);
      };
    },
    deep_explanation => sub {
      my ( $type, $value, $varname ) = @_;
      my $param = $type->parameters->[0];

      return [
        sprintf( '%s exists', $varname ),
        sprintf( '"%s" constrains %s with "%s" if it exists', $type, $varname, $param ),
        @{ $param->validate_explain( $value, $varname ) },
      ];
    },
    coercion_generator => sub {
      my ( $parent, $child, $param ) = @_;
      return unless $param->has_coercion;
      return $param->coercion;
    },
  }
);

sub slurpy {
  my $t = shift;
  wantarray ? ( +{ slurpy => $t }, @_ ) : +{ slurpy => $t };
}

$meta->$add_core_type(
  {
    name           => "Tuple",
    parent         => $_arr,
    name_generator => sub {
      my ( $s, @a ) = @_;
      sprintf( '%s[%s]', $s, join q[,], map { ref($_) eq "HASH" ? sprintf( "slurpy %s", $_->{slurpy} ) : $_ } @a );
    },
    constraint_generator => LazyLoad( Tuple => 'constraint_generator' ),
    inline_generator     => LazyLoad( Tuple => 'inline_generator' ),
    deep_explanation     => LazyLoad( Tuple => 'deep_explanation' ),
    coercion_generator   => LazyLoad( Tuple => 'coercion_generator' ),
  }
);

$meta->add_type(
  {
    name           => "CycleTuple",
    parent         => $_arr,
    name_generator => sub {
      my ( $s, @a ) = @_;
      sprintf( '%s[%s]', $s, join q[,], @a );
    },
    constraint_generator => LazyLoad( CycleTuple => 'constraint_generator' ),
    inline_generator     => LazyLoad( CycleTuple => 'inline_generator' ),
    deep_explanation     => LazyLoad( CycleTuple => 'deep_explanation' ),
    coercion_generator   => LazyLoad( CycleTuple => 'coercion_generator' ),
  }
);

$meta->add_type(
  {
    name           => "Dict",
    parent         => $_hash,
    name_generator => sub {
      my ( $s, @p ) = @_;
      my $l = ref( $p[-1] ) eq q(HASH) ? pop(@p)->{slurpy} : undef;
      my %a = @p;
      sprintf( '%s[%s%s]', $s, join( q[,], map sprintf( "%s=>%s", $_, $a{$_} ), sort keys %a ), $l ? ",slurpy $l" : '' );
    },
    constraint_generator => LazyLoad( Dict => 'constraint_generator' ),
    inline_generator     => LazyLoad( Dict => 'inline_generator' ),
    deep_explanation     => LazyLoad( Dict => 'deep_explanation' ),
    coercion_generator   => LazyLoad( Dict => 'coercion_generator' ),
    my_methods           => {
      dict_is_slurpy => sub {
        my $self = shift;

        return !!0 if $self == Dict();

        my $dict = $self->find_parent( sub { $_->has_parent && $_->parent == Dict() } );
        ref( $dict->parameters->[-1] ) eq q(HASH)
          ? $dict->parameters->[-1]{slurpy}
          : !!0;
      },
      hashref_allows_key => sub {
        my $self = shift;
        my ($key) = @_;

        return Str()->check($key) if $self == Dict();

        my $dict = $self->find_parent( sub { $_->has_parent && $_->parent == Dict() } );
        my %params;
        my $slurpy = $dict->my_dict_is_slurpy;
        if ($slurpy) {
          my @args = @{ $dict->parameters };
          pop @args;
          %params = @args;
        }
        else {
          %params = @{ $dict->parameters };
        }

        return !!1
          if exists( $params{$key} );
        return !!0
          if !$slurpy;
        return Str()->check($key)
          if $slurpy == Any() || $slurpy == Item() || $slurpy == Defined() || $slurpy == Ref();
        return $slurpy->my_hashref_allows_key($key)
          if $slurpy->is_a_type_of( HashRef() );
        return !!0;
      },
      hashref_allows_value => sub {
        my $self = shift;
        my ( $key, $value ) = @_;

        return !!0 unless $self->my_hashref_allows_key($key);
        return !!1 if $self == Dict();

        my $dict = $self->find_parent( sub { $_->has_parent && $_->parent == Dict() } );
        my %params;
        my $slurpy = $dict->my_dict_is_slurpy;
        if ($slurpy) {
          my @args = @{ $dict->parameters };
          pop @args;
          %params = @args;
        }
        else {
          %params = @{ $dict->parameters };
        }

        return !!1
          if exists( $params{$key} ) && $params{$key}->check($value);
        return !!0
          if !$slurpy;
        return !!1
          if $slurpy == Any() || $slurpy == Item() || $slurpy == Defined() || $slurpy == Ref();
        return $slurpy->my_hashref_allows_value( $key, $value )
          if $slurpy->is_a_type_of( HashRef() );
        return !!0;
      },
    },
  }
);

use overload ();
$meta->add_type(
  {
    name                 => "Overload",
    parent               => $_obj,
    constraint           => sub { overload::Overloaded($_) },
    inlined              => sub { "Scalar::Util::blessed($_[1]) and overload::Overloaded($_[1])" },
    constraint_generator => sub {
      return $meta->get_type('Overload') unless @_;

      my @operations = map {
        Types::TypeTiny::StringLike->check($_)
          ? "$_"
          : _croak("Parameters to Overload[`a] expected to be a strings; got $_");
      } @_;

      return sub {
        my $value = shift;
        for my $op (@operations) {
          return unless overload::Method( $value, $op );
        }
        return !!1;
      }
    },
    inline_generator => sub {
      my @operations = @_;
      return sub {
        my $v = $_[1];
        join " and ", "Scalar::Util::blessed($v)", map "overload::Method($v, q[$_])", @operations;
      };
    },
  }
);

our %_StrMatch;
my $has_regexp_util;
my $serialize_regexp = sub {
  $has_regexp_util = eval {
    require Regexp::Util;
    Regexp::Util->VERSION('0.003');
    1;
  } || 0 unless defined $has_regexp_util;

  my $re = shift;
  my $serialized;
  if ($has_regexp_util) {
    $serialized = eval { Regexp::Util::serialize_regexp($re) };
  }

  if ( !$serialized ) {
    my $key = sprintf( '%s|%s', ref($re), $re );
    $_StrMatch{$key} = $re;
    $serialized = sprintf( '$Types::Standard::_StrMatch{%s}', B::perlstring($key) );
  }

  return $serialized;
};
$meta->add_type(
  {
    name                 => "StrMatch",
    parent               => $_str,
    constraint_generator => sub {
      return $meta->get_type('StrMatch') unless @_;

      my ( $regexp, $checker ) = @_;

      $_regexp->check($regexp)
        or _croak("First parameter to StrMatch[`a] expected to be a Regexp; got $regexp");

      if ( @_ > 1 ) {
        $checker = Types::TypeTiny::to_TypeTiny($checker);
        Types::TypeTiny::TypeTiny->check($checker)
          or _croak("Second parameter to StrMatch[`a] expected to be a type constraint; got $checker");
      }

      $checker
        ? sub {
        my $value = shift;
        return if ref($value);
        my @m = ( $value =~ $regexp );
        $checker->check( \@m );
        }
        : sub {
        my $value = shift;
        !ref($value) and $value =~ $regexp;
        };
    },
    inline_generator => sub {
      require B;
      my ( $regexp, $checker ) = @_;
      if ($checker) {
        return unless $checker->can_be_inlined;

        my $serialized_re = $regexp->$serialize_regexp;
        return sub {
          my $v = $_[1];
          sprintf
            "!ref($v) and do { my \$m = [$v =~ %s]; %s }",
            $serialized_re,
            $checker->inline_check('$m'),
            ;
        };
      }
      else {
        my $regexp_string = "$regexp";
        if ( $regexp_string =~ /\A\(\?\^u?:(\.+)\)\z/ ) {
          my $length = length $1;
          return sub { "!ref($_) and length($_)>=$length" };
        }

        if ( $regexp_string =~ /\A\(\?\^u?:\\A(\.+)\\z\)\z/ ) {
          my $length = length $1;
          return sub { "!ref($_) and length($_)==$length" };
        }

        my $serialized_re = $regexp->$serialize_regexp;
        return sub {
          my $v = $_[1];
          "!ref($v) and $v =~ $serialized_re";
        };
      }
    },
  }
);

$meta->add_type(
  {
    name       => "OptList",
    parent     => $_arr,
    constraint => sub {
      for my $inner (@$_) {
        return unless ref($inner) eq q(ARRAY);
        return unless @$inner == 2;
        return unless is_Str( $inner->[0] );
      }
      return !!1;
    },
    inlined => sub {
      my ( $self, $var ) = @_;
      my $Str_check = Str()->inline_check('$inner->[0]');
      my @code      = 'do { my $ok = 1; ';
      push @code, sprintf( 'for my $inner (@{%s}) { no warnings; ',                                    $var );
      push @code, sprintf( '($ok=0) && last unless ref($inner) eq q(ARRAY) && @$inner == 2 && (%s); ', $Str_check );
      push @code, '} ';
      push @code, '$ok }';
      return ( undef, join( q( ), @code ) );
    },
  }
);

$meta->add_type(
  {
    name       => "Tied",
    parent     => $_ref,
    constraint => sub {
      !!tied( Scalar::Util::reftype($_) eq 'HASH' ? %{$_} : Scalar::Util::reftype($_) eq 'ARRAY' ? @{$_} : ${$_} );
    },
    inlined => sub {
      my ( $self, $var ) = @_;
      $self->parent->inline_check($var)
        . " and !!tied(Scalar::Util::reftype($var) eq 'HASH' ? \%{$var} : Scalar::Util::reftype($var) eq 'ARRAY' ? \@{$var} : \${$var})";
    },
    name_generator => sub {
      my $self  = shift;
      my $param = Types::TypeTiny::to_TypeTiny(shift);
      unless ( Types::TypeTiny::TypeTiny->check($param) ) {
        Types::TypeTiny::StringLike->check($param)
          or _croak("Parameter to Tied[`a] expected to be a class name; got $param");
        require B;
        return sprintf( "%s[%s]", $self, B::perlstring($param) );
      }
      return sprintf( "%s[%s]", $self, $param );
    },
    constraint_generator => sub {
      return $meta->get_type('Tied') unless @_;

      my $param = Types::TypeTiny::to_TypeTiny(shift);
      unless ( Types::TypeTiny::TypeTiny->check($param) ) {
        Types::TypeTiny::StringLike->check($param)
          or _croak("Parameter to Tied[`a] expected to be a class name; got $param");
        require Type::Tiny::Class;
        $param = "Type::Tiny::Class"->new( class => "$param" );
      }

      my $check = $param->compiled_check;
      return sub {
        $check->( tied( Scalar::Util::reftype($_) eq 'HASH' ? %{$_} : Scalar::Util::reftype($_) eq 'ARRAY' ? @{$_} : ${$_} ) );
      };
    },
    inline_generator => sub {
      my $param = Types::TypeTiny::to_TypeTiny(shift);
      unless ( Types::TypeTiny::TypeTiny->check($param) ) {
        Types::TypeTiny::StringLike->check($param)
          or _croak("Parameter to Tied[`a] expected to be a class name; got $param");
        require Type::Tiny::Class;
        $param = "Type::Tiny::Class"->new( class => "$param" );
      }
      return unless $param->can_be_inlined;

      return sub {
        require B;
        my $var = $_[1];
        sprintf(
"%s and do { my \$TIED = tied(Scalar::Util::reftype($var) eq 'HASH' ? \%{$var} : Scalar::Util::reftype($var) eq 'ARRAY' ? \@{$var} : \${$var}); %s }",
          Ref()->inline_check($var),
          $param->inline_check('$TIED')
        );
      };
    },
  }
);

$meta->add_type(
  {
    name                 => "InstanceOf",
    parent               => $_obj,
    constraint_generator => sub {
      return $meta->get_type('InstanceOf') unless @_;
      require Type::Tiny::Class;
      my @classes = map {
        Types::TypeTiny::TypeTiny->check($_)
          ? $_
          : "Type::Tiny::Class"->new( class => $_, display_name => sprintf( 'InstanceOf[%s]', B::perlstring($_) ) )
      } @_;
      return $classes[0] if @classes == 1;

      require B;
      require Type::Tiny::Union;
      return "Type::Tiny::Union"->new(
        type_constraints => \@classes,
        display_name     => sprintf( 'InstanceOf[%s]', join q[,], map B::perlstring( $_->class ), @classes ),
      );
    },
  }
);

$meta->add_type(
  {
    name                 => "ConsumerOf",
    parent               => $_obj,
    constraint_generator => sub {
      return $meta->get_type('ConsumerOf') unless @_;
      require B;
      require Type::Tiny::Role;
      my @roles = map {
        Types::TypeTiny::TypeTiny->check($_)
          ? $_
          : "Type::Tiny::Role"->new( role => $_, display_name => sprintf( 'ConsumerOf[%s]', B::perlstring($_) ) )
      } @_;
      return $roles[0] if @roles == 1;

      require Type::Tiny::Intersection;
      return "Type::Tiny::Intersection"->new(
        type_constraints => \@roles,
        display_name     => sprintf( 'ConsumerOf[%s]', join q[,], map B::perlstring( $_->role ), @roles ),
      );
    },
  }
);

$meta->add_type(
  {
    name                 => "HasMethods",
    parent               => $_obj,
    constraint_generator => sub {
      return $meta->get_type('HasMethods') unless @_;
      require B;
      require Type::Tiny::Duck;
      return "Type::Tiny::Duck"->new(
        methods      => \@_,
        display_name => sprintf( 'HasMethods[%s]', join q[,], map B::perlstring($_), @_ ),
      );
    },
  }
);

$meta->add_type(
  {
    name                 => "Enum",
    parent               => $_str,
    constraint_generator => sub {
      return $meta->get_type('Enum') unless @_;
      require B;
      require Type::Tiny::Enum;
      return "Type::Tiny::Enum"->new(
        values       => \@_,
        display_name => sprintf( 'Enum[%s]', join q[,], map B::perlstring($_), @_ ),
      );
    },
  }
);

$meta->add_coercion(
  {
    name              => "MkOpt",
    type_constraint   => $meta->get_type("OptList"),
    type_coercion_map => [ $_arr, q{ Exporter::Tiny::mkopt($_) }, $_hash, q{ Exporter::Tiny::mkopt($_) }, $_undef, q{ [] }, ],
  }
);

$meta->add_coercion(
  {
    name               => "Join",
    type_constraint    => $_str,
    coercion_generator => sub {
      my ( $self, $target, $sep ) = @_;
      Types::TypeTiny::StringLike->check($sep)
        or _croak("Parameter to Join[`a] expected to be a string; got $sep");
      require B;
      $sep = B::perlstring($sep);
      return ( ArrayRef(), qq{ join($sep, \@\$_) } );
    },
  }
);

$meta->add_coercion(
  {
    name               => "Split",
    type_constraint    => $_arr,
    coercion_generator => sub {
      my ( $self, $target, $re ) = @_;
      ref($re) eq q(Regexp)
        or _croak("Parameter to Split[`a] expected to be a regular expresssion; got $re");
      my $regexp_string = "$re";
      $regexp_string =~ s/\\\//\\\\\//g;    # toothpicks
      return ( Str(), qq{ [split /$regexp_string/, \$_] } );
    },
  }
);

__PACKAGE__->meta->make_immutable;

1;

__END__

