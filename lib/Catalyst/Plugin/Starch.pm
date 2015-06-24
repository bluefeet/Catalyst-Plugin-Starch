package Catalyst::Plugin::Starch;

=head1 NAME

Catalyst::Plugin::Starch - Catalyst session plugin via Web::Starch.

=head1 SYNOPSIS

    package MyApp;
    
    use Catalyst qw(
        Starch
        Starch::State::Cookie
    );
    
    __PACKAGE__->config(
        'Plugin::Starch' => {
            cookie_name => 'my_session',
            store => { class=>'::Memory' },
        },
    );

=head1 DESCRIPTION

Integrates L<Web::Starch> with L<Catalyst> providing a compatible replacement
for L<Catalyst::Plugin::Session>.

=head1 CONFIGURATION

Configuring starch is a matter if setting the L<Plugin::Starch> configuration
key in your root Catalyst application class:

    __PACKAGE__->config(
        'Plugin::Starch' => {
            store => { class=>'::Memory' },
        },
    );

In addition to the arguments you would normally pass to L<Web::Starch> you
can also pass a C<plugins> argument which will be combined with the plugins
from L</default_starch_plugins>.

=cut

use Web::Starch;
use Types::Standard -types;
use Types::Common::String -types;
use Catalyst::Exception;
use Scalar::Util qw( blessed );

use Moose::Role;
use strictures 2;
use namespace::clean;

sub BUILD {
  my ($c) = @_;

  # Get the starch object instantiated as early as possible.
  $c->starch();

  return;
}

before finalize_body => sub{
    my ($c) = @_;

    $c->_clear_sessionid();
    $c->_clear_session_delete_reason();

    return if !$c->_has_starch_session();

    $c->starch_session->save();
    $c->_clear_starch_session();

    return;
};

=head1 COMPATIBILITY

This module is mostly API compliant with L<Catalyst::Plugin::Session>.  The way you
configure this plugin will be different, but all your code that uses sessions, or
other plugins that use sessions, should not need to be changed unless they
depend on undocumented features.

Everything documented in the L<Catalyst::Plugin::Session/METHODS> section is
supported except for:

=over

=item *

The C<session_expires> and C<change_session_expires> methods are not supported
as starch has the concept of multiple layered stores which may have different
expiration times per-store.

=item *

The C<flash>, C<clear_flash>, and C<keep_flash> methods are not implemented
as its really a terrible idea.  If this becomes a big issue for compatibility
with existing code and plugins then this may be reconsidered.

=item *

The C<session_expire_key> method is not supported, but can be if it is deemed
a good feature to port.

=back

The above listed un-implemented methods and attributes will throw an exception
if called.

=cut

sub session_expires {
    Catalyst::Exception->throw( 'The session_expires method is not implemented by Catalyst::Plugin::Starch' );
}

sub change_session_expires {
    Catalyst::Exception->throw( 'The change_session_expires method is not implemented by Catalyst::Plugin::Starch' );
}

sub flash {
    Catalyst::Exception->throw( 'The flash method is not implemented by Catalyst::Plugin::Starch' );
}

sub clear_flash {
    Catalyst::Exception->throw( 'The clear_flash method is not implemented by Catalyst::Plugin::Starch' );
}

sub keep_flash {
    Catalyst::Exception->throw( 'The keep_flash method is not implemented by Catalyst::Plugin::Starch' );
}

sub session_expire_key {
    Catalyst::Exception->throw( 'The session_expire_key method is not implemented by Catalyst::Plugin::Starch' );
}

=head1 REQUIRED ARGUMENTS

=head2 starch

The L<Web::Starch> object.  This gets automatically constructed from
the C<Plugin::Starch> Catalyst configuration key per L</CONFIGURATION>.

=cut

