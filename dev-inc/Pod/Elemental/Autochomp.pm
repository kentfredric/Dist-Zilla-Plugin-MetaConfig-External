package Pod::Elemental::Autochomp;

# ABSTRACT: a paragraph that chomps set content
$Pod::Elemental::Autochomp::VERSION = '0.103004';
use namespace::autoclean;
use Moose::Role;

use Pod::Elemental::Types qw(ChompedString);

#pod =head1 OVERVIEW
#pod
#pod This role exists primarily to simplify elements produced by the Pod5
#pod transformer.
#pod
#pod =cut

# has '+content' => (
#   coerce => 1,
#   isa    => ChompedString,
# );

1;

__END__

