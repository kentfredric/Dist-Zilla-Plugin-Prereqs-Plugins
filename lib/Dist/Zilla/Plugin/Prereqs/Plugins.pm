use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Plugins;
BEGIN {
  $Dist::Zilla::Plugin::Prereqs::Plugins::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Prereqs::Plugins::VERSION = '0.1.0';
}

# ABSTRACT: Add all Dist::Zilla plugins presently in use as prerequisites.

use Moose;
use MooseX::Types::Moose qw( HashRef ArrayRef Str );

with 'Dist::Zilla::Role::PrereqSource';



has phase    => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'develop' }, );
has relation => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'requires' }, );


has exclude => ( is => ro =>, isa => ArrayRef [Str], lazy => 1, default => sub { [] } );


has _exclude_hash => ( is => ro =>, isa => HashRef [Str], lazy => 1, builder => '_build__exclude_hash' );


sub mvp_multivalue_args { return qw(exclude) }


sub _build__exclude_hash {
  my ( $self, ) = @_;
  return { map { ( $_ => 1 ) } @{ $self->exclude } };
}


sub get_plugin_module {
  my ( $self, $plugin ) = @_;
  return if not ref $plugin;
  require Scalar::Util;
  return Scalar::Util::blessed($plugin);
}


sub skip_prereq {
  my ( $self, $plugin ) = @_;
  return 1 if exists $self->_exclude_hash->{ $self->get_plugin_module($plugin) };
  return;
}


sub get_prereq_for {
  my ( $self, $plugin ) = @_;
  return ( $self->get_plugin_module($plugin), 0 );
}

around 'dump_config' => sub {
  my ( $orig, $self, @args ) = @_;
  my $config      = $self->$orig(@args);
  my $this_config = {
    phase    => $self->phase,
    relation => $self->relation,
    exclude  => $self->exclude,
  };
  $config->{ q{} . __PACKAGE__ } = $this_config;
  return $config;
};


sub register_prereqs {
  my ($self)   = @_;
  my $zilla    = $self->zilla;
  my $phase    = $self->phase;
  my $relation = $self->relation;

  for my $plugin ( @{ $self->zilla->plugins } ) {
    next if $self->skip_prereq($plugin);
    my ( $name, $version ) = $self->get_prereq_for($plugin);
    $zilla->register_prereqs( { phase => $phase, type => $relation }, $name, $version );
  }
  return $zilla->prereqs;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::Prereqs::Plugins - Add all Dist::Zilla plugins presently in use as prerequisites.

=head1 VERSION

version 0.1.0

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

=head2 C<get_plugin_module>

    $instance->get_plugin_module( $plugin_instance );

=head2 C<skip_prereq>

    if ( $instance->skip_prereq( $plugin_instance ) ) {

    }

=head2 C<get_prereq_for>

    my ( $module, $version ) = $instance->get_prereq_for( $plugin_instance );

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

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
