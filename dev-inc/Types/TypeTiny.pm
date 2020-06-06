package Types::TypeTiny;

use strict;
use warnings;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '1.002001';

use Scalar::Util qw< blessed refaddr weaken >;

our @EXPORT_OK = ( __PACKAGE__->type_names, qw/to_TypeTiny/ );

my %cache;

sub import {

  # do the shuffle!
  no warnings "redefine";
  our @ISA = qw( Exporter::Tiny );
  require Exporter::Tiny;
  my $next = \&Exporter::Tiny::import;
  *import = $next;
  my $class = shift;
  my $opts  = { ref( $_[0] ) ? %{ +shift } : () };
  $opts->{into} ||= scalar(caller);
  return $class->$next( $opts, @_ );
}

sub meta {
  return $_[0];
}

sub type_names {
  qw( CodeLike StringLike TypeTiny HashLike ArrayLike );
}

sub has_type {
  my %has = map +( $_ => 1 ), shift->type_names;
  !!$has{ $_[0] };
}

sub get_type {
  my $self = shift;
  return unless $self->has_type(@_);
  no strict qw(refs);
  &{ $_[0] }();
}

sub coercion_names {
  qw();
}

sub has_coercion {
  my %has = map +( $_ => 1 ), shift->coercion_names;
  !!$has{ $_[0] };
}

sub get_coercion {
  my $self = shift;
  return unless $self->has_coercion(@_);
  no strict qw(refs);
  &{ $_[0] }();    # uncoverable statement
}

sub StringLike () {
  require Type::Tiny;
  $cache{StringLike} ||= "Type::Tiny"->new(
    name       => "StringLike",
    constraint => sub { defined($_) && !ref($_) or Scalar::Util::blessed($_) && overload::Method( $_, q[""] ) },
    inlined    => sub { qq/defined($_[1]) && !ref($_[1]) or Scalar::Util::blessed($_[1]) && overload::Method($_[1], q[""])/ },
    library    => __PACKAGE__,
  );
}

sub HashLike () {
  require Type::Tiny;
  $cache{HashLike} ||= "Type::Tiny"->new(
    name       => "HashLike",
    constraint => sub { ref($_) eq q[HASH] or Scalar::Util::blessed($_) && overload::Method( $_, q[%{}] ) },
    inlined    => sub { qq/ref($_[1]) eq q[HASH] or Scalar::Util::blessed($_[1]) && overload::Method($_[1], q[\%{}])/ },
    library    => __PACKAGE__,
  );
}

sub ArrayLike () {
  require Type::Tiny;
  $cache{ArrayLike} ||= "Type::Tiny"->new(
    name       => "ArrayLike",
    constraint => sub { ref($_) eq q[ARRAY] or Scalar::Util::blessed($_) && overload::Method( $_, q[@{}] ) },
    inlined    => sub { qq/ref($_[1]) eq q[ARRAY] or Scalar::Util::blessed($_[1]) && overload::Method($_[1], q[\@{}])/ },
    library    => __PACKAGE__,
  );
}

sub CodeLike () {
  require Type::Tiny;
  $cache{CodeLike} ||= "Type::Tiny"->new(
    name       => "CodeLike",
    constraint => sub { ref($_) eq q[CODE] or Scalar::Util::blessed($_) && overload::Method( $_, q[&{}] ) },
    inlined    => sub { qq/ref($_[1]) eq q[CODE] or Scalar::Util::blessed($_[1]) && overload::Method($_[1], q[\&{}])/ },
    library    => __PACKAGE__,
  );
}

sub TypeTiny () {
  require Type::Tiny;
  $cache{TypeTiny} ||= "Type::Tiny"->new(
    name       => "TypeTiny",
    constraint => sub { Scalar::Util::blessed($_) && $_->isa(q[Type::Tiny]) },
    inlined    => sub { my $var = $_[1]; "Scalar::Util::blessed($var) && $var\->isa(q[Type::Tiny])" },
    library    => __PACKAGE__,
  );
}

my %ttt_cache;

sub to_TypeTiny {
  my $t = $_[0];

  return $t unless ( my $ref = ref $t );
  return $t if $ref =~ /^Type::Tiny\b/;

  return $ttt_cache{ refaddr($t) } if $ttt_cache{ refaddr($t) };

  if ( my $class = blessed $t) {
    return $t                               if $class->isa("Type::Tiny");
    return _TypeTinyFromMoose($t)           if $class->isa("Moose::Meta::TypeConstraint");
    return _TypeTinyFromMoose($t)           if $class->isa("MooseX::Types::TypeDecorator");
    return _TypeTinyFromValidationClass($t) if $class->isa("Validation::Class::Simple");
    return _TypeTinyFromValidationClass($t) if $class->isa("Validation::Class");
    return _TypeTinyFromGeneric($t)         if $t->can("check") && $t->can("get_message");    # i.e. Type::API::Constraint
  }

  return _TypeTinyFromCodeRef($t) if $ref eq q(CODE);

  $t;
}

