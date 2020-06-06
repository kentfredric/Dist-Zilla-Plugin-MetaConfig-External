package Type::Tiny::Role;

use 5.006001;
use strict;
use warnings;

BEGIN {
  $Type::Tiny::Role::AUTHORITY = 'cpan:TOBYINK';
  $Type::Tiny::Role::VERSION   = '1.002001';
}

use Scalar::Util qw< blessed weaken >;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

require Type::Tiny;
our @ISA = 'Type::Tiny';

my %cache;

sub new {
  my $proto = shift;

  my %opts = ( @_ == 1 ) ? %{ $_[0] } : @_;
  _croak "Role type constraints cannot have a parent constraint passed to the constructor"  if exists $opts{parent};
  _croak "Role type constraints cannot have a constraint coderef passed to the constructor" if exists $opts{constraint};
  _croak "Role type constraints cannot have a inlining coderef passed to the constructor"   if exists $opts{inlined};
  _croak "Need to supply role name" unless exists $opts{role};

  return $proto->SUPER::new(%opts);
}

sub role    { $_[0]{role} }
sub inlined { $_[0]{inlined} ||= $_[0]->_build_inlined }

sub has_inlined { !!1 }

sub _build_constraint {
  my $self = shift;
  my $role = $self->role;
  return sub {
    blessed($_) and do { my $method = $_->can('DOES') || $_->can('isa'); $_->$method($role) }
  };
}

sub _build_inlined {
  my $self = shift;
  my $role = $self->role;
  sub {
    my $var = $_[1];
    qq{Scalar::Util::blessed($var) and do { my \$method = $var->can('DOES')||$var->can('isa'); $var->\$method(q[$role]) }};
  };
}

sub _build_default_message {
  my $self = shift;
  my $c    = $self->role;
  return sub { sprintf '%s did not pass type constraint (not DOES %s)', Type::Tiny::_dd( $_[0] ), $c }
    if $self->is_anon;
  my $name = "$self";
  return sub { sprintf '%s did not pass type constraint "%s" (not DOES %s)', Type::Tiny::_dd( $_[0] ), $name, $c };
}

sub has_parent {
  !!1;
}

sub parent {
  require Types::Standard;
  Types::Standard::Object();
}

sub validate_explain {
  my $self = shift;
  my ( $value, $varname ) = @_;
  $varname = '$_' unless defined $varname;

  return undef if $self->check($value);
  return ["Not a blessed reference"] unless blessed($value);
  return ["Reference provides no DOES method to check roles"] unless $value->can('DOES');

  my $display_var = $varname eq q{$_} ? '' : sprintf( ' (in %s)', $varname );

  return [
    sprintf( '"%s" requires that the reference does %s', $self,        $self->role ),
    sprintf( "The reference%s doesn't %s",               $display_var, $self->role ),
  ];
}

1;

__END__

