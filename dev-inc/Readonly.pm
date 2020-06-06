package Readonly;
use 5.005;
use strict;

#use warnings;
#no warnings 'uninitialized';
package Readonly;
our $VERSION = '2.05';
$VERSION = eval $VERSION;

# Autocroak (Thanks, MJD)
# Only load Carp.pm if module is croaking.
sub croak {
  require Carp;
  goto &Carp::croak;
}

# These functions may be overridden by Readonly::XS, if installed.
use vars qw/$XSokay/;    # Set to true in Readonly::XS, if available

# Predeclare the following, so we can use them recursively
sub _ARRAY (\@);
sub _HASH (\%);

# For perl 5.8.x or higher
# These functions are exposed in perl 5.8.x (Thanks, Leon!)
# They may be overridden by Readonly::XS, if installed on old perl versions
if ( $] < 5.008 ) {    # 'Classic' perl
  *is_sv_readonly   = sub ($) { 0 };
  *make_sv_readonly = sub ($) { die "make_sv_readonly called but not overridden" };

  # See if we can use the XS stuff.
  $Readonly::XS::MAGIC_COOKIE = $Readonly::XS::MAGIC_COOKIE = "Do NOT use or require Readonly::XS unless you're me.";
  eval 'use Readonly::XS';
}
else {                 # Modern perl doesn't need Readonly::XS
  *is_sv_readonly   = sub ($) { Internals::SvREADONLY( $_[0] ) };
  *make_sv_readonly = sub ($) { Internals::SvREADONLY( $_[0], 1 ) };
  $XSokay = 1;         # We're using the new built-ins so this is a white lie
}

# Undo setting readonly
sub _SCALAR ($) {
  my ($r_var) = @_;
  if ($XSokay) {
    Internals::SvREADONLY( $r_var, 0 ) if is_sv_readonly($r_var);
  }
  else {
    return if tied($r_var) !~ 'Readonly::Scalar';
    my $r_scalar;
    {
      my $obj = tied $$r_var;
      $r_scalar = $obj;
    }
    untie $r_var;
    $r_var = $r_scalar;
  }
}

sub _ARRAY (\@) {
  my ($r_var) = @_;
  return if !tied(@$r_var);
  return if tied(@$r_var) !~ 'Readonly::Array';
  my $r_array;
  {
    my $obj = tied @$r_var;
    $r_array = $obj;
  }
  untie @$r_var;
  @$r_var = @$r_array;

  # Recursively check child elements for references; clean if Readonly
  foreach (@$r_var) {
    my $_reftype = ref $_;
    if ( $_reftype eq 'SCALAR' ) { _SCALAR($_) }
    elsif ( $_reftype eq 'ARRAY' ) {
      _ARRAY(@$_);
    }
    elsif ( $_reftype eq 'HASH' ) {
      _HASH(%$_);
    }
  }
}

sub _HASH (\%) {
  my ($r_var) = @_;
  return if !tied(%$r_var);
  return if tied(%$r_var) !~ 'Readonly::Hash';
  my $r_hash;
  {
    my $obj = tied %$r_var;
    $r_hash = $obj;
  }
  untie %$r_var;
  %$r_var = %$r_hash;

  # Recursively check child elements for references; clean if Readonly
  foreach ( values %$r_var ) {
    my $_reftype = ref $_;
    if ( $_reftype eq 'SCALAR' ) { _SCALAR($_) }
    elsif ( $_reftype eq 'ARRAY' ) {
      _ARRAY(@$_);
    }
    elsif ( $_reftype eq 'HASH' ) {
      _HASH(%$_);
    }
  }
}

# Common error messages, or portions thereof
use vars qw/$MODIFY $REASSIGN $ODDHASH/;
$MODIFY   = 'Modification of a read-only value attempted';
$REASSIGN = 'Attempt to reassign a readonly';
$ODDHASH  = 'May not store an odd number of values in a hash';

# ----------------
# Read-only scalars
# ----------------
package Readonly::Scalar;

sub STORABLE_freeze {
  my ( $self, $cloning ) = @_;
  Readonly::_SCALAR($$self) if $cloning;
}

sub TIESCALAR {
  my $whence = ( caller 2 )[3];    # Check if naughty user is trying to tie directly.
  Readonly::croak "Invalid tie"
    unless $whence && $whence =~ /^Readonly::(?:Scalar1?|Readonly)$/;
  my $class = shift;
  Readonly::croak "No value specified for readonly scalar" unless @_;
  Readonly::croak "Too many values specified for readonly scalar"
    unless @_ == 1;
  my $value = shift;
  return bless \$value, $class;
}

sub FETCH {
  my $self = shift;
  return $$self;
}
*STORE = *STORE = sub { Readonly::croak $Readonly::MODIFY };
*UNTIE = *UNTIE = sub { Readonly::croak $Readonly::MODIFY if caller() ne 'Readonly' };

# ----------------
# Read-only arrays
# ----------------
package Readonly::Array;

sub STORABLE_freeze {
  my ( $self, $cloning ) = @_;
  Readonly::_ARRAY(@$self) if $cloning;
}