has starch => (
    is      => 'lazy',
    isa     => HasMethods[ 'session' ],
    lazy    => 1,
    builder => '_build_starch',
);
sub _build_starch {
    my ($c) = @_;

    my $starch = $c->config->{'Plugin::Starch'};
    Catalyst::Exception->throw( 'No Catalyst configuration was specified for Plugin::Starch' ) if !$starch;
    Catalyst::Exception->throw( 'Plugin::Starch config was not a hash ref' ) if ref($starch) ne 'HASH';

    my $args = Web::Starch->BUILDARGS( $starch );
    my $plugins = delete( $args->{plugins} ) || [];

    $plugins = [
        @{ $c->default_starch_plugins() },
        @$plugins,
    ];

    return Web::Starch->new_with_plugins( $plugins, $args );
}

=head1 ATTRIBUTES

=head2 sessionid

The ID of the session.

=cut

has sessionid => (
    is        => 'ro',
    isa       => NonEmptySimpleStr,
    init_arg  => undef,
    writer    => '_set_sessionid',
    clearer   => '_clear_sessionid',
    predicate => '_has_sessionid',
);

=head2 session_delete_reason

Returns the C<reason> value passsed to L</delete_session>.
Two common values are:

=over

=item *

C<address mismatch>

=item *

C<session expired>

=back

=cut

has session_delete_reason => (
    is       => 'ro',
    isa      => NonEmptySimpleStr,
    init_arg => undef,
    writer   => '_set_session_delete_reason',
    clearer  => '_clear_session_delete_reason',
);

=head2 default_starch_plugins

This attribute returns the base set plugins that the L</starch>
object will be built with.  Note that this does not include any
additional plugins you specify in the L</CONFIGURATION>.

=cut

sub default_starch_plugins {
    return [];
}

=head2 starch_session

This holds the underlying L<Web::Starch::Session> object.

=cut

has starch_session => (
    is        => 'ro',
    isa        => HasMethods[ 'save', 'expire' ],
    lazy      => 1,
    builder   => '_build_starch_session',
    writer    => '_set_starch_session',
    predicate => '_has_starch_session',
    clearer   => '_clear_starch_session',
);
sub _build_starch_session {
    my ($c) = @_;
    my $session = $c->starch->session( $c->sessionid() );
    $c->_set_sessionid( $session->id() );
    return $session;
}

=head1 METHODS

=head2 session

    $c->session->{foo} = 45;
    $c->session( foo => 45 );
    $c->session({ foo => 45 });

Returns a hashref of the session data which may be modified and
will be stored at the end of the request.

A hash list or a hash ref may be passed to set values.

=cut

sub session {
    my $c = shift;

    my $data = $c->starch_session->data();
    return $data if !@_;

    my $new_data;
    if (@_==1 and ref($_[0]) eq 'HASH') {
        $new_data = $_[0];
    }
    else {
        $new_data = { @_ };
    }

    foreach my $key (keys %$new_data) {
        $data->{$key} = $new_data->{$key};
    }

    return $data;
}

=head2 delete_session

    $c->delete_session();
    $c->delete_session( $reason );

Deletes the session, optionally with a reason specified.

=cut

sub delete_session {
    my ($c, $reason) = @_;

    if ($c->_has_starch_session()) {
        $c->starch_session->expire();
    }

    $c->_set_session_delete_reason( $reason );

    return;
}

=head2 change_session_id

    $c->change_session_id();

Generates a new ID for the session but retains the session
data in the new session.

Some interesting discussion as to why this is useful is at
L<Catalyst::Plugin::Session/METHODS> under the C<change_session_id>
method.

=cut

sub change_session_id {
    my ($c) = @_;

    $c->_clear_sessionid();
    return if !$c->_has_starch_session();

    $c->starch_session->reset_id();

    return;
}

1;
__END__

=head1 AUTHOR

Aran Clary Deltac <bluefeetE<64>gmail.com>

=head1 ACKNOWLEDGEMENTS

Thanks to L<ZipRecruiter|https://www.ziprecruiter.com/>
for encouraging their employees to contribute back to the open
source ecosystem.  Without their dedication to quality software
development this distribution would not exist.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

