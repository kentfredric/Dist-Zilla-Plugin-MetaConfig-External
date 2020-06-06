package Type::Coercion;

use 5.006001;
use strict;
use warnings;

BEGIN {
  $Type::Coercion::AUTHORITY = 'cpan:TOBYINK';
  $Type::Coercion::VERSION   = '1.002001';
}

use Eval::TypeTiny qw<>;
use Scalar::Util qw< blessed >;
use Types::TypeTiny qw<>;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use overload
  q("")   => sub { caller =~ m{^(Moo::HandleMoose|Sub::Quote)} ? overload::StrVal( $_[0] ) : $_[0]->display_name },
  q(bool) => sub { 1 },
  q(&{})   => "_overload_coderef",
  fallback => 1,
  ;

BEGIN {
  require Type::Tiny;
  overload->import(
    q(~~)    => sub { $_[0]->has_coercion_for_value( $_[1] ) },
    fallback => 1,                                                # 5.10 loses the fallback otherwise
  ) if Type::Tiny::SUPPORT_SMARTMATCH();
}

sub _overload_coderef {
  my $self = shift;

  if ( "Sub::Quote"->can("quote_sub") && $self->can_be_inlined ) {
    $self->{_overload_coderef} = Sub::Quote::quote_sub( $self->inline_coercion('$_[0]') )
      if !$self->{_overload_coderef} || !$self->{_sub_quoted}++;
  }
  else {
    $self->{_overload_coderef} ||= sub { $self->coerce(@_) };
  }

  $self->{_overload_coderef};
}

sub new {
  my $class  = shift;
  my %params = ( @_ == 1 ) ? %{ $_[0] } : @_;

  $params{name} = '__ANON__' unless exists( $params{name} );
  my $C = delete( $params{type_coercion_map} ) || [];
  my $F = delete( $params{frozen} );

  my $self = bless \%params, $class;
  $self->add_type_coercions(@$C) if @$C;
  $self->_preserve_type_constraint;
  Scalar::Util::weaken( $self->{type_constraint} );    # break ref cycle
  $self->{frozen} = $F if $F;

  unless ( $self->is_anon ) {

    # First try a fast ASCII-only expression, but fall back to Unicode
    $self->name =~ /^_{0,2}[A-Z][A-Za-z0-9_]+$/sm
      or eval q( use 5.008; $self->name =~ /^_{0,2}\p{Lu}[\p{L}0-9_]+$/sm )
      or _croak '"%s" is not a valid coercion name', $self->name;
  }

  return $self;
}

sub name               { $_[0]{name} }
sub display_name       { $_[0]{display_name} ||= $_[0]->_build_display_name }
sub library            { $_[0]{library} }
sub type_constraint    { $_[0]{type_constraint} ||= $_[0]->_maybe_restore_type_constraint }
sub type_coercion_map  { $_[0]{type_coercion_map} ||= [] }
sub moose_coercion     { $_[0]{moose_coercion} ||= $_[0]->_build_moose_coercion }
sub compiled_coercion  { $_[0]{compiled_coercion} ||= $_[0]->_build_compiled_coercion }
sub frozen             { $_[0]{frozen} ||= 0 }
sub coercion_generator { $_[0]{coercion_generator} }
sub parameters         { $_[0]{parameters} }
sub parameterized_from { $_[0]{parameterized_from} }

sub has_library            { exists $_[0]{library} }
sub has_type_constraint    { defined $_[0]->type_constraint }     # sic
sub has_coercion_generator { exists $_[0]{coercion_generator} }
sub has_parameters         { exists $_[0]{parameters} }

sub _preserve_type_constraint {
  my $self = shift;
  $self->{_compiled_type_constraint_check} = $self->{type_constraint}->compiled_check
    if $self->{type_constraint};
}

sub _maybe_restore_type_constraint {
  my $self = shift;
  if ( my $check = $self->{_compiled_type_constraint_check} ) {
    return Type::Tiny->new( constraint => $check );
  }
  return;
}

