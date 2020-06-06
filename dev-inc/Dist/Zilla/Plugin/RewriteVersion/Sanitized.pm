use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::RewriteVersion::Sanitized;

our $VERSION = '0.001006';

# ABSTRACT: RewriteVersion but force normalizing ENV{V} and other sources.

our $AUTHORITY = 'cpan:KENTNL';    # AUTHORITY

use Moose qw( extends with );

extends 'Dist::Zilla::Plugin::RewriteVersion';
with 'Dist::Zilla::Role::Version::Sanitize';

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

