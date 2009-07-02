#!/usr/bin/perl -T
package Fake_lwp_uagent;
use Moose;
has 'response' => ( is => 'rw' );

sub post{
    my $self = shift;
    return $self->response;
}

no Moose;

package Fake_lwp_response;

use Moose;

has 'content' => ( is => 'rw' );
has 'is_success' => ( is => 'rw' );
has 'status_line' => ( is => 'rw' );

no Moose;

package main;

use strict;
use Test::More tests => 23;


use Net::PingFM;
use Scalar::Util qw{ blessed };

{

    my $pfm = new Net::PingFM( api_key => 'foo', user_key => 'bar',
                           _debug_save_last_post => 1 );

    prep_test_response( $pfm, '<?xml version="1.0"?>
<rsp status="OK">
  <transaction>12345</transaction>
  <method>user.validate</method>
</rsp>
', 1 );
    ok( $pfm->user_validate, 'User validate' );

    prep_test_response( $pfm, '<?xml version="1.0"?>
<rsp status="FAIL">
  <transaction>12345</transaction>
  <method>user.validate</method>
</rsp>
', 1 );

    ok( ! $pfm->user_validate, 'User validate failure handled' );

    prep_test_response(
                $pfm, '<?xml version="1.0"?>
<rsp status="OK">
  <transaction>12345</transaction>
  <method>user.post</method>
</rsp>
', 1 );


    ok( $pfm->post( 'RAR!' ), 'Post');
    is( $pfm->_debug_last_post->{body}, 'RAR!', 'And that set the body post field correctly' );
    ok( $pfm->post( 'RAR!', {method => 'status'} ), 'Post with method');

    is( $pfm->_debug_last_post->{post_method}, 'status', 'And that set the status post field correctly' );
    my $ERROR = 'foo';
    prep_test_response(
        $pfm, '<?xml version="1.0"?>
<rsp status="FAIL">
  <transaction>12345</transaction>
  <method>user.post</method>
  <message>'.$ERROR.'</message>
</rsp>', 1
);
    $pfm->post( 'boo' );

    ok( $pfm->last_error eq $ERROR, 'Error extraction and report works' );

    # use the documentations services response to do an inital set of
    # "services" tests
    prep_test_response( $pfm, '<?xml version="1.0"?>
<rsp status="OK">
  <transaction>12345</transaction>
  <method>user.services</method>
  <services>
    <service id="twitter" name="Twitter">
      <trigger>@tt</trigger>
      <url>http://twitter.com/</url>
      <icon>http://p.ping.fm/static/icons/twitter.png</icon>
      <methods>microblog,status</methods>
    </service>
    <service id="facebook" name="Facebook">
      <trigger>@fb</trigger>
      <url>http://www.facebook.com/</url>
      <icon>http://p.ping.fm/static/icons/facebook.png</icon>
      <methods>status</methods>
    </service>
  </services>
</rsp>', 1);

    my @services = $pfm->services;

    is( @services+0, 2, 'Correctly parsed service response into a two entry list'  );

    my $twitter = $services[0];

    ok( $twitter->can_microblog, 'Service object for twitter thinks it can microblog' );
    ok( ! $twitter->can_blog, 'Service entry for twitter knows it can\'t blog' );
    ok( $twitter->can_status, 'Service object for twitter things it can use status method' );
    is( $twitter->trigger, '@tt', 'Service object for twitter knows it\'s trigger' );
    is( $twitter->id, 'twitter', 'Service object for twitter knows it\'s id');
    is( $twitter->name, 'Twitter', 'Service object for twitter knows it\'s name');

    my $facebook = $services[1];

    ok( $facebook->can_status, 'Facebook service knows it can status' );
    ok( ! $facebook->can_blog && !$facebook->can_microblog,
        'Facebook service knows it\'s limitations' );
    is( $facebook->trigger, '@fb', 'Facebook service knows it\'s trigger' );
    is( $facebook->name, 'Facebook', 'Facebook service know\'s it\'s name' );
    is( $facebook->id, 'facebook', q|Facebook service know's it's id| );

    prep_test_response(
                $pfm, '<?xml version="1.0"?>
<rsp status="OK">
  <transaction>12345</transaction>
  <method>user.post</method>
</rsp>
', 1 );

    ok( $pfm->post( 'boo', { service => $facebook }), 'Can use a service obj. in post' );

    ok( $pfm->_debug_last_post->{service} eq 'facebook', '..And that set the relivant post field' );

    ok( $pfm->post( 'boo', { service => $twitter->id }), 'Can use a service id in post' );

    ok( $pfm->_debug_last_post->{service} eq 'twitter', '..And that set the relivant post field' );
    
}


sub prep_test_response{
    my ( $pfm, $response, $ok) = @_;
    $pfm->_use_lwp_replacement(
        Fake_lwp_uagent->new(
            response => Fake_lwp_response->new(
                content => $response,
                is_success => $ok,
                status_line => 'fake',
            )
        )
    );
}
;1;
