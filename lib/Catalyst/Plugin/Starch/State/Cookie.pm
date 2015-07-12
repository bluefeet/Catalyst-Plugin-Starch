package Catalyst::Plugin::Starch::State::Cookie;

=head1 NAME

Catalyst::Plugin::Starch::State::Cookie - Record Starch session state in a cookie.

=head1 SYNOPSIS

    package MyApp;
    
    use Catalyst qw(
        Starch
        Starch::State::Cookie
    );

=head1 DESCRIPTION

This plugin utilizes the L<Starch::Plugin::CookieArgs> plugin to add
a bunch of arguments to the Starch object, search the request cookies for
the session cookie, and write the session cookie at the end of the request.

See the L<Starch::Plugin::CookieArgs> documentation for a
list of arguments you can specify in the Catalyst configuration for
L<Catalyst::Plugin::Starch>.

=cut

use Class::Method::Modifiers qw( fresh );

use Moose::Role;
use strictures 2;
use namespace::clean;

=head1 COMPATIBILITY

Most of the methods documented in
L<Catalyst::Plugin::Session::State::Cookie/METHODS> are not
supported at this time:

=over

=item *

The C<make_session_cookie>, C<update_session_cookie>, C<calc_expiry>,
C<calculate_session_cookie_expires>, C<cookie_is_rejecting>,
C<delete_session_id>, C<extend_session_id>,
C<get_session_id>, and C<set_session_id> methods are not currently
supported but could be if necessary.

=back

The above listed un-implemented methods and attributes will throw an exception
if called.

=cut

# These are already blocked by Catalyst::Plugin::Starch:
#    delete_session_id extend_session_id
#    get_session_id set_session_id

foreach my $method (qw(
    make_session_cookie update_session_cookie calc_expiry
    calculate_session_cookie_expires cookie_is_rejecting
)) {
    fresh $method => sub{
        Catalyst::Exception->throw( "The $method method is not implemented by Catalyst::Plugin::Starch::State::Cookie" );
    };
}

=head1 METHODS

=head2 get_session_cookie

Returns the L<CGI::Simple::Cookie> object from L<Catalyst::Request>
for the session cookie, if there is one.

=cut

sub get_session_cookie {
    my ($c) = @_;

    my $cookie_name = $c->starch->cookie_name();
    my $cookie = $c->req->cookies->{ $cookie_name };

    return $cookie;
}

=head1 MODIFIED METHODS

These methods in the Catalyst application object are modified.
See L<Catalyst::Manual::Internals> for more information.

=head2 prepare_cookies

Reads the session cookie from the request just after
C<prepare_cookies> is called.

=cut

after prepare_cookies => sub{
    my ($c) = @_;
    my $cookie = $c->get_session_cookie();
    return if !$cookie;
    $c->_set_sessionid( $cookie->value() );
    return;
};

=head2 finalize_headers

Adds the session cookie to the response just before
C<finalize_headers> is called.

=cut

before finalize_headers => sub{
    my ($c) = @_;
    return if !$c->_has_sessionid();
    my $cookie_name = $c->starch->cookie_name();
    $c->res->cookies->{ $cookie_name } = $c->starch_session->cookie_args();
    return;
};

=head2 default_starch_plugins

Adds L<Starch::Plugin::CookieArgs> to the list of Starch plugins
that L<Catalyst::Plugin::Starch> will apply.

=cut

around default_starch_plugins => sub{
    my $orig = shift;
    my $c = shift;

    return [
        @{ $c->$orig() },
        '::CookieArgs',
    ];
};

1;
__END__

=head1 AUTHOR AND LICENSE

See L<Catalyst::Plugin::Starch/AUTHOR> and
L<Catalyst::Plugin::Starch/LICENSE>.

