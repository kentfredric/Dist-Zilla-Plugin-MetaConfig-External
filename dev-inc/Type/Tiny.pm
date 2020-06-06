package Type::Tiny;

use 5.006001;
use strict;
use warnings;

BEGIN {
  if ( $] < 5.008 ) { require Devel::TypeTiny::Perl56Compat }
}

BEGIN {
  $Type::Tiny::AUTHORITY  = 'cpan:TOBYINK';
  $Type::Tiny::VERSION    = '1.002001';
  $Type::Tiny::XS_VERSION = '0.011';
}

use Eval::TypeTiny ();
use Scalar::Util qw( blessed weaken refaddr isweak );
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

sub _swap { $_[2] ? @_[ 1, 0 ] : @_[ 0, 1 ] }

BEGIN {
  ( $] < 5.010001 )
    ? eval q{ sub SUPPORT_SMARTMATCH () { !!0 } }
    : eval q{ sub SUPPORT_SMARTMATCH () { !!1 } };
  ( $] >= 5.014 )
    ? eval q{ sub _FIXED_PRECEDENCE () { !!1 } }
    : eval q{ sub _FIXED_PRECEDENCE () { !!0 } };
}

BEGIN {
  my $try_xs =
      exists( $ENV{PERL_TYPE_TINY_XS} ) ? !!$ENV{PERL_TYPE_TINY_XS}
    : exists( $ENV{PERL_ONLY} )         ? !$ENV{PERL_ONLY}
    :                                     1;

  my $use_xs = 0;
  $try_xs and eval {
    require Type::Tiny::XS;
    'Type::Tiny::XS'->VERSION($Type::Tiny::XS_VERSION);
    $use_xs++;
  };

  *_USE_XS =
      $use_xs
    ? sub () { !!1 }
    : sub () { !!0 };

  *_USE_MOUSE =
      $try_xs
    ? sub () { $INC{'Mouse/Util.pm'} and Mouse::Util::MOUSE_XS() }
    : sub () { !!0 };
}

sub __warn__ {
  my ( $msg, $thing ) = @_ == 2 ? @_ : ( Thing => @_ );
  my $string = do {
    blessed($thing)
      && $thing->isa('Type::Tiny::Union') ? sprintf( 'Union[%s]', join q{, }, map $_->name, @{ $thing->type_constraints } )
      : blessed($thing) && $thing->isa('Type::Tiny') ? $thing->name
      : blessed($thing)
      && $thing->isa('Type::Tiny::_HalfOp')
      ? sprintf( 'HalfOp[ q{%s}, %s, %s ]', $thing->{op}, $thing->{type}->name, $thing->{param} )
      : !defined($thing) ? 'NIL'
      :                    "$thing";
  };
  warn "$msg => $string\n";
  $thing;
}

use overload
  q("")   => sub { caller =~ m{^(Moo::HandleMoose|Sub::Quote)} ? overload::StrVal( $_[0] ) : $_[0]->display_name },
  q(bool) => sub { 1 },
  q(&{}) => "_overload_coderef",
  q(|)   => sub {
  my @tc = _swap @_;
  if ( !_FIXED_PRECEDENCE && $_[2] ) {
    if ( blessed $tc[0] ) {
      if ( blessed $tc[0] eq "Type::Tiny::_HalfOp" ) {
        my $type  = $tc[0]->{type};
        my $param = $tc[0]->{param};
        my $op    = $tc[0]->{op};
        require Type::Tiny::Union;
        return "Type::Tiny::_HalfOp"->new( $op, $param, "Type::Tiny::Union"->new( type_constraints => [ $type, $tc[1] ] ), );
      }
    }
    elsif ( ref $tc[0] eq 'ARRAY' ) {
      require Type::Tiny::_HalfOp;
      return "Type::Tiny::_HalfOp"->new( '|', @tc );
    }
  }
  require Type::Tiny::Union;
  return "Type::Tiny::Union"->new( type_constraints => \@tc );
  },
  q(&) => sub {
  my @tc = _swap @_;
  if ( !_FIXED_PRECEDENCE && $_[2] ) {
    if ( blessed $tc[0] ) {
      if ( blessed $tc[0] eq "Type::Tiny::_HalfOp" ) {
        my $type  = $tc[0]->{type};
        my $param = $tc[0]->{param};
        my $op    = $tc[0]->{op};
        require Type::Tiny::Intersection;
        return
          "Type::Tiny::_HalfOp"->new( $op, $param, "Type::Tiny::Intersection"->new( type_constraints => [ $type, $tc[1] ] ), );
      }
    }
    elsif ( ref $tc[0] eq 'ARRAY' ) {
      require Type::Tiny::_HalfOp;
      return "Type::Tiny::_HalfOp"->new( '&', @tc );
    }
  }
  require Type::Tiny::Intersection;
  "Type::Tiny::Intersection"->new( type_constraints => \@tc );
  },
  q(~)   => sub { shift->complementary_type },
  q(==)  => sub { $_[0]->equals( $_[1] ) },
  q(!=)  => sub { not $_[0]->equals( $_[1] ) },
  q(<)   => sub { my $m = $_[0]->can('is_subtype_of'); $m->( _swap @_ ) },
  q(>)   => sub { my $m = $_[0]->can('is_subtype_of'); $m->( reverse _swap @_ ) },
  q(<=)  => sub { my $m = $_[0]->can('is_a_type_of'); $m->( _swap @_ ) },
  q(>=)  => sub { my $m = $_[0]->can('is_a_type_of'); $m->( reverse _swap @_ ) },
  q(eq)  => sub { "$_[0]" eq "$_[1]" },
  q(cmp) => sub { $_[2] ? ( "$_[1]" cmp "$_[0]" ) : ( "$_[0]" cmp "$_[1]" ) },
  fallback => 1,
  ;

