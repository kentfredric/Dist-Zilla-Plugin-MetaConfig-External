package Pod::Weaver::Config;

# ABSTRACT: stored configuration loader role
$Pod::Weaver::Config::VERSION = '4.015';
use Moose::Role;

use Config::MVP 2;
use Pod::Weaver::Config::Assembler;

use namespace::autoclean;

#pod =head1 DESCRIPTION
#pod
#pod The config role provides some helpers for writing a configuration loader using
#pod the L<Config::MVP|Config::MVP> system to load and validate its configuration.
#pod
#pod =attr assembler
#pod
#pod The L<assembler> attribute must be a Config::MVP::Assembler, has a sensible
#pod default that will handle the standard needs of a config loader.  Namely, it
#pod will be pre-loaded with a starting section for root configuration.
#pod
#pod =cut

sub build_assembler {
  my $assembler = Pod::Weaver::Config::Assembler->new;

  my $root = $assembler->section_class->new(
    {
      name => '_',
    }
  );

  $assembler->sequence->add_section($root);

  return $assembler;
}

1;

__END__