sub TIEARRAY {
  my $whence = ( caller 1 )[3];    # Check if naughty user is trying to tie directly.
  Readonly::croak "Invalid tie" unless $whence =~ /^Readonly::Array1?$/;
  my $class = shift;
  my @self  = @_;
  return bless \@self, $class;
}

sub FETCH {
  my $self  = shift;
  my $index = shift;
  return $self->[$index];
}

sub FETCHSIZE {
  my $self = shift;
  return scalar @$self;
}

BEGIN {
  eval q{
        sub EXISTS
           {
           my $self  = shift;
           my $index = shift;
           return exists $self->[$index];
           }
    } if $] >= 5.006;    # couldn't do "exists" on arrays before then
}
*STORE = *STORESIZE = *EXTEND = *PUSH = *POP = *UNSHIFT = *SHIFT = *SPLICE = *CLEAR = *STORE = *STORESIZE = *EXTEND = *PUSH =
  *POP = *UNSHIFT = *SHIFT = *SPLICE = *CLEAR = sub { Readonly::croak $Readonly::MODIFY};
*UNTIE = *UNTIE = sub { Readonly::croak $Readonly::MODIFY if caller() ne 'Readonly' };

# ----------------
# Read-only hashes
# ----------------
package Readonly::Hash;

sub STORABLE_freeze {
  my ( $self, $cloning ) = @_;
  Readonly::_HASH(%$self) if $cloning;
}

sub TIEHASH {
  my $whence = ( caller 1 )[3];    # Check if naughty user is trying to tie directly.
  Readonly::croak "Invalid tie" unless $whence =~ /^Readonly::Hash1?$/;
  my $class = shift;

  # must have an even number of values
  Readonly::croak $Readonly::ODDHASH unless ( @_ % 2 == 0 );
  my %self = @_;
  return bless \%self, $class;
}

sub FETCH {
  my $self = shift;
  my $key  = shift;
  return $self->{$key};
}

sub EXISTS {
  my $self = shift;
  my $key  = shift;
  return exists $self->{$key};
}

sub FIRSTKEY {
  my $self  = shift;
  my $dummy = keys %$self;
  return scalar each %$self;
}

sub NEXTKEY {
  my $self = shift;
  return scalar each %$self;
}
*STORE = *DELETE = *CLEAR = *STORE = *DELETE = *CLEAR = sub { Readonly::croak $Readonly::MODIFY};
*UNTIE = *UNTIE  = sub                                      { Readonly::croak $Readonly::MODIFY if caller() ne 'Readonly'; };

# ----------------------------------------------------------------
# Main package, containing convenience functions (so callers won't
# have to explicitly tie the variables themselves).
# ----------------------------------------------------------------
package Readonly;
use Exporter;
use vars qw/@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
push @ISA,       'Exporter';
push @EXPORT,    qw/Readonly/;
push @EXPORT_OK, qw/Scalar Array Hash Scalar1 Array1 Hash1/;

# Predeclare the following, so we can use them recursively
sub Scalar ($$);
sub Array (\@;@);
sub Hash (\%;@);

# Returns true if a string begins with "Readonly::"
# Used to prevent reassignment of Readonly variables.
sub _is_badtype {
  my $type = $_[0];
  return lc $type if $type =~ s/^Readonly:://;
  return;
}

# Shallow Readonly scalar
sub Scalar1 ($$) {
  croak "$REASSIGN scalar" if is_sv_readonly( $_[0] );
  my $badtype = _is_badtype( ref tied $_[0] );
  croak "$REASSIGN $badtype" if $badtype;

  # xs method: flag scalar as readonly
  if ($XSokay) {
    $_[0] = $_[1];
    make_sv_readonly( $_[0] );
    return;
  }

  # pure-perl method: tied scalar
  my $tieobj = eval { tie $_[0], 'Readonly::Scalar', $_[1] };
  if ($@) {
    croak "$REASSIGN scalar" if substr( $@, 0, 43 ) eq $MODIFY;
    die $@;    # some other error?
  }
  return $tieobj;
}

# Shallow Readonly array
sub Array1 (\@;@) {
  my $badtype = _is_badtype( ref tied $_[0] );
  croak "$REASSIGN $badtype" if $badtype;
  my $aref = shift;
  return tie @$aref, 'Readonly::Array', @_;
}

# Shallow Readonly hash
sub Hash1 (\%;@) {
  my $badtype = _is_badtype( ref tied $_[0] );
  croak "$REASSIGN $badtype" if $badtype;
  my $href = shift;

  # If only one value, and it's a hashref, expand it
  if ( @_ == 1 && ref $_[0] eq 'HASH' ) {
    return tie %$href, 'Readonly::Hash', %{ $_[0] };
  }

  # otherwise, must have an even number of values
  croak $ODDHASH unless ( @_ % 2 == 0 );
  return tie %$href, 'Readonly::Hash', @_;
}