BEGIN {
  overload->import(
    q(~~)    => sub { $_[0]->check( $_[1] ) },
    fallback => 1,                               # 5.10 loses the fallback otherwise
  ) if Type::Tiny::SUPPORT_SMARTMATCH;
}

sub _overload_coderef {
  my $self = shift;
  $self->message unless exists $self->{message};

  #	if ($self->has_parent && $self->_is_null_constraint)
  #	{
  #		$self->{_overload_coderef} ||= $self->parent->_overload_coderef;
  #	}
  #	els
  if ( !exists( $self->{message} ) && exists(&Sub::Quote::quote_sub) && $self->can_be_inlined ) {
    $self->{_overload_coderef} = Sub::Quote::quote_sub( $self->inline_assert('$_[0]') )
      if !$self->{_overload_coderef} || !$self->{_sub_quoted}++;
  }
  else {
    $self->{_overload_coderef} ||= sub { $self->assert_return(@_) };
  }

  $self->{_overload_coderef};
}

our %ALL_TYPES;

my $QFS;
my $uniq = 1;
my $subname;

sub new {
  my $class  = shift;
  my %params = ( @_ == 1 ) ? %{ $_[0] } : @_;

  if (  exists $params{constraint}
    and not ref $params{constraint}
    and not exists $params{constraint_generator}
    and not exists $params{inline_generator} )
  {
    my $code = $params{constraint};
    $params{constraint} = Eval::TypeTiny::eval_closure(
      source      => sprintf( 'sub ($) { %s }', $code ),
      description => "anonymous check",
    );
    $params{inlined} ||= sub {
      my ($type) = @_;
      my $inlined = $_ eq '$_' ? "do { $code }" : "do { local \$_ = $_; $code }";
      $type->has_parent ? ( undef, $inlined ) : $inlined;
    };
  }

  if ( exists $params{parent} ) {
    $params{parent} =
      ref( $params{parent} ) =~ /^Type::Tiny\b/
      ? $params{parent}
      : Types::TypeTiny::to_TypeTiny( $params{parent} );

    _croak "Parent must be an instance of %s", __PACKAGE__
      unless blessed( $params{parent} ) && $params{parent}->isa(__PACKAGE__);
  }

  $params{name} = "__ANON__" unless exists $params{name};
  $params{uniq} = $uniq++;

  if ( $params{name} ne "__ANON__" ) {

    # First try a fast ASCII-only expression, but fall back to Unicode
    $params{name} =~ /^_{0,2}[A-Z][A-Za-z0-9_]+$/sm
      or eval q( use 5.008; $params{name} =~ /^_{0,2}\p{Lu}[\p{L}0-9_]+$/sm )
      or _croak '"%s" is not a valid type name', $params{name};
  }

  if ( exists $params{coercion} and !ref $params{coercion} and $params{coercion} ) {
    $params{parent}->has_coercion
      or _croak "coercion => 1 requires type to have a direct parent with a coercion";

    $params{coercion} = $params{parent}->coercion->type_coercion_map;
  }

  if ( !exists $params{inlined}
    and exists $params{constraint}
    and ( !exists $params{parent} or $params{parent}->can_be_inlined )
    and $QFS ||= "Sub::Quote"->can("quoted_from_sub") )
  {
    my ( undef, $perlstring, $captures ) = @{ $QFS->( $params{constraint} ) || [] };

    $params{inlined} = sub {
      my ( $self, $var ) = @_;
      my $code = Sub::Quote::inlinify( $perlstring, $var, $var eq q($_) ? '' : "local \$_ = $var;", 1, );
      $code = sprintf( '%s and %s', $self->parent->inline_check($var), $code ) if $self->has_parent;
      return $code;
      }
      if $perlstring && !$captures;
  }

  my $self = bless \%params, $class;

  unless ( $params{tmp} ) {
    my $uniq = $self->{uniq};

    $ALL_TYPES{$uniq} = $self;
    weaken( $ALL_TYPES{$uniq} );

    package    # no index
      Moo::HandleMoose;
    my $tmp = $self;
    Scalar::Util::weaken($tmp);
    $Moo::HandleMoose::TYPE_MAP{$self} = sub { $tmp };
  }

  if ( ref( $params{coercion} ) eq q(CODE) ) {
    require Types::Standard;
    my $code = delete( $params{coercion} );
    $self->{coercion} = $self->_build_coercion;
    $self->coercion->add_type_coercions( Types::Standard::Any(), $code );
  }
  elsif ( ref( $params{coercion} ) eq q(ARRAY) ) {
    my $arr = delete( $params{coercion} );
    $self->{coercion} = $self->_build_coercion;
    $self->coercion->add_type_coercions(@$arr);
  }

  if ( $params{my_methods} ) {
    $subname =
        eval { require Sub::Util } ? \&Sub::Util::set_subname
      : eval { require Sub::Name } ? \&Sub::Name::subname
      : 0
      if not defined $subname;
    if ($subname) {
      $subname->( sprintf( "%s::my_%s", $self->qualified_name, $_ ), $params{my_methods}{$_}, ) for keys %{ $params{my_methods} };
    }
  }

  return $self;
}

