package Pod::Weaver::Plugin::SingleEncoding;

# ABSTRACT: ensure that there is exactly one =encoding of known value
$Pod::Weaver::Plugin::SingleEncoding::VERSION = '4.015';
use Moose;
with( 'Pod::Weaver::Role::Dialect', 'Pod::Weaver::Role::Finalizer', );

use namespace::autoclean;

use Pod::Elemental::Selectors -all;

#pod =head1 OVERVIEW
#pod
#pod The SingleEncoding plugin is a Dialect and a Finalizer.
#pod
#pod During dialect translation, it will look for C<=encoding> directives.  If it
#pod finds them, it will ensure that they all agree on one encoding and remove them.
#pod
#pod During document finalization, it will insert an C<=encoding> directive at the
#pod top of the output, using the encoding previously detected.  If no encoding was
#pod detected, the plugin's C<encoding> attribute will be used instead.  That
#pod defaults to UTF-8.
#pod
#pod If you want to reject any C<=encoding> directive that doesn't match your
#pod expectations, set the C<encoding> attribute by hand.
#pod
#pod No actual validation of the encoding is done.  Pod::Weaver, after all, deals in
#pod text rather than bytes.
#pod
#pod =cut

has encoding => (
  reader    => 'encoding',
  writer    => '_set_encoding',
  isa       => 'Str',
  lazy      => 1,
  default   => 'UTF-8',
  predicate => '_has_encoding',
);

sub translate_dialect {
  my ( $self, $document ) = @_;

  my $want;
  $want = $self->encoding if $self->_has_encoding;
  if ($want) {
    $self->log_debug("enforcing encoding of $want in all pod");
  }

  my $childs = $document->children;
  my $is_enc = s_command( [qw(encoding)] );

  for ( reverse 0 .. $#$childs ) {
    next unless $is_enc->( $childs->[$_] );
    my $have = $childs->[$_]->content;
    $have =~ s/\s+\z//;

    if ( defined $want ) {
      my $ok = lc $have eq lc $want
        || lc $have eq 'utf8' && lc $want eq 'utf-8';
      confess "expected only $want encoding but found $have" unless $ok;
    }
    else {
      $have = 'UTF-8' if lc $have eq 'utf8';
      $self->_set_encoding($have);
      $want = $have;
    }

    splice @$childs, $_, 1;
  }

  return;
}

sub finalize_document {
  my ( $self, $document, $input ) = @_;

  my $encoding = Pod::Elemental::Element::Pod5::Command->new(
    {
      command => 'encoding',
      content => $self->encoding,
    }
  );

  my $childs = $document->children;
  my $is_pod = s_command( [qw(pod)] );    # ??
  for ( 0 .. $#$childs ) {
    next if $is_pod->( $childs->[$_] );
    $self->log_debug( 'setting =encoding to ' . $self->encoding );
    splice @$childs, $_, 0, $encoding;
    last;
  }

  return;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

