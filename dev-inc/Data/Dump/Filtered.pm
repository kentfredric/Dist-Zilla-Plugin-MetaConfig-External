package Data::Dump::Filtered;

use Data::Dump ();
use Carp       ();

use base 'Exporter';
our @EXPORT_OK = qw(add_dump_filter remove_dump_filter dump_filtered);

sub add_dump_filter {
  my $filter = shift;
  unless ( ref($filter) eq "CODE" ) {
    Carp::croak("add_dump_filter argument must be a code reference");
  }
  push( @Data::Dump::FILTERS, $filter );
  return $filter;
}

sub remove_dump_filter {
  my $filter = shift;
  @Data::Dump::FILTERS = grep $_ ne $filter, @Data::Dump::FILTERS;
}

sub dump_filtered {
  my $filter = pop;
  if ( defined($filter) && ref($filter) ne "CODE" ) {
    Carp::croak("Last argument to dump_filtered must be undef or a code reference");
  }
  local @Data::Dump::FILTERS = ( $filter ? $filter : () );
  return &Data::Dump::dump;
}

1;

