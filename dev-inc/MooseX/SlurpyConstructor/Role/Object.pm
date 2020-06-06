package MooseX::SlurpyConstructor::Role::Object;

our $VERSION = '1.30';

# applied as base_class_roles => [ __PACKAGE__ ], for all Moose versions.
use Moose::Role;

use namespace::autoclean;

after BUILDALL => sub {
  my $self   = shift;
  my $params = shift;

  my %attrs = (
    __INSTANCE__ => 1,
    map    { $_ => 1 }
      grep { defined }
      map  { $_->init_arg } $self->meta->get_all_attributes
  );

  my @extra = sort grep { !$attrs{$_} } keys %{$params};
  return if not @extra;

  # XXX TODO: stuff all these into the slurpy attr.

  # find the slurpy attr
  # TODO: use the metaclass slurpy_attr to find this:
  # if $self->meta->slurpy_attr
  # and then the check for multiple slurpy attrs can be done at
  # composition time.

  my $slurpy_attr = $self->meta->slurpy_attr;

  Moose->throw_error('Found extra construction arguments, but there is no \'slurpy\' attribute present!') if not $slurpy_attr;

  my %slurpy_values;
  @slurpy_values{@extra} = @{$params}{@extra};

  $slurpy_attr->set_value( $self, \%slurpy_values );
};

1;

# ABSTRACT: A role which implements a slurpy constructor for Moose::Object

__END__

