use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Plugins;
BEGIN {
  $Dist::Zilla::Plugin::Prereqs::Plugins::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Prereqs::Plugins::VERSION = '0.1.0';
}

# ABSTRACT: Add all Dist::Zilla plugins presently in use as prereqs.

use Moose;

with 'Dist::Zilla::Role::PrereqSource';

has phase => ( is => ro =>, lazy =>1, default => sub { 'develop' } );
has relation => ( is => ro =>, lazy =>1 , default => sub { 'requires' } );

sub skip_prereq {
    my ( $self, $plugin ) = @_ ;
    return;
}

sub get_prereq_for {
    my ( $self, $plugin ) = @_;
    require Scalar::Util;
    return ( Scalar::Util::blessed($plugin) , 0 );
}

around 'dump_config' => sub {
    my ( $orig, $self, @args ) = @_;
    my $config = $self->$orig(@args);
    my $this_config = {
        phase => $self->phase,
        relation => $self->relation,
    };
    $config->{ q{} . __PACKAGE__ } = $this_config;
    return $config;
};

sub register_prereqs {
    my ( $self ) = @_; 
    my $zilla = $self->zilla;
    my $phase = $self->phase;
    my $relation = $self->relation;

    for my $plugin (  @{$self->zilla->plugins} ) {
        next if $self->skip_prereq( $plugin );
        my ( $name, $version ) = $self->get_prereq_for( $plugin );
        $zilla->register_prereqs( { phase => $phase, type => $relation }, 
                $name, $version );
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

Dist::Zilla::Plugin::Prereqs::Plugins - Add all Dist::Zilla plugins presently in use as prereqs.

=head1 VERSION

version 0.1.0

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
