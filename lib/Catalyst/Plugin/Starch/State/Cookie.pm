package Catalyst::Plugin::Starch::State::Cookie;

=head1 NAME

Catalyst::Plugin::Starch::State::Cookie - Record Web::Starch session state in a cookie.

=head1 SYNOPSIS

    package MyApp;
    
    use Catalyst qw(
        Starch
        Starch::State::Cookie
    );

=head1 DESCRIPTION

This plugin utilizes the L<Web::Starch::Plugin::CookieArgs> plugin to add
a bunch of arguments to the Starch object, search the request cookies for
the session cookie, and write the session cookie at the end of the request.

See the L<Web::Starch::Plugin::CookieArgs::Manager> documentation for a
list of arguments you can specify in the Catalyst configuration for
L<Catalyst::Plugin::Starch>.

=cut

use Moose::Role;
use strictures 2;
use namespace::clean;

after prepare_cookies => sub{
    my ($c) = @_;
    my $cookie = $c->req->cookie( $c->starch->cookie_name() );
    $c->_set_sessionid( $cookie->value() ) if $cookie;
    return;
};

before finalize_cookies => sub{
    my ($c) = @_;

    return if !$c->_has_sessionid();

    $c->res->cookies->{ $c->starch->cookie_name() } =
        $c->starch_session->cookie_args();

    return;
};

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