sub DESTROY {
  my $self = shift;
  delete( $ALL_TYPES{ $self->{uniq} } );
  package    # no index
    Moo::HandleMoose;
  delete( $Moo::HandleMoose::TYPE_MAP{$self} );
  return;
}

sub _clone {
  my $self = shift;
  my %opts;
  $opts{$_} = $self->{$_} for qw< name display_name message >;
  $self->create_child_type(%opts);
}

our $DD;

sub _dd {
  @_ = $_ unless @_;
  my ($value) = @_;

  goto $DD if ref($DD) eq q(CODE);

  require B;

      !defined $value ? 'Undef'
    : !ref $value     ? sprintf( 'Value %s', B::perlstring($value) )
    : do {
    my $N = 0 + ( defined($DD) ? $DD : 72 );
    require Data::Dumper;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::Useqq    = 1;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Maxdepth = 2;
    my $str = Data::Dumper::Dumper($value);
    $str = substr( $str, 0, $N - 12 ) . '...' . substr( $str, -1, 1 )
      if length($str) >= $N;
    "Reference $str";
  }
}

sub _loose_to_TypeTiny {
  map +(
    ref($_)
    ? Types::TypeTiny::to_TypeTiny($_)
    : do { require Type::Utils; Type::Utils::dwim_type($_) }
  ), @_;
}

sub name                 { $_[0]{name} }
sub display_name         { $_[0]{display_name} ||= $_[0]->_build_display_name }
sub parent               { $_[0]{parent} }
sub constraint           { $_[0]{constraint} ||= $_[0]->_build_constraint }
sub compiled_check       { $_[0]{compiled_type_constraint} ||= $_[0]->_build_compiled_check }
sub coercion             { $_[0]{coercion} ||= $_[0]->_build_coercion }
sub message              { $_[0]{message} }
sub library              { $_[0]{library} }
sub inlined              { $_[0]{inlined} }
sub constraint_generator { $_[0]{constraint_generator} }
sub inline_generator     { $_[0]{inline_generator} }
sub name_generator       { $_[0]{name_generator} ||= $_[0]->_build_name_generator }
sub coercion_generator   { $_[0]{coercion_generator} }
sub parameters           { $_[0]{parameters} }
sub moose_type           { $_[0]{moose_type} ||= $_[0]->_build_moose_type }
sub mouse_type           { $_[0]{mouse_type} ||= $_[0]->_build_mouse_type }
sub deep_explanation     { $_[0]{deep_explanation} }
sub my_methods           { $_[0]{my_methods} ||= $_[0]->_build_my_methods }