sub add {
  my $class = shift;
  my ( $x, $y, $swap ) = @_;

  Types::TypeTiny::TypeTiny->check($x) and return $x->plus_fallback_coercions($y);
  Types::TypeTiny::TypeTiny->check($y) and return $y->plus_coercions($x);

  _croak "Attempt to add $class to something that is not a $class"
    unless blessed($x) && blessed($y) && $x->isa($class) && $y->isa($class);

  ( $y, $x ) = ( $x, $y ) if $swap;

  my %opts;
  if ( $x->has_type_constraint and $y->has_type_constraint and $x->type_constraint == $y->type_constraint ) {
    $opts{type_constraint} = $x->type_constraint;
  }
  elsif ( $x->has_type_constraint and $y->has_type_constraint ) {

    #		require Type::Tiny::Union;
    #		$opts{type_constraint} = "Type::Tiny::Union"->new(
    #			type_constraints => [ $x->type_constraint, $y->type_constraint ],
    #		);
  }
  $opts{display_name} ||= "$x+$y";
  delete $opts{display_name} if $opts{display_name} eq '__ANON__+__ANON__';

  my $new = $class->new(%opts);
  $new->add_type_coercions( @{ $x->type_coercion_map } );
  $new->add_type_coercions( @{ $y->type_coercion_map } );
  return $new;
}

sub _build_display_name {
  shift->name;
}

sub qualified_name {
  my $self = shift;

  if ( $self->has_library and not $self->is_anon ) {
    return sprintf( "%s::%s", $self->library, $self->name );
  }

  return $self->name;
}

sub is_anon {
  my $self = shift;
  $self->name eq "__ANON__";
}

sub _clear_compiled_coercion {
  delete $_[0]{_overload_coderef};
  delete $_[0]{compiled_coercion};
}

sub freeze                    { $_[0]{frozen} = 1; $_[0] }
sub i_really_want_to_unfreeze { $_[0]{frozen} = 0; $_[0] }

sub coerce {
  my $self = shift;
  return $self->compiled_coercion->(@_);
}

sub assert_coerce {
  my $self = shift;
  my $r    = $self->coerce(@_);
  $self->type_constraint->assert_valid($r)
    if $self->has_type_constraint;
  return $r;
}

sub has_coercion_for_type {
  my $self = shift;
  my $type = Types::TypeTiny::to_TypeTiny( $_[0] );

  return "0 but true"
    if $self->has_type_constraint && $type->is_a_type_of( $self->type_constraint );

  my $c = $self->type_coercion_map;
  for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
    return !!1 if $type->is_a_type_of( $c->[$i] );
  }
  return;
}

sub has_coercion_for_value {
  my $self = shift;
  local $_ = $_[0];

  return "0 but true"
    if $self->has_type_constraint && $self->type_constraint->check(@_);

  my $c = $self->type_coercion_map;
  for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
    return !!1 if $c->[$i]->check(@_);
  }
  return;
}

sub add_type_coercions {
  my $self = shift;
  my @args = @_;

  _croak "Attempt to add coercion code to a Type::Coercion which has been frozen" if $self->frozen;

  while (@args) {
    my $type     = Types::TypeTiny::to_TypeTiny( shift @args );
    my $coercion = shift @args;

    _croak "Types must be blessed Type::Tiny objects"
      unless Types::TypeTiny::TypeTiny->check($type);
    _croak "Coercions must be code references or strings"
      unless Types::TypeTiny::StringLike->check($coercion) || Types::TypeTiny::CodeLike->check($coercion);

    push @{ $self->type_coercion_map }, $type, $coercion;
  }

  $self->_clear_compiled_coercion;
  return $self;
}

