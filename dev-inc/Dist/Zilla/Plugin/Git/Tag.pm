#
# This file is part of Dist-Zilla-Plugin-Git
#
# This software is copyright (c) 2009 by Jerome Quelin.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use 5.008;
use strict;
use warnings;

package Dist::Zilla::Plugin::Git::Tag;

# ABSTRACT: Tag the new version

our $VERSION = '2.043';

use Moose;
use MooseX::Has::Sugar;
use MooseX::Types::Moose qw{ Str Bool};
use namespace::autoclean;

sub _git_config_mapping {
  +{ changelog => '%{changelog}s', };
}

# -- attributes

has tag_format  => ( ro, isa => Str,  default   => 'v%v' );
has tag_message => ( ro, isa => Str,  default   => 'v%v' );
has changelog   => ( ro, isa => Str,  default   => 'Changes' );
has branch      => ( ro, isa => Str,  predicate => 'has_branch' );
has signed      => ( ro, isa => Bool, default   => 0 );

with 'Dist::Zilla::Role::BeforeRelease', 'Dist::Zilla::Role::AfterRelease', 'Dist::Zilla::Role::Git::Repo';
with 'Dist::Zilla::Role::Git::StringFormatter';
with 'Dist::Zilla::Role::GitConfig';

#pod =method tag
#pod
#pod     my $tag = $plugin->tag;
#pod
#pod Return the tag that will be / has been applied by the plugin. That is,
#pod returns C<tag_format> as completed with the real values.
#pod
#pod =cut

has tag => ( ro, isa => Str, lazy_build => 1, );

sub _build_tag {
  my $self = shift;
  return $self->_format_string( $self->tag_format );
}

# -- role implementation

around dump_config => sub {
  my $orig = shift;
  my $self = shift;

  my $config = $self->$orig;

  $config->{ +__PACKAGE__ } = {
    ( map { $_ => $self->$_ } qw(tag_format tag_message changelog branch tag) ),
    signed => $self->signed ? 1 : 0,
    blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
  };

  return $config;
};

sub before_release {
  my $self = shift;

  # Make sure a tag with the new version doesn't exist yet:
  my $tag = $self->tag;
  $self->log_fatal("tag $tag already exists")
    if $self->git->tag( '-l', $tag );
}

sub after_release {
  my $self = shift;

  my @opts;
  push @opts, ( '-m' => $self->_format_string( $self->tag_message ) )
    if $self->tag_message;    # Make an annotated tag if tag_message, lightweight tag otherwise:
  push @opts, '-s'
    if $self->signed;         # make a GPG-signed tag

  my @branch = $self->has_branch ? ( $self->branch ) : ();

  # create a tag with the new version
  my $tag = $self->tag;
  $self->git->tag( @opts, $tag, @branch );
  $self->log("Tagged $tag");
}

__PACKAGE__->meta->make_immutable;
1;

__END__