sub has_parent               { exists $_[0]{parent} }
sub has_library              { exists $_[0]{library} }
sub has_coercion             { $_[0]{coercion} and !!@{ $_[0]{coercion}->type_coercion_map } }
sub has_inlined              { exists $_[0]{inlined} }
sub has_constraint_generator { exists $_[0]{constraint_generator} }
sub has_inline_generator     { exists $_[0]{inline_generator} }
sub has_coercion_generator   { exists $_[0]{coercion_generator} }
sub has_parameters           { exists $_[0]{parameters} }
sub has_message              { defined $_[0]{message} }
sub has_deep_explanation     { exists $_[0]{deep_explanation} }

sub _default_message { $_[0]{_default_message} ||= $_[0]->_build_default_message }

sub _assert_coercion {
  my $self = shift;
  _croak "No coercion for this type constraint"
    unless $self->has_coercion && @{ $self->coercion->type_coercion_map };
  return $self->coercion;
}

my $null_constraint = sub { !!1 };

sub _build_display_name {
  shift->name;
}

sub _build_constraint {
  return $null_constraint;
}

sub _is_null_constraint {
  shift->constraint == $null_constraint;
}

sub _build_coercion {
  require Type::Coercion;
  my $self = shift;
  my %opts = ( type_constraint => $self );
  $opts{display_name} = "to_$self" unless $self->is_anon;
  return "Type::Coercion"->new(%opts);
}

sub _build_default_message {
  my $self = shift;
  return sub { sprintf '%s did not pass type constraint', _dd( $_[0] ) }
    if "$self" eq "__ANON__";
  my $name = "$self";
  return sub { sprintf '%s did not pass type constraint "%s"', _dd( $_[0] ), $name };
}

sub _build_name_generator {
  my $self = shift;
  return sub {
    my ( $s, @a ) = @_;
    sprintf( '%s[%s]', $s, join q[,], @a );
  };
}

sub _build_compiled_check {
  my $self = shift;

  if ( $self->_is_null_constraint and $self->has_parent ) {
    return $self->parent->compiled_check;
  }

  return Eval::TypeTiny::eval_closure(
    source      => sprintf( 'sub ($) { %s }',      $self->inline_check('$_[0]') ),
    description => sprintf( "compiled check '%s'", $self ),
  ) if $self->can_be_inlined;

  my @constraints;
  push @constraints, $self->parent->compiled_check if $self->has_parent;
  push @constraints, $self->constraint             if !$self->_is_null_constraint;
  return $null_constraint unless @constraints;

  return sub ($) {
    local $_ = $_[0];
    for my $c (@constraints) {
      return unless $c->(@_);
    }
    return !!1;
  };
}

sub equals {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  return !!1 if refaddr($self) == refaddr($other);

  return !!1 if $self->has_parent  && $self->_is_null_constraint  && $self->parent == $other;
  return !!1 if $other->has_parent && $other->_is_null_constraint && $other->parent == $self;

  return !!1 if refaddr( $self->compiled_check ) == refaddr( $other->compiled_check );

  return $self->qualified_name eq $other->qualified_name
    if $self->has_library && !$self->is_anon && $other->has_library && !$other->is_anon;

  return $self->inline_check('$x') eq $other->inline_check('$x')
    if $self->can_be_inlined && $other->can_be_inlined;

  return;
}

sub is_subtype_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  #	my $this = $self;
  #	while (my $parent = $this->parent)
  #	{
  #		return !!1 if $parent->equals($other);
  #		$this = $parent;
  #	}
  #	return;

  return unless $self->has_parent;
  $self->parent->equals($other) or $self->parent->is_subtype_of($other);
}

sub is_supertype_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  $other->is_subtype_of($self);
}

sub is_a_type_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  $self->equals($other) or $self->is_subtype_of($other);
}

sub strictly_equals {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");
  $self->{uniq} == $other->{uniq};
}

sub is_strictly_subtype_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  #	my $this = $self;
  #	while (my $parent = $this->parent)
  #	{
  #		return !!1 if $parent->strictly_equals($other);
  #		$this = $parent;
  #	}
  #	return;

  return unless $self->has_parent;
  $self->parent->strictly_equals($other) or $self->parent->is_strictly_subtype_of($other);
}