sub _build_compiled_coercion {
  my $self = shift;

  my @mishmash = @{ $self->type_coercion_map };
  return sub { $_[0] }
    unless @mishmash;

  if ( $self->can_be_inlined ) {
    return Eval::TypeTiny::eval_closure(
      source      => sprintf( 'sub ($) { %s }',         $self->inline_coercion('$_[0]') ),
      description => sprintf( "compiled coercion '%s'", $self ),
    );
  }

  # These arrays will be closed over.
  my ( @types, @codes );
  while (@mishmash) {
    push @types, shift @mishmash;
    push @codes, shift @mishmash;
  }
  if ( $self->has_type_constraint ) {
    unshift @types, $self->type_constraint;
    unshift @codes, undef;
  }

  my @sub;

  for my $i ( 0 .. $#types ) {
    push @sub, $types[$i]->can_be_inlined
      ? sprintf( 'if (%s)',                $types[$i]->inline_check('$_[0]') )
      : sprintf( 'if ($checks[%d]->(@_))', $i );
    push @sub,
        !defined( $codes[$i] )                           ? sprintf('  { return $_[0] }')
      : Types::TypeTiny::StringLike->check( $codes[$i] ) ? sprintf( '  { local $_ = $_[0]; return scalar(%s); }', $codes[$i] )
      :   sprintf( '  { local $_ = $_[0]; return scalar($codes[%d]->(@_)) }', $i );
  }

  push @sub, 'return $_[0];';

  return Eval::TypeTiny::eval_closure(
    source      => sprintf( 'sub ($) { %s }',         join qq[\n], @sub ),
    description => sprintf( "compiled coercion '%s'", $self ),
    environment => {
      '@checks' => [ map $_->compiled_check, @types ],
      '@codes'  => \@codes,
    },
  );
}

sub can_be_inlined {
  my $self = shift;

  return unless $self->frozen;

  return
    if $self->has_type_constraint
    && !$self->type_constraint->can_be_inlined;

  my @mishmash = @{ $self->type_coercion_map };
  while (@mishmash) {
    my ( $type, $converter ) = splice( @mishmash, 0, 2 );
    return unless $type->can_be_inlined;
    return unless Types::TypeTiny::StringLike->check($converter);
  }
  return !!1;
}

sub _source_type_union {
  my $self = shift;

  my @r;
  push @r, $self->type_constraint if $self->has_type_constraint;

  my @mishmash = @{ $self->type_coercion_map };
  while (@mishmash) {
    my ($type) = splice( @mishmash, 0, 2 );
    push @r, $type;
  }

  require Type::Tiny::Union;
  return "Type::Tiny::Union"->new( type_constraints => \@r, tmp => 1 );
}

sub inline_coercion {
  my $self    = shift;
  my $varname = $_[0];

  _croak "This coercion cannot be inlined" unless $self->can_be_inlined;

  my @mishmash = @{ $self->type_coercion_map };
  return "($varname)" unless @mishmash;

  my ( @types, @codes );
  while (@mishmash) {
    push @types, shift @mishmash;
    push @codes, shift @mishmash;
  }
  if ( $self->has_type_constraint ) {
    unshift @types, $self->type_constraint;
    unshift @codes, undef;
  }

  my @sub;

  for my $i ( 0 .. $#types ) {
    push @sub, sprintf( '(%s) ?', $types[$i]->inline_check($varname) );
    push @sub,
        ( defined( $codes[$i] ) && ( $varname eq '$_' ) ) ? sprintf( 'scalar(do { %s }) :', $codes[$i] )
      : defined( $codes[$i] )                             ? sprintf( 'scalar(do { local $_ = %s; %s }) :', $varname, $codes[$i] )
      :                                                     sprintf( '%s :', $varname );
  }

  push @sub, "$varname";

  "@sub";
}

sub _build_moose_coercion {
  my $self = shift;

  my %options = ();
  $options{type_coercion_map} = [ $self->freeze->_codelike_type_coercion_map('moose_type') ];
  $options{type_constraint}   = $self->type_constraint if $self->has_type_constraint;

  require Moose::Meta::TypeCoercion;
  my $r = "Moose::Meta::TypeCoercion"->new(%options);

  return $r;
}