sub _TypeTinyFromMoose {
  my $t = $_[0];

  if ( ref $t->{"Types::TypeTiny::to_TypeTiny"} ) {
    return $t->{"Types::TypeTiny::to_TypeTiny"};
  }

  if ( $t->name ne '__ANON__' ) {
    require Types::Standard;
    my $ts = 'Types::Standard'->get_type( $t->name );
    return $ts if $ts->{_is_core};
  }

  my %opts;
  $opts{display_name} = $t->name;
  $opts{constraint}   = $t->constraint;
  $opts{parent}       = to_TypeTiny( $t->parent ) if $t->has_parent;
  $opts{inlined}      = sub { shift; $t->_inline_check(@_) }
    if $t->can("can_be_inlined") && $t->can_be_inlined;
  $opts{message} = sub { $t->get_message($_) }
    if $t->has_message;
  $opts{moose_type} = $t;

  require Type::Tiny;
  my $new = 'Type::Tiny'->new(%opts);
  $ttt_cache{ refaddr($t) } = $new;
  weaken( $ttt_cache{ refaddr($t) } );

  $new->{coercion} = do {
    require Type::Coercion::FromMoose;
    'Type::Coercion::FromMoose'->new(
      type_constraint => $new,
      moose_coercion  => $t->coercion,
    );
  } if $t->has_coercion;

  return $new;
}

sub _TypeTinyFromValidationClass {
  my $t = $_[0];

  require Type::Tiny;
  require Types::Standard;

  my %opts = (
    parent            => Types::Standard::HashRef(),
    _validation_class => $t,
  );

  if ( $t->VERSION >= "7.900048" ) {
    $opts{constraint} = sub {
      $t->params->clear;
      $t->params->add(%$_);
      my $f = $t->filtering;
      $t->filtering('off');
      my $r = eval { $t->validate };
      $t->filtering( $f || 'pre' );
      return $r;
    };
    $opts{message} = sub {
      $t->params->clear;
      $t->params->add(%$_);
      my $f = $t->filtering;
      $t->filtering('off');
      my $r = ( eval { $t->validate } ? "OK" : $t->errors_to_string );
      $t->filtering( $f || 'pre' );
      return $r;
    };
  }
  else    # need to use hackish method
  {
    $opts{constraint} = sub {
      $t->params->clear;
      $t->params->add(%$_);
      no warnings "redefine";
      local *Validation::Class::Directive::Filters::execute_filtering = sub { $_[0] };
      eval { $t->validate };
    };
    $opts{message} = sub {
      $t->params->clear;
      $t->params->add(%$_);
      no warnings "redefine";
      local *Validation::Class::Directive::Filters::execute_filtering = sub { $_[0] };
      eval { $t->validate } ? "OK" : $t->errors_to_string;
    };
  }

  require Type::Tiny;
  my $new = "Type::Tiny"->new(%opts);

  $new->coercion->add_type_coercions(
    Types::Standard::HashRef() => sub {
      my %params = %$_;
      for my $k ( keys %params ) { delete $params{$_} unless $t->get_fields($k) }
      $t->params->clear;
      $t->params->add(%params);
      eval { $t->validate };
      $t->get_hash;
    },
  );

  $ttt_cache{ refaddr($t) } = $new;
  weaken( $ttt_cache{ refaddr($t) } );
  return $new;
}

sub _TypeTinyFromGeneric {
  my $t = $_[0];

  # XXX - handle inlining??

  my %opts = (
    constraint => sub { $t->check( @_       ? @_ : $_ ) },
    message    => sub { $t->get_message( @_ ? @_ : $_ ) },
  );

  $opts{display_name} = $t->name if $t->can("name");

  $opts{coercion} = sub { $t->coerce( @_ ? @_ : $_ ) }
    if $t->can("has_coercion") && $t->has_coercion && $t->can("coerce");

  require Type::Tiny;
  my $new = "Type::Tiny"->new(%opts);
  $ttt_cache{ refaddr($t) } = $new;
  weaken( $ttt_cache{ refaddr($t) } );
  return $new;
}

my $QFS;

sub _TypeTinyFromCodeRef {
  my $t = $_[0];

  my %opts = (
    constraint => sub {
      return !!eval { $t->($_) };
    },
    message => sub {
      local $@;
      eval { $t->($_); 1 } or do { chomp $@; return $@ if $@ };
      return sprintf( '%s did not pass type constraint', Type::Tiny::_dd($_) );
    },
  );

  if ( $QFS ||= "Sub::Quote"->can("quoted_from_sub") ) {
    my ( undef, $perlstring, $captures ) = @{ $QFS->($t) || [] };
    if ($perlstring) {
      $perlstring = "!!eval{ $perlstring }";
      $opts{inlined} = sub {
        my $var = $_[1];
        Sub::Quote::inlinify( $perlstring, $var, $var eq q($_) ? '' : "local \$_ = $var;", 1, );
        }
        if $perlstring && !$captures;
    }
  }

  require Type::Tiny;
  my $new = "Type::Tiny"->new(%opts);
  $ttt_cache{ refaddr($t) } = $new;
  weaken( $ttt_cache{ refaddr($t) } );
  return $new;
}

1;

__END__