sub is_strictly_supertype_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  $other->is_strictly_subtype_of($self);
}

sub is_strictly_a_type_of {
  my ( $self, $other ) = _loose_to_TypeTiny(@_);
  return unless blessed($self)  && $self->isa("Type::Tiny");
  return unless blessed($other) && $other->isa("Type::Tiny");

  $self->strictly_equals($other) or $self->is_strictly_subtype_of($other);
}

sub qualified_name {
  my $self = shift;
  ( exists $self->{library} and $self->name ne "__ANON__" )
    ? "$self->{library}::$self->{name}"
    : $self->{name};
}

sub is_anon {
  my $self = shift;
  $self->name eq "__ANON__";
}

sub parents {
  my $self = shift;
  return unless $self->has_parent;
  return ( $self->parent, $self->parent->parents );
}

sub find_parent {
  my $self = shift;
  my ($test) = @_;

  local ( $_, $. );
  my $type  = $self;
  my $count = 0;
  while ($type) {
    if ( $test->( $_ = $type, $. = $count ) ) {
      return wantarray ? ( $type, $count ) : $type;
    }
    else {
      $type = $type->parent;
      $count++;
    }
  }

  return;
}

sub check {
  my $self = shift;
  ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )->(@_);
}

sub _strict_check {
  my $self = shift;
  local $_ = $_[0];

  my @constraints =
    reverse
    map { $_->constraint }
    grep { not $_->_is_null_constraint } ( $self, $self->parents );

  for my $c (@constraints) {
    return unless $c->(@_);
  }

  return !!1;
}

sub get_message {
  my $self = shift;
  local $_ = $_[0];
  $self->has_message
    ? $self->message->(@_)
    : $self->_default_message->(@_);
}

sub validate {
  my $self = shift;

  return undef if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )->(@_);

  local $_ = $_[0];
  return $self->get_message(@_);
}

sub validate_explain {
  my $self = shift;
  my ( $value, $varname ) = @_;
  $varname = '$_' unless defined $varname;

  return undef if $self->check($value);

  if ( $self->has_parent ) {
    my $parent = $self->parent->validate_explain( $value, $varname );
    return [ sprintf( '"%s" is a subtype of "%s"', $self, $self->parent ), @$parent ] if $parent;
  }

  my $message = sprintf( '%s%s', $self->get_message($value), $varname eq q{$_} ? '' : sprintf( ' (in %s)', $varname ), );

  if ( $self->is_parameterized and $self->parent->has_deep_explanation ) {
    my $deep = $self->parent->deep_explanation->( $self, $value, $varname );
    return [ $message, @$deep ] if $deep;
  }

  return [ $message, sprintf( '"%s" is defined as: %s', $self, $self->_perlcode ) ];
}

my $b;

sub _perlcode {
  my $self = shift;

  return $self->inline_check('$_')
    if $self->can_be_inlined;

  $b ||= do {
    require B::Deparse;
    my $tmp = "B::Deparse"->new;
    $tmp->ambient_pragmas( strict => "all", warnings => "all" ) if $tmp->can('ambient_pragmas');
    $tmp;
  };

  my $code = $b->coderef2text( $self->constraint );
  $code =~ s/\s+/ /g;
  return "sub $code";
}

sub assert_valid {
  my $self = shift;

  return !!1 if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )->(@_);

  local $_ = $_[0];
  $self->_failed_check( "$self", $_ );
}

sub assert_return {
  my $self = shift;

  return $_[0] if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )->(@_);

  local $_ = $_[0];
  $self->_failed_check( "$self", $_ );
}

sub can_be_inlined {
  my $self = shift;
  return $self->parent->can_be_inlined
    if $self->has_parent && $self->_is_null_constraint;
  return !!1
    if !$self->has_parent && $self->_is_null_constraint;
  return $self->has_inlined;
}

sub inline_check {
  my $self = shift;
  _croak 'Cannot inline type constraint check for "%s"', $self
    unless $self->can_be_inlined;

  return $self->parent->inline_check(@_)
    if $self->has_parent && $self->_is_null_constraint;
  return '(!!1)'
    if !$self->has_parent && $self->_is_null_constraint;

  local $_ = $_[0];
  my @r = $self->inlined->( $self, @_ );
  if ( @r and not defined $r[0] ) {
    _croak 'Inlining type constraint check for "%s" returned undef!', $self
      unless $self->has_parent;
    $r[0] = $self->parent->inline_check(@_);
  }
  my $r = join " && " => map { /[;{}]/ ? "do { $_ }" : "($_)" } @r;
  return @r == 1 ? $r : "($r)";
}

