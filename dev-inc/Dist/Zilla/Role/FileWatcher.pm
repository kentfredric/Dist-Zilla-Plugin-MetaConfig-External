use strict;
use warnings;

package Dist::Zilla::Role::FileWatcher;    # git description: v0.005-17-ge7b35a0

# ABSTRACT: Receive notification when something changes a file's contents
# KEYWORDS: plugin build file change notify checksum watch monitor immutable lock
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.006';

use Moose::Role;
use Safe::Isa;
use Dist::Zilla::Role::File::ChangeNotification;
use namespace::autoclean;

sub watch_file {
  my ( $self, $file, $on_changed ) = @_;

  $file->$_does('Dist::Zilla::Role::File')
    or $self->log_fatal('watch_file was not passed a valid file object');

  Dist::Zilla::Role::File::ChangeNotification->meta->apply($file)
    if not $file->$_does('Dist::Zilla::Role::File::ChangeNotification');

  my $plugin = $self;
  $file->on_changed(
    sub {
      my $self = shift;
      $plugin->$on_changed($self);
    }
  );

  $file->watch_file;
}

sub lock_file {
  my ( $self, $file, $message ) = @_;

  $file->$_does('Dist::Zilla::Role::File')
    or $self->log_fatal('lock_file was not passed a valid file object');

  $message ||=
    'someone tried to munge ' . $file->name . ' after we read from it. You need to adjust the load order of your plugins!';

  $self->watch_file(
    $file,
    sub {
      my $me = shift;
      $me->log_fatal($message);
    },
  );
}

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = { version => __PACKAGE__->VERSION, };

  return $config;
};

1;

__END__

