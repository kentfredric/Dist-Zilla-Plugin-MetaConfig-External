package MooseX::SlurpyConstructor;    # git description: 1.2-17-g7df5114

use strict;
use warnings;

our $VERSION = '1.30';

use Moose 0.94 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use MooseX::SlurpyConstructor::Role::Object;
use MooseX::SlurpyConstructor::Trait::Class;
use MooseX::SlurpyConstructor::Trait::Attribute;

{
  my %meta_stuff = (
    base_class_roles => ['MooseX::SlurpyConstructor::Role::Object'],
    class_metaroles  => {
      class     => ['MooseX::SlurpyConstructor::Trait::Class'],
      attribute => ['MooseX::SlurpyConstructor::Trait::Attribute'],
    },
  );

  if ( Moose->VERSION < 1.9900 ) {
    require MooseX::SlurpyConstructor::Trait::Method::Constructor;
    push @{ $meta_stuff{class_metaroles}{constructor} }, 'MooseX::SlurpyConstructor::Trait::Method::Constructor';
  }
  else {
    push @{ $meta_stuff{class_metaroles}{class} },               'MooseX::SlurpyConstructor::Trait::Class';
    push @{ $meta_stuff{role_metaroles}{role} },                 'MooseX::SlurpyConstructor::Trait::Role';
    push @{ $meta_stuff{role_metaroles}{application_to_class} }, 'MooseX::SlurpyConstructor::Trait::ApplicationToClass';
    push @{ $meta_stuff{role_metaroles}{application_to_role} },  'MooseX::SlurpyConstructor::Trait::ApplicationToRole';
    push @{ $meta_stuff{role_metaroles}{applied_attribute} },    'MooseX::SlurpyConstructor::Trait::Attribute';
  }

  Moose::Exporter->setup_import_methods( %meta_stuff, );
}

1;

# ABSTRACT: Make your object constructor collect all unknown attributes

__END__

