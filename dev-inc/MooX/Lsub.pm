use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package MooX::Lsub;

our $VERSION = '0.002001';

# ABSTRACT: Very shorthand syntax for bulk lazy builders

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Eval::Closure qw(eval_closure);
use Carp qw(croak);
## no critic (Capitalization,ProhibitConstantPragma,RequireCheckingReturnValueOfEval);
use constant can_haz_subname => eval { require Sub::Util };

## no critic (TestingAndDebugging::ProhibitNoStrict)
sub _get_sub {
  my ( undef, $target, $subname ) = @_;
  no strict 'refs';
  return \&{ $target . q[::] . $subname };
}

sub _set_sub {
  my ( undef, $target, $subname, $code ) = @_;
  no strict 'refs';
  *{ $target . q[::] . $subname } = $code;
  return;
}

sub _set_sub_named {
  my ( undef, $target, $subname, $code ) = @_;
  no strict 'refs';
  *{ $target . q[::] . $subname } = can_haz_subname ? Sub::Util::set_subname( $target . q[::] . $subname, $code ) : $code;
  return;
}
## use critic
#
sub import {
  my ( $class, @args ) = @_;
  my $target = caller;
  my $has    = $class->_get_sub( $target, 'has' );

  croak "No 'has' method in $target. Did you forget to import Moo(se)?" if not $has;

  my $lsub_code = $class->_make_lsub(
    {
      target  => $target,
      has     => $has,
      options => \@args,
    },
  );

  $class->_set_sub( $target, 'lsub', $lsub_code );

  return;
}

sub _make_lsub_code {
  my ( $class, $options ) = @_;
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  my $nl   = qq[\n];
  my $code = 'sub($$) {' . $nl;
  $code .= q[ package ] . $class . q[; ] . $nl;
  $code .= q[ my ( $subname, $sub , @extras ) = @_; ] . $nl;
  $code .= q[ if ( @extras ) { ] . $nl;
  $code .= q[   croak "Too many arguments to 'lsub'. Did you misplace a ';'?"; ] . $nl;
  $code .= q[ } ] . $nl;
  $code .= q[ if ( not defined $subname or not length $subname or ref $subname ) { ] . $nl;
  $code .= q[   croak "Subname must be defined + length + not a ref"; ] . $nl;
  $code .= q[ } ] . $nl;
  $code .= q[ if ( not 'CODE' eq ref $sub ) { ] . $nl;
  $code .= q[   croak "Sub must be a CODE ref"; ] . $nl;
  $code .= q[ } ] . $nl;
  $code .= q[ $class->_set_sub_named($target, "_build_" . $subname , $sub ); ] . $nl;
  $code .= q[ package ] . $options->{'target'} . q[; ] . $nl;
  $code .= q[ return $has->( ] . $nl;
  $code .= q[   $subname, ] . $nl;
  $code .= q[   ( ] . $nl;
  $code .= q[     is => 'ro', ] . $nl;
  $code .= q[     lazy => 1, ] . $nl;
  $code .= q[     builder => '_build_' . $subname, ] . $nl;
  $code .= q[   ) ] . $nl;
  $code .= q[ ); ] . $nl;
  $code .= q[}] . $nl;
  ## use critic
  return $code;
}

sub _make_lsub {
  my ( $class, $options ) = @_;

  my $code = $class->_make_lsub_code($options);

  my $sub = eval_closure(
    source      => $code,
    environment => {
      ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
      '$class'  => \$class,
      '$has'    => \$options->{'has'},
      '$target' => \$options->{'target'},
      ## use critic
    },
  );
  return $sub;
}

1;

__END__