sub inline_assert {
  require B;
  my $self    = shift;
  my $varname = $_[0];
  my $code    = sprintf(
    q[do { no warnings "void"; %s ? %s : Type::Tiny::_failed_check(%d, %s, %s) };],
    $self->inline_check(@_),
    $varname, $self->{uniq}, B::perlstring("$self"), $varname,
  );
  return $code;
}

sub _failed_check {
  require Error::TypeTiny::Assertion;

  my ( $self, $name, $value, %attrs ) = @_;
  $self = $ALL_TYPES{$self} unless ref $self;

  my $exception_class = delete( $attrs{exception_class} ) || "Error::TypeTiny::Assertion";

  if ($self) {
    $exception_class->throw(
      message => $self->get_message($value),
      type    => $self,
      value   => $value,
      %attrs,
    );
  }
  else {
    $exception_class->throw(
      message => sprintf( '%s did not pass type constraint "%s"', _dd($value), $name ),
      value   => $value,
      %attrs,
    );
  }
}

sub coerce {
  my $self = shift;
  $self->_assert_coercion->coerce(@_);
}

sub assert_coerce {
  my $self = shift;
  $self->_assert_coercion->assert_coerce(@_);
}

sub is_parameterizable {
  shift->has_constraint_generator;
}

sub is_parameterized {
  shift->has_parameters;
}

my %param_cache;

sub parameterize {
  my $self = shift;

  $self->is_parameterizable
    or @_ ? _croak( "Type '%s' does not accept parameters", "$self" ) : return ($self);

  @_ = map Types::TypeTiny::to_TypeTiny($_), @_;

  # Generate a key for caching parameterized type constraints,
  # but only if all the parameters are strings or type constraints.
  my $key;
  if ( not grep( ref($_) && !Types::TypeTiny::TypeTiny->check($_), @_ ) ) {
    require B;
    $key = join ":", map( Types::TypeTiny::TypeTiny->check($_) ? $_->{uniq} : B::perlstring($_), $self, @_ );
  }

  return $param_cache{$key} if defined $key && defined $param_cache{$key};

  local $Type::Tiny::parameterize_type = $self;
  local $_                             = $_[0];
  my $P;

  my ( $constraint, $compiled ) = $self->constraint_generator->(@_);

  if ( Types::TypeTiny::TypeTiny->check($constraint) ) {
    $P = $constraint;
  }
  else {
    my %options = (
      constraint   => $constraint,
      display_name => $self->name_generator->( $self, @_ ),
      parameters   => [@_],
    );
    $options{compiled_type_constraint} = $compiled
      if $compiled;
    $options{inlined} = $self->inline_generator->(@_)
      if $self->has_inline_generator;
    exists $options{$_} && !defined $options{$_} && delete $options{$_} for keys %options;

    $P = $self->create_child_type(%options);

    my $coercion;
    $coercion = $self->coercion_generator->( $self, $P, @_ )
      if $self->has_coercion_generator;
    $P->coercion->add_type_coercions( @{ $coercion->type_coercion_map } )
      if $coercion;
  }

  if ( defined $key ) {
    $param_cache{$key} = $P;
    weaken( $param_cache{$key} );
  }

  $P->coercion->freeze;

  return $P;
}

sub child_type_class {
  __PACKAGE__;
}

sub create_child_type {
  my $self = shift;
  return $self->child_type_class->new( parent => $self, @_ );
}

sub complementary_type {
  my $self = shift;
  my $r    = ( $self->{complementary_type} ||= $self->_build_complementary_type );
  weaken( $self->{complementary_type} ) unless isweak( $self->{complementary_type} );
  return $r;
}

sub _build_complementary_type {
  my $self = shift;
  my %opts = (
    constraint   => sub { not $self->check($_) },
    display_name => sprintf( "~%s", $self ),
  );
  $opts{display_name} =~ s/^\~{2}//;
  $opts{inlined} = sub { shift; "not(" . $self->inline_check(@_) . ")" }
    if $self->can_be_inlined;
  return "Type::Tiny"->new(%opts);
}

sub _instantiate_moose_type {
  my $self = shift;
  my %opts = @_;
  require Moose::Meta::TypeConstraint;
  return "Moose::Meta::TypeConstraint"->new(%opts);
}

