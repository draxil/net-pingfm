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
use Test::More tests => 5;


use Net::PingFM;
{
    my $pfm = new Net::PingFM( api_key => 'foo', user_key => 'bar',
                               _debug_save_last_post => 1 );
    prep_test_response( $pfm,'<?xml version="1.0"?>
<rsp status="OK">
  <transaction>12345</transaction>
  <method>user.triggers</method>
  <triggers>
    <trigger id="twt" method="microblog">
      <services>
        <service id="twitter" name="Twitter"/>
      </services>
    </trigger>
    <trigger id="fb" method="status">
      <services>
        <service id="facebook" name="Facebook"/>
      </services>
    </trigger>
  </triggers>
</rsp>', 1
);
    my @triggers = eval{$pfm->triggers};
    ok( !$@, 'Can get triggers without an exception')
        or diag($@);
    is( scalar @triggers, 2, 'Get two triggers');
    is( $triggers[0]->id, 'twt', 'ID set correctly' );
    is( $triggers[0]->method, 'microblog', 'Status set correctly' );
    is( $triggers[1]->id, 'fb', 'Second trigger has id.');
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
