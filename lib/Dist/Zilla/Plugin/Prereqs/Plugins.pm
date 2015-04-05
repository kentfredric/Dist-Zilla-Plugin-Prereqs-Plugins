use 5.008;    # pragma utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Prereqs::Plugins;

our $VERSION = '1.003000';

# ABSTRACT: Add all Dist::Zilla plugins presently in use as prerequisites.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( with has around );
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );
use Dist::Zilla::Util;
use MooseX::Types::Moose qw( HashRef ArrayRef Str );
use Dist::Zilla::Util::BundleInfo;
use Dist::Zilla::Util::ExpandINI::Reader;
use Module::Runtime qw( require_module );
use Path::Tiny qw( path );
with 'Dist::Zilla::Role::PrereqSource';





















has phase => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'develop' }, );





















has relation => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'requires' }, );













has exclude => ( is => ro =>, isa => ArrayRef [Str], lazy => 1, default => sub { [] } );





has _exclude_hash => ( is => ro =>, isa => HashRef [Str], lazy => 1, builder => '_build__exclude_hash' );









sub mvp_multivalue_args { return qw(exclude) }





sub _build__exclude_hash {
  my ( $self, ) = @_;
  return { map { ( $_ => 1 ) } @{ $self->exclude } };
}

around 'dump_config' => config_dumper( __PACKAGE__, qw( phase relation exclude ) );

sub _extract_versions {
  my ( $section, ) = @_;
  return unless $section->{lines};
  my @entries = @{ $section->{lines} };
  my (@versions);
  while (@entries) {
    my $key = shift @entries;
    my $value = shift @entries if @entries;
    next unless $key eq ':version';
    push @versions, $value;
  }
  return @versions;
}







sub register_prereqs {
  my ($self)   = @_;
  my $zilla    = $self->zilla;
  my $phase    = $self->phase;
  my $relation = $self->relation;

  my $reader = Dist::Zilla::Util::ExpandINI::Reader->new();
  my $ini    = path( $self->zilla->root )->child('dist.ini');
  if ( not $ini->exists ) {
    $self->log_fatal(
      "Sorry, Prereqs::Plugins only works on dist.ini files directly due to :version now being excluded from the package stash");
    return;
  }
  my (@sections) = @{ $reader->read_file("$ini") };
  while (@sections) {
    my ($section)  = shift @sections;
    my (@versions) = _extract_versions($section);

    # Special case for Dzil
    if ( '_' eq ( $section->{name} || q[] ) ) {

      # No versions = no explicit dep
      next unless scalar @versions;
      for my $version (@versions) {
        $zilla->register_prereqs( { phase => $phase, type => $relation }, "Dist::Zilla", $version );
      }
      next;
    }
    next unless $section->{package};
    my $package_expanded = Dist::Zilla::Util->expand_config_package_name( $section->{package} );
    next if exists $self->_exclude_hash->{$package_expanded};

    # Standard plugin.
    if ( $section->{package} !~ /\A\@/msx ) {

      # Register all plugins as 0 first.
      $zilla->register_prereqs( { phase => $phase, type => $relation }, $package_expanded, 0 );
      next unless scalar @versions;
      for my $version (@versions) {
        $zilla->register_prereqs( { phase => $phase, type => $relation }, $package_expanded, $version );
      }
      next;
    }

    # Bundle
    # TODO: Maybe register the bundle itself?
    # $self->register_prereqs( { phase => $phase, type => $relation }, $section->{package}, 0 );

    # Handle bundle
    my $bundle = Dist::Zilla::Util::BundleInfo->new(
      bundle_name    => $section->{package},
      bundle_payload => $section->{lines},
    );

    for my $plugin ( $bundle->plugins ) {
      next if exists $self->_exclude_hash->{ $plugin->module };
      $zilla->register_prereqs( { phase => $phase, type => $relation }, $plugin->module, 0 );
      require_module( $plugin->module );
      my (@versions) = _extract_versions( { lines => [ $plugin->payload_list ] } );
      next unless @versions;
      for my $version (@versions) {
        $zilla->register_prereqs( { phase => $phase, type => $relation }, $plugin->module, $version );
      }
    }
  }
  return $zilla->prereqs;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Prereqs::Plugins - Add all Dist::Zilla plugins presently in use as prerequisites.

=head1 VERSION

version 1.003000

=head1 SYNOPSIS

    [Prereqs::Plugins]
    ; all plugins are now develop.requires deps

    [Prereqs::Plugins]
    phase = runtime    ; all plugins are now runtime.requires deps

=head1 DESCRIPTION

This is mostly because I am lazy, and the lengthy list of hand-updated dependencies
on my C<@Author::> bundle started to get overwhelming, and I'd periodically miss something.

This module is kinda C<AutoPrereqs>y, but in ways that I can't imagine being plausible with
a generic C<AutoPrereqs> tool, at least, not without requiring some nasty re-implementation
of how C<dist.ini> is parsed.

=head1 METHODS

=head2 C<mvp_multivalue_args>

The list of attributes that can be specified multiple times

    exclude

=head2 C<register_prereqs>

See L<<< C<< Dist::Zilla::Role::B<PrereqSource> >>|Dist::Zilla::Role::PrereqSource >>>

=head1 ATTRIBUTES

=head2 C<phase>

The target installation phase to inject into:

=over 4

=item * C<runtime>

=item * C<configure>

=item * C<build>

=item * C<test>

=item * C<develop>

=back

=head2 C<relation>

The type of dependency relation to create:

=over 4

=item * C<requires>

=item * C<recommends>

=item * C<suggests>

=item * C<conflicts>

Though think incredibly hard before using this last one ;)

=back

=head2 C<exclude>

Specify anything you want excluded here.

May Be specified multiple times.

    [Prereqs::Plugins]
    exclude = Some::Module::Thingy
    exclude = Some::Other::Module::Thingy

=head1 PRIVATE ATTRIBUTES

=head2 C<_exclude_hash>

=head1 PRIVATE METHODS

=head2 C<_build__exclude_hash>

=head1 LIMITATIONS

=over 4

=item * This module will B<NOT> report C<@Bundles> as dependencies at present.

=item * This module will B<NOT> I<necessarily> include B<ALL> dependencies, but is only intended to include the majority of them.

Some plugins, such as my own C<Bootstrap::lib> don't add themselves to the C<dzil> C<< ->plugins() >> list, and as such, it will be invisible to this module.

=back

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
