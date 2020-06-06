package Safe::Isa;

use strict;
use warnings FATAL => 'all';
use Scalar::Util ();
use Exporter 5.57 qw(import);

our $VERSION = '1.000008';

our @EXPORT = qw($_call_if_object $_isa $_can $_does $_DOES $_call_if_can);

our $_call_if_object = sub {
  my ( $obj, $method ) = ( shift, shift );

  # This is intentionally a truth test, not a defined test, otherwise
  # we gratuitously break modules like Scalar::Defer, which would be
  # un-perlish.
  return unless Scalar::Util::blessed($obj);
  return $obj->isa(@_) if lc($method) eq 'does' and not $obj->can($method);
  return $obj->$method(@_);
};

our ( $_isa, $_can, $_does, $_DOES ) = map {
  my $method = $_;
  sub { my $obj = shift; $obj->$_call_if_object( $method => @_ ) }
} qw(isa can does DOES);

our $_call_if_can = sub {
  my ( $obj, $method ) = ( shift, shift );
  return unless $obj->$_call_if_object( can => $method );
  return $obj->$method(@_);
};

1;
__END__

