package Perl::Critic::Utils::PPI;

use 5.006001;
use strict;
use warnings;

use Readonly;

use Scalar::Util qw< blessed readonly >;

use Exporter 'import';

our $VERSION = '1.130';

#-----------------------------------------------------------------------------

our @EXPORT_OK = qw(
  is_ppi_expression_or_generic_statement
  is_ppi_generic_statement
  is_ppi_statement_subclass
  is_ppi_simple_statement
  is_ppi_constant_element
  is_subroutine_declaration
  is_in_subroutine
  get_constant_name_element_from_declaring_statement
  get_next_element_in_same_simple_statement
  get_previous_module_used_on_same_line
);

our %EXPORT_TAGS = ( all => \@EXPORT_OK, );

#-----------------------------------------------------------------------------

sub is_ppi_expression_or_generic_statement {
  my $element = shift;

  return   if not $element;
  return   if not $element->isa('PPI::Statement');
  return 1 if $element->isa('PPI::Statement::Expression');

  my $element_class = blessed($element);

  return if not $element_class;
  return $element_class eq 'PPI::Statement';
}

#-----------------------------------------------------------------------------

sub is_ppi_generic_statement {
  my $element = shift;

  my $element_class = blessed($element);

  return if not $element_class;
  return if not $element->isa('PPI::Statement');

  return $element_class eq 'PPI::Statement';
}

#-----------------------------------------------------------------------------

sub is_ppi_statement_subclass {
  my $element = shift;

  my $element_class = blessed($element);

  return if not $element_class;
  return if not $element->isa('PPI::Statement');

  return $element_class ne 'PPI::Statement';
}

#-----------------------------------------------------------------------------

# Can not use hashify() here because Perl::Critic::Utils already depends on
# this module.
Readonly::Hash my %SIMPLE_STATEMENT_CLASS => map { $_ => 1 } qw<
  PPI::Statement
  PPI::Statement::Break
  PPI::Statement::Include
  PPI::Statement::Null
  PPI::Statement::Package
  PPI::Statement::Variable
>;

sub is_ppi_simple_statement {
  my $element = shift or return;

  my $element_class = blessed($element) or return;

  return $SIMPLE_STATEMENT_CLASS{$element_class};
}

#-----------------------------------------------------------------------------

sub is_ppi_constant_element {
  my $element = shift or return;

  blessed($element) or return;

  # TODO implement here documents once PPI::Token::HereDoc grows the
  # necessary PPI::Token::Quote interface.
  return
       $element->isa('PPI::Token::Number')
    || $element->isa('PPI::Token::Quote::Literal')
    || $element->isa('PPI::Token::Quote::Single')
    || $element->isa('PPI::Token::QuoteLike::Words')
    || ( $element->isa('PPI::Token::Quote::Double')
    || $element->isa('PPI::Token::Quote::Interpolate') )
    && $element->string() !~ m< (?: \A | [^\\] ) (?: \\\\)* [\$\@] >smx;
}

#-----------------------------------------------------------------------------

sub is_subroutine_declaration {
  my $element = shift;

  return if not $element;

  return 1 if $element->isa('PPI::Statement::Sub');

  if ( is_ppi_generic_statement($element) ) {
    my $first_element = $element->first_element();

    return 1
      if $first_element
      and $first_element->isa('PPI::Token::Word')
      and $first_element->content() eq 'sub';
  }

  return;
}

#-----------------------------------------------------------------------------

sub is_in_subroutine {
  my ($element) = @_;

  return   if not $element;
  return 1 if is_subroutine_declaration($element);

  while ( $element = $element->parent() ) {
    return 1 if is_subroutine_declaration($element);
  }

  return;
}

#-----------------------------------------------------------------------------

sub get_constant_name_element_from_declaring_statement {
  my ($element) = @_;

  warnings::warnif(
    'deprecated',
'Perl::Critic::Utils::PPI::get_constant_name_element_from_declaring_statement() is deprecated. Use PPIx::Utilities::Statement::get_constant_name_elements_from_declaring_statement() instead.',
  );

  return if not $element;
  return if not $element->isa('PPI::Statement');

  if ( $element->isa('PPI::Statement::Include') ) {
    my $pragma;
    if ( $pragma = $element->pragma() and $pragma eq 'constant' ) {
      return _constant_name_from_constant_pragma($element);
    }
  }
  elsif ( is_ppi_generic_statement($element)
    and $element->schild(0)->content() =~ m< \A Readonly \b >xms )
  {
    return $element->schild(2);
  }

  return;
}

sub _constant_name_from_constant_pragma {
  my ($include) = @_;

  my @arguments = $include->arguments() or return;

  my $follower = $arguments[0];
  return if not defined $follower;

  return $follower;
}

#-----------------------------------------------------------------------------

sub get_next_element_in_same_simple_statement {
  my $element = shift or return;

  while (
    $element
    and ( not is_ppi_simple_statement($element)
      or $element->parent() and $element->parent()->isa('PPI::Structure::List') )
    )
  {
    my $next;
    $next    = $element->snext_sibling() and return $next;
    $element = $element->parent();
  }
  return;

}

#-----------------------------------------------------------------------------

sub get_previous_module_used_on_same_line {
  my $element = shift or return;

  my ($line) = @{ $element->location() || [] };

  while ( not is_ppi_simple_statement($element) ) {
    $element = $element->parent() or return;
  }

  while ( $element = $element->sprevious_sibling() ) {
    ( @{ $element->location() || [] } )[0] == $line or return;
    $element->isa('PPI::Statement::Include')
      and return $element->schild(1);
  }

  return;
}

#-----------------------------------------------------------------------------

1;

__END__


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 ft=perl expandtab shiftround :