sub _build_moose_type {
  my $self = shift;

  my $r;
  if ( $self->{_is_core} ) {
    require Moose::Util::TypeConstraints;
    $r = Moose::Util::TypeConstraints::find_type_constraint( $self->name );
    $r->{"Types::TypeTiny::to_TypeTiny"} = $self;
    Scalar::Util::weaken( $r->{"Types::TypeTiny::to_TypeTiny"} );
  }
  else {
    my $wrapped_inlined = sub {
      shift;
      $self->inline_check(@_);
    };

    my %opts;
    $opts{name}   = $self->qualified_name     if $self->has_library && !$self->is_anon;
    $opts{parent} = $self->parent->moose_type if $self->has_parent;
    $opts{constraint} = $self->constraint unless $self->_is_null_constraint;
    $opts{message}    = $self->message if $self->has_message;
    $opts{inlined}    = $wrapped_inlined if $self->has_inlined;

    $r                                   = $self->_instantiate_moose_type(%opts);
    $r->{"Types::TypeTiny::to_TypeTiny"} = $self;
    $self->{moose_type}                  = $r;                                      # prevent recursion
    $r->coercion( $self->coercion->moose_coercion ) if $self->has_coercion;
  }

  return $r;
}

sub _build_mouse_type {
  my $self = shift;

  my %options;
  $options{name}   = $self->qualified_name     if $self->has_library && !$self->is_anon;
  $options{parent} = $self->parent->mouse_type if $self->has_parent;
  $options{constraint} = $self->constraint unless $self->_is_null_constraint;
  $options{message}    = $self->message if $self->has_message;

  require Mouse::Meta::TypeConstraint;
  my $r = "Mouse::Meta::TypeConstraint"->new(%options);

  $self->{mouse_type} = $r;    # prevent recursion
  $r->_add_type_coercions( $self->coercion->freeze->_codelike_type_coercion_map('mouse_type') ) if $self->has_coercion;

  return $r;
}

sub _process_coercion_list {
  my $self = shift;

  my @pairs;
  while (@_) {
    my $next = shift;
    if ( blessed($next) and $next->isa('Type::Coercion') and $next->is_parameterized ) {
      push @pairs => ( @{ $next->_reparameterize($self)->type_coercion_map } );
    }
    elsif ( blessed($next) and $next->can('type_coercion_map') ) {
      push @pairs => ( @{ $next->type_coercion_map }, );
    }
    elsif ( ref($next) eq q(ARRAY) ) {
      unshift @_, @$next;
    }
    else {
      push @pairs => ( Types::TypeTiny::to_TypeTiny($next), shift, );
    }
  }

  return @pairs;
}

sub plus_coercions {
  my $self = shift;
  my $new  = $self->_clone;
  $new->coercion->add_type_coercions( $self->_process_coercion_list(@_), @{ $self->coercion->type_coercion_map }, );
  $new->coercion->freeze;
  return $new;
}

sub plus_fallback_coercions {
  my $self = shift;

  my $new = $self->_clone;
  $new->coercion->add_type_coercions( @{ $self->coercion->type_coercion_map }, $self->_process_coercion_list(@_), );
  $new->coercion->freeze;
  return $new;
}

sub minus_coercions {
  my $self = shift;

  my $new = $self->_clone;
  my @not = grep Types::TypeTiny::TypeTiny->check($_), $self->_process_coercion_list( $new, @_ );

  my @keep;
  my $c = $self->coercion->type_coercion_map;
  for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
    my $keep_this = 1;
  NOT: for my $n (@not) {
      if ( $c->[$i] == $n ) {
        $keep_this = 0;
        last NOT;
      }
    }

    push @keep, $c->[$i], $c->[ $i + 1 ] if $keep_this;
  }

  $new->coercion->add_type_coercions(@keep);
  $new->coercion->freeze;
  return $new;
}

sub no_coercions {
  my $new = shift->_clone;
  $new->coercion->freeze;
  $new;
}

sub coercibles {
  my $self = shift;
  $self->has_coercion ? $self->coercion->_source_type_union : $self;
}

