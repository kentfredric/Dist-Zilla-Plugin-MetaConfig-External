use strict;
use warnings;

package Pod::Elemental::Selectors;

# ABSTRACT: predicates for selecting elements
$Pod::Elemental::Selectors::VERSION = '0.103004';

#pod =head1 OVERVIEW
#pod
#pod Pod::Elemental::Selectors provides a number of routines to check for
#pod Pod::Elemental paragraphs with given qualities.
#pod
#pod =head1 SELECTORS
#pod
#pod Selectors are predicates:  they examine paragraphs and return either true or
#pod false.  All the selectors have (by default) names like: C<s_whatever>.  They
#pod expect zero or more parameters to affect the selection.  If these parameters
#pod are given, but no paragraph, a callback will be returned that will expect a
#pod paragraph.  If a paragraph is given, the selector will return immediately.
#pod
#pod For example, the C<s_command> selector expects a parameter that can be the name
#pod of the command desired.  Both of the following uses are valid:
#pod
#pod   # create and use a callback:
#pod
#pod   my $selector = s_command('head1');
#pod   my @headers  = grep { $selector->($_) } @paragraphs;
#pod
#pod   # just check a paragraph right now:
#pod
#pod   if ( s_command('head1', $paragraph) ) { ... }
#pod
#pod The selectors can be imported individually or as the C<-all> group, and can be
#pod renamed with L<Sub::Exporter> features.  (Selectors cannot I<yet> be curried by
#pod Sub::Exporter.)
#pod
#pod =cut

use List::Util 1.33 'any';

use Sub::Exporter -setup => { exports => [qw(s_blank s_flat s_node s_command)], };

#pod =head2 s_blank
#pod
#pod   my $callback = s_blank;
#pod
#pod   if( s_blank($para) ) { ... }
#pod
#pod C<s_blank> tests whether a paragraph is a Generic::Blank element.
#pod
#pod =cut

sub s_blank {
  my $code = sub {
    my $para = shift;
    return $para && $para->isa('Pod::Elemental::Element::Generic::Blank');
  };

  return @_ ? $code->(@_) : $code;
}

#pod =head2 s_flat
#pod
#pod   my $callback = s_flat;
#pod
#pod   if( s_flat($para) ) { ... }
#pod
#pod C<s_flat> tests whether a paragraph does Pod::Elemental::Flat -- in other
#pod words, is content-only.
#pod
#pod =cut

sub s_flat {
  my $code = sub {
    my $para = shift;
    return $para && $para->does('Pod::Elemental::Flat');
  };

  return @_ ? $code->(@_) : $code;
}

#pod =head2 s_node
#pod
#pod   my $callback = s_node;
#pod
#pod   if( s_node($para) ) { ... }
#pod
#pod C<s_node> tests whether a paragraph does Pod::Elemental::Node -- in other
#pod words, whether it may have children.
#pod
#pod =cut

sub s_node {
  my $code = sub {
    my $para = shift;
    return $para && $para->does('Pod::Elemental::Node');
  };

  return @_ ? $code->(@_) : $code;
}

#pod =head2 s_command
#pod
#pod   my $callback = s_command;
#pod   my $callback = s_command( $command_name);
#pod   my $callback = s_command(\@command_names);
#pod
#pod   if( s_command(undef, \$para) ) { ... }
#pod
#pod   if( s_command( $command_name,  \$para) ) { ... }
#pod   if( s_command(\@command_names, \$para) ) { ... }
#pod
#pod C<s_command> tests whether a paragraph does Pod::Elemental::Command.  If a
#pod command name (or a reference to an array of command names) is given, the tested
#pod paragraph's command must match one of the given command names.
#pod
#pod =cut

sub s_command {
  my $command = shift;

  my $code = sub {
    my $para = shift;
    return   unless $para && $para->does('Pod::Elemental::Command');
    return 1 unless defined $command;

    my $alts = ref $command ? $command : [$command];
    return any { $para->command eq $_ } @$alts;
  };

  return @_ ? $code->(@_) : $code;
}

1;

__END__

