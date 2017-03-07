use 5.006;
use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Plugins;

our $VERSION = '1.003003';

# ABSTRACT: Add all Dist::Zilla plugins presently in use as prerequisites.

# AUTHORITY

use Moose qw( with has around );
use Dist::Zilla::Util;
use MooseX::Types::Moose qw( HashRef ArrayRef Str );
use Dist::Zilla::Util::BundleInfo;
use Dist::Zilla::Util::ExpandINI::Reader;
use Module::Runtime qw( require_module );
use Path::Tiny qw( path );
with 'Dist::Zilla::Role::PrereqSource';

=attr C<phase>

The target installation phase to inject into:

=over 4

=item * C<runtime>

=item * C<configure>

=item * C<build>

=item * C<test>

=item * C<develop>

=back

=cut

has phase => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'develop' }, );

=attr C<relation>

The type of dependency relation to create:

=over 4

=item * C<requires>

=item * C<recommends>

=item * C<suggests>

=item * C<conflicts>

Though think incredibly hard before using this last one ;)

=back

=cut

has relation => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'requires' }, );

=attr C<exclude>

Specify anything you want excluded here.

May Be specified multiple times.

    [Prereqs::Plugins]
    exclude = Some::Module::Thingy
    exclude = Some::Other::Module::Thingy

=cut

has exclude => ( is => ro =>, isa => ArrayRef [Str], lazy => 1, default => sub { [] } );

=p_attr C<_exclude_hash>

=cut

has _exclude_hash => ( is => ro =>, isa => HashRef [Str], lazy => 1, builder => '_build__exclude_hash' );

=method C<mvp_multivalue_args>

The list of attributes that can be specified multiple times

    exclude

=cut

sub mvp_multivalue_args { return qw(exclude) }

=p_method C<_build__exclude_hash>

=cut

sub _build__exclude_hash {
  my ( $self, ) = @_;
  return { map { ( $_ => 1 ) } @{ $self->exclude } };
}
around dump_config => sub {
  my ( $orig, $self, @args ) = @_;
  my $config = $self->$orig(@args);
  my $localconf = $config->{ +__PACKAGE__ } = {};

  $localconf->{phase}    = $self->phase;
  $localconf->{relation} = $self->relation;
  $localconf->{exclude}  = $self->exclude;

  $localconf->{ q[$] . __PACKAGE__ . '::VERSION' } = $VERSION
    unless __PACKAGE__ eq ref $self;

  return $config;
};

__PACKAGE__->meta->make_immutable;
no Moose;

sub _register_plugin_prereq {
  my ( $self, $package, $lines ) = @_;
  return if exists $self->_exclude_hash->{$package};
  $self->zilla->register_prereqs( { phase => $self->phase, type => $self->relation }, $package, 0 );
  return unless @{ $lines || [] };
  while ( @{$lines} ) {
    my $key   = shift @{$lines};
    my $value = shift @{$lines};
    next unless q[:version] eq $key;
    $self->zilla->register_prereqs( { phase => $self->phase, type => $self->relation }, $package, $value );
  }
  return;
}

=method C<register_prereqs>

See L<<< C<< Dist::Zilla::Role::B<PrereqSource> >>|Dist::Zilla::Role::PrereqSource >>>

=cut

sub register_prereqs {
  my ($self) = @_;
  my $reader = Dist::Zilla::Util::ExpandINI::Reader->new();
  my $ini    = path( $self->zilla->root )->child('dist.ini');
  if ( not $ini->exists ) {
    $self->log_fatal(q[Prereqs::Plugins only works on dist.ini due to :version hidden since 5.032]);
    return;
  }
  my (@sections) = @{ $reader->read_file("$ini") };
  while (@sections) {
    my ($section) = shift @sections;

    # Special case for Dzil
    if ( '_' eq ( $section->{name} || q[] ) ) {
      $self->_register_plugin_prereq( q[Dist::Zilla], $section->{lines} );
      next;
    }
    my $package_expanded = Dist::Zilla::Util->expand_config_package_name( $section->{package} );

    # Standard plugin.
    if ( $section->{package} !~ /\A\@/msx ) {
      $self->_register_plugin_prereq( $package_expanded, $section->{lines} );
      next;
    }

    # Bundle
    # TODO: Maybe register the bundle itself?
    next if exists $self->_exclude_hash->{$package_expanded};

    # Handle bundle
    my $bundle = Dist::Zilla::Util::BundleInfo->new(
      bundle_name    => $section->{package},
      bundle_payload => $section->{lines},
    );

    for my $plugin ( $bundle->plugins ) {
      $self->_register_plugin_prereq( $plugin->module, [ $plugin->payload_list ] );
    }
  }
  return $self->zilla->prereqs;
}


1;

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

=head1 LIMITATIONS

=over 4

=item * This module will B<NOT> report C<@Bundles> as dependencies at present.

=item * This module will B<NOT> I<necessarily> include B<ALL> dependencies, but is only intended to include the majority of them.

=item * This module will not report I<injected> dependencies, only dependencies that can be discovered from the parse tree directly, or from the return values of any indicated bundles.

=back

=cut