sub _codelike_type_coercion_map {
  my $self     = shift;
  my $modifier = $_[0];

  my @orig = @{ $self->type_coercion_map };
  my @new;

  while (@orig) {
    my ( $type, $converter ) = splice( @orig, 0, 2 );

    push @new, $modifier ? $type->$modifier : $type;

    if ( Types::TypeTiny::CodeLike->check($converter) ) {
      push @new, $converter;
    }
    else {
      push @new,
        Eval::TypeTiny::eval_closure(
        source      => sprintf( 'sub { local $_ = $_[0]; %s }',           $converter ),
        description => sprintf( "temporary compiled converter from '%s'", $type ),
        );
    }
  }

  return @new;
}

sub is_parameterizable {
  shift->has_coercion_generator;
}

sub is_parameterized {
  shift->has_parameters;
}

sub parameterize {
  my $self = shift;
  return $self unless @_;
  $self->is_parameterizable
    or _croak "Constraint '%s' does not accept parameters", "$self";

  @_ = map Types::TypeTiny::to_TypeTiny($_), @_;

  return ref($self)->new(
    type_constraint    => $self->type_constraint,
    type_coercion_map  => [ $self->coercion_generator->( $self, $self->type_constraint, @_ ) ],
    parameters         => \@_,
    frozen             => 1,
    parameterized_from => $self,
  );
}

sub _reparameterize {
  my $self = shift;
  my ($target_type) = @_;

  $self->is_parameterized or return $self;
  my $parent = $self->parameterized_from;

  return ref($self)->new(
    type_constraint    => $target_type,
    type_coercion_map  => [ $parent->coercion_generator->( $parent, $target_type, @{ $self->parameters } ) ],
    parameters         => \@_,
    frozen             => 1,
    parameterized_from => $parent,
  );
}

sub isa {
  my $self = shift;

  if ( $INC{"Moose.pm"} and blessed($self) and $_[0] eq 'Moose::Meta::TypeCoercion' ) {
    return !!1;
  }

  if (  $INC{"Moose.pm"}
    and blessed($self)
    and $_[0] =~ /^(Class::MOP|MooseX?)::/ )
  {
    my $r = $self->moose_coercion->isa(@_);
    return $r if $r;
  }

  $self->SUPER::isa(@_);
}

sub can {
  my $self = shift;

  my $can = $self->SUPER::can(@_);
  return $can if $can;

  if (  $INC{"Moose.pm"}
    and blessed($self)
    and my $method = $self->moose_coercion->can(@_) )
  {
    return sub { $method->( shift->moose_coercion, @_ ) };
  }

  return;
}

sub AUTOLOAD {
  my $self = shift;
  my ($m) = ( our $AUTOLOAD =~ /::(\w+)$/ );
  return if $m eq 'DESTROY';

  if ( $INC{"Moose.pm"} and blessed($self) and my $method = $self->moose_coercion->can($m) ) {
    return $method->( $self->moose_coercion, @_ );
  }

  _croak q[Can't locate object method "%s" via package "%s"], $m, ref($self) || $self;
}

# Private Moose method, but Moo uses this...
sub _compiled_type_coercion {
  my $self = shift;
  if (@_) {
    my $thing = $_[0];
    if ( blessed($thing) and $thing->isa("Type::Coercion") ) {
      $self->add_type_coercions( @{ $thing->type_coercion_map } );
    }
    elsif ( Types::TypeTiny::CodeLike->check($thing) ) {
      require Types::Standard;
      $self->add_type_coercions( Types::Standard::Any(), $thing );
    }
  }
  $self->compiled_coercion;
}

*compile_type_coercion = \&compiled_coercion;
sub meta { _croak("Not really a Moose::Meta::TypeCoercion. Sorry!") }

1;

__END__

