package Perl::Critic::Exception::Fatal;

use 5.006001;
use strict;
use warnings;

our $VERSION = '1.130';

#-----------------------------------------------------------------------------

use Exception::Class (
  'Perl::Critic::Exception::Fatal' => {
    isa         => 'Perl::Critic::Exception',
    description => 'A problem that should cause Perl::Critic to stop running.',
  },
);

#-----------------------------------------------------------------------------

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);

  $self->show_trace(1);

  return $self;
}

#-----------------------------------------------------------------------------

sub full_message {
  my ($self) = @_;

  return
      $self->short_class_name() . q{: }
    . $self->description() . "\n\n"
    . $self->message() . "\n\n"
    . gmtime $self->time() . "\n\n";
}

1;

__END__

#-----------------------------------------------------------------------------


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 ft=perl expandtab shiftround :