sub isa {
  my $self = shift;

  if ( $INC{"Moose.pm"} and ref($self) and $_[0] =~ /^(?:Class::MOP|MooseX?::Meta)::(.+)$/ ) {
    my $meta = $1;

    return !!1                             if $meta eq 'TypeConstraint';
    return $self->is_parameterized         if $meta eq 'TypeConstraint::Parameterized';
    return $self->is_parameterizable       if $meta eq 'TypeConstraint::Parameterizable';
    return $self->isa('Type::Tiny::Union') if $meta eq 'TypeConstraint::Union';

    my $inflate = $self->moose_type;
    return $inflate->isa(@_);
  }

  if ( $INC{"Mouse.pm"} and ref($self) and $_[0] eq 'Mouse::Meta::TypeConstraint' ) {
    return !!1;
  }

  $self->SUPER::isa(@_);
}

sub _build_my_methods {
  return {};
}

sub _lookup_my_method {
  my $self = shift;
  my ($name) = @_;

  if ( $self->my_methods->{$name} ) {
    return $self->my_methods->{$name};
  }

  if ( $self->has_parent ) {
    return $self->parent->_lookup_my_method(@_);
  }

  return;
}

sub can {
  my $self = shift;

  return !!0 if $_[0] eq 'type_parameter' && blessed( $_[0] ) && $_[0]->has_parameters;

  my $can = $self->SUPER::can(@_);
  return $can if $can;

  if ( ref($self) ) {
    if ( $INC{"Moose.pm"} ) {
      my $method = $self->moose_type->can(@_);
      return sub { shift->moose_type->$method(@_) }
        if $method;
    }
    if ( $_[0] =~ /\Amy_(.+)\z/ ) {
      my $method = $self->_lookup_my_method($1);
      return $method if $method;
    }
  }

  return;
}

sub AUTOLOAD {
  my $self = shift;
  my ($m) = ( our $AUTOLOAD =~ /::(\w+)$/ );
  return if $m eq 'DESTROY';

  if ( ref($self) ) {
    if ( $INC{"Moose.pm"} ) {
      my $method = $self->moose_type->can($m);
      return $self->moose_type->$method(@_) if $method;
    }
    if ( $m =~ /\Amy_(.+)\z/ ) {
      my $method = $self->_lookup_my_method($1);
      return $self->$method(@_) if $method;
    }
  }

  _croak q[Can't locate object method "%s" via package "%s"], $m, ref($self) || $self;
}

sub DOES {
  my $self = shift;

  return !!1 if ref($self)  && $_[0] =~ m{^ Type::API::Constraint (?: ::Coercible | ::Inlinable )? $}x;
  return !!1 if !ref($self) && $_[0] eq 'Type::API::Constraint::Constructor';

  "UNIVERSAL"->can("DOES") ? $self->SUPER::DOES(@_) : $self->isa(@_);
}

sub _has_xsub {
  require B;
  !!B::svref_2object( shift->compiled_check )->XSUB;
}

sub of    { shift->parameterize(@_) }
sub where { shift->create_child_type( constraint => @_ ) }

# fill out Moose-compatible API
sub inline_environment                 { +{} }
sub _inline_check                      { shift->inline_check(@_) }
sub _compiled_type_constraint          { shift->compiled_check(@_) }
sub meta                               { _croak("Not really a Moose::Meta::TypeConstraint. Sorry!") }
sub compile_type_constraint            { shift->compiled_check }
sub _actually_compile_type_constraint  { shift->_build_compiled_check }
sub hand_optimized_type_constraint     { shift->{hand_optimized_type_constraint} }
sub has_hand_optimized_type_constraint { exists( shift->{hand_optimized_type_constraint} ) }
sub type_parameter                     { ( shift->parameters || [] )->[0] }

# some stuff for Mouse-compatible API
sub __is_parameterized      { shift->is_parameterized(@_) }
sub _add_type_coercions     { shift->coercion->add_type_coercions(@_) }
sub _as_string              { shift->qualified_name(@_) }
sub _compiled_type_coercion { shift->coercion->compiled_coercion(@_) }
sub _identity               { refaddr(shift) }
sub _unite                  { require Type::Tiny::Union; "Type::Tiny::Union"->new( type_constraints => \@_ ) }

# Hooks for Type::Tie
sub TIESCALAR { require Type::Tie; unshift @_, 'Type::Tie::SCALAR'; goto \&Type::Tie::SCALAR::TIESCALAR }
sub TIEARRAY  { require Type::Tie; unshift @_, 'Type::Tie::ARRAY';  goto \&Type::Tie::ARRAY::TIEARRAY }
sub TIEHASH   { require Type::Tie; unshift @_, 'Type::Tie::HASH';   goto \&Type::Tie::HASH::TIEHASH }

1;

__END__

