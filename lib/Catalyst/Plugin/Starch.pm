package Catalyst::Plugin::Starch;

=head1 NAME

Catalyst::Plugin::Starch - Catalyst session plugin via Web::Starch.

=head1 DESCRIPTION

This module is API compliant with L<Catalyst::Plugin::Session>.  The way you
configure this plugin will be different, but all your code that uses sessions, or
other plugins that use sessions, should not need to be changed unless they
depend on undocumented features.

=cut

use Session::Manager;
use Log;

use Types::Standard -types;

use Moose::Role;
use strictures 1;
use namespace::clean;

sub BUILD {
  my ($self) = @_;

  # Get the session manager instantiated as early as possible.
  $self->_session_manager();

  return;
}

has _session_manager => (
  is  => 'lazy',
  isa => InstanceOf[ 'Session::Manager' ],
);
sub _build__session_manager {
  return Session::Manager->new();
}

has _session_object => (
  is        => 'lazy',
  isa       => InstanceOf[ 'Session' ],
  predicate => 1,
  clearer   => 1,
);
sub _build__session_object {
  my ($c) = @_;

  my $manager = $self->_sesssion_manager();
  my $cookie_args = $manager->cookie_args();

  my $cookie = $c->req->cookie( $cookie_args->{name} );
  return $manager->session() if !$cookie;

  return $manager->session( $cookie->value() );
}

sub session {
  my $c = shift;

  my $data = $self->_session_object->data();
  return $data if !@_;

  if (@_ == 1) {
    %$data = (
      %$data,
      %{ $_[0] },
    );
  }
  else {
    %$data = (
      %$data,
      @_,
    );
  }

  return;
}

after prepare_cookies => sub{
  my ($c) = @_;

  # This should never happen, and if it did it would be very bad as we'd
  # be using a session object from a previous request.
  if ($c->_has_session_object()) {
    warn(
      'Session object %s present too early in the request cycle',
      $c->session_object->key(),
    );

    $c->_clear_session_object();
  }

  return;
};

before finalize_cookies => sub{
  my ($c) = @_;

  my $cookie_args = $c->_session_object->cookie_args();
  my $name = delete $cookie_args->{name};

  $c->res->cookies->{ $name } = $cookie_args;

  return;
};

before finalize_body => sub{
  my ($c) = @_;

  $self->_session_object->flush();
  $self->_clear_session_object();

  return $c->$orig( @_ );
};

1;
