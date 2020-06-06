use strict;
use warnings;

package Dist::Zilla::Role::File::ChangeNotification;

# ABSTRACT: Receive notification when something changes a file's contents
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.006';

use Moose::Role;
use Digest::MD5 'md5_hex';
use Encode 'encode_utf8';
use namespace::autoclean;

has _content_checksum => ( is => 'rw', isa => 'Str' );

has on_changed => (
  isa     => 'ArrayRef[CodeRef]',
  traits  => ['Array'],
  handles => {
    _add_on_changed  => 'push',
    _on_changed_subs => 'elements',
  },
  lazy    => 1,
  default => sub { [] },
);

sub on_changed {
  my ( $self, $watch_sub ) = @_;
  $self->_add_on_changed(
    $watch_sub || sub {
      my ( $file, $new_content ) = @_;
      die 'content of ', $file->name, ' has changed!';
    }
  );
}

sub watch_file {
  my $self = shift;

  $self->on_changed if not $self->_on_changed_subs;
  return            if $self->_content_checksum;

  # Storing a checksum initiates the "watch" process
  $self->_content_checksum( $self->__calculate_checksum );
  return;
}

sub __calculate_checksum {
  my $self = shift;

  # this may not be the correct encoding, but things should work out okay
  # anyway - all we care about is deterministically getting bytes back
  md5_hex( encode_utf8( $self->content ) );
}

around content => sub {
  my $orig = shift;
  my $self = shift;

  # pass through if getter
  return $self->$orig if @_ < 1;

  # store the new content
  # XXX possible TODO: do not set the new content until after the callback
  # is invoked. Talk to me if you care about this in either direction!
  my $content = shift;
  $self->$orig($content);

  my $old_checksum = $self->_content_checksum;

  # do nothing extra if we haven't got a checksum yet
  return $content if not $old_checksum;

  # ...or if the content hasn't actually changed
  my $new_checksum = $self->__calculate_checksum;
  return $content if $old_checksum eq $new_checksum;

  # update the checksum to reflect the new content
  $self->_content_checksum($new_checksum);

  # invoke the callback
  $self->_has_changed($content);

  return $self->content;
};

sub _has_changed {
  my ( $self, @args ) = @_;

  $self->$_(@args) for $self->_on_changed_subs;
}

1;

__END__