# Deep Readonly scalar
sub Scalar ($$) {
  croak "$REASSIGN scalar" if is_sv_readonly( $_[0] );
  my $badtype = _is_badtype( ref tied $_[0] );
  croak "$REASSIGN $badtype" if $badtype;
  my $value = $_[1];

  # Recursively check passed element for references; if any, make them Readonly
  foreach ($value) {
    if    ( ref eq 'SCALAR' ) { Scalar my $v => $$_; $_ = \$v }
    elsif ( ref eq 'ARRAY' )  { Array my @v  => @$_; $_ = \@v }
    elsif ( ref eq 'HASH' )   { Hash my %v   => $_;  $_ = \%v }
  }

  # xs method: flag scalar as readonly
  if ($XSokay) {
    $_[0] = $value;
    make_sv_readonly( $_[0] );
    return;
  }

  # pure-perl method: tied scalar
  my $tieobj = eval { tie $_[0], 'Readonly::Scalar', $value };
  if ($@) {
    croak "$REASSIGN scalar" if substr( $@, 0, 43 ) eq $MODIFY;
    die $@;    # some other error?
  }
  return $tieobj;
}

# Deep Readonly array
sub Array (\@;@) {
  my $badtype = _is_badtype( ref tied @{ $_[0] } );
  croak "$REASSIGN $badtype" if $badtype;
  my $aref   = shift;
  my @values = @_;

  # Recursively check passed elements for references; if any, make them Readonly
  foreach (@values) {
    if    ( ref eq 'SCALAR' ) { Scalar my $v => $$_; $_ = \$v }
    elsif ( ref eq 'ARRAY' )  { Array my @v  => @$_; $_ = \@v }
    elsif ( ref eq 'HASH' )   { Hash my %v   => $_;  $_ = \%v }
  }

  # Lastly, tie the passed reference
  return tie @$aref, 'Readonly::Array', @values;
}

# Deep Readonly hash
sub Hash (\%;@) {
  my $badtype = _is_badtype( ref tied %{ $_[0] } );
  croak "$REASSIGN $badtype" if $badtype;
  my $href   = shift;
  my @values = @_;

  # If only one value, and it's a hashref, expand it
  if ( @_ == 1 && ref $_[0] eq 'HASH' ) {
    @values = %{ $_[0] };
  }

  # otherwise, must have an even number of values
  croak $ODDHASH unless ( @values % 2 == 0 );

  # Recursively check passed elements for references; if any, make them Readonly
  foreach (@values) {
    if    ( ref eq 'SCALAR' ) { Scalar my $v => $$_; $_ = \$v }
    elsif ( ref eq 'ARRAY' )  { Array my @v  => @$_; $_ = \@v }
    elsif ( ref eq 'HASH' )   { Hash my %v   => $_;  $_ = \%v }
  }
  return tie %$href, 'Readonly::Hash', @values;
}

sub Clone(\[$@%]) {
  require Storable;
  my $retval = Storable::dclone( $_[0] );
  $retval = $$retval if ref $retval eq 'REF';
  my $reftype = ref $retval;
  if ( $reftype eq 'SCALAR' ) {
    _SCALAR($retval);
    return $$retval;
  }
  elsif ( $reftype eq 'ARRAY' ) {
    _ARRAY(@$retval);
  }
  elsif ( $reftype eq 'HASH' ) {
    _HASH(%$retval);
    return %$retval if wantarray;
  }
  return $retval;
}

# Common entry-point for all supported data types
eval q{sub Readonly} . ( $] < 5.008 ? '' : '(\[$@%]@)' ) . <<'SUB_READONLY';
{
    if (ref $_[0] eq 'SCALAR')
    {
        croak $MODIFY if is_sv_readonly ${$_[0]};
        my $badtype = _is_badtype (ref tied ${$_[0]});
        croak "$REASSIGN $badtype" if $badtype;
        croak "Readonly scalar must have only one value" if @_ > 2;

        # Because of problems with handling \$ prototypes declarations like
        # Readonly my @a = ... and Readonly my %h = ... are also caught here
        croak 'Invalid initialization by assignment'
            if @_ == 1 && defined ${$_[0]};

        my $tieobj = eval {tie ${$_[0]}, 'Readonly::Scalar', $_[1]};
        # Tie may have failed because user tried to tie a constant, or we screwed up somehow.
        if ($@)
        {
            croak $MODIFY if $@ =~ /^$MODIFY at/;    # Point the finger at the user.
            die "$@\n";        # Not a modify read-only message; must be our fault.
        }
        return $tieobj;
    }
    elsif (ref $_[0] eq 'ARRAY')
    {
        my $aref = shift;
        return Array @$aref, @_;
    }
    elsif (ref $_[0] eq 'HASH')
    {
        my $href = shift;
        croak $ODDHASH  if @_%2 != 0  &&  !(@_ == 1  && ref $_[0] eq 'HASH');
        return Hash %$href, @_;
    }
    elsif (ref $_[0])
    {
        croak "Readonly only supports scalar, array, and hash variables.";
    }
    else
    {
        croak "First argument to Readonly must be a reference.";
    }
}
SUB_READONLY
1;

