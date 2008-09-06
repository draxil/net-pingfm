#!/usr/bin/perl -T

use strict;
use Test::More tests => 6;


use Net::PingFM;
use Scalar::Util qw{ blessed };

my $pfm = Net::PingFM->new( user_key => 'blah',
                            api_key => 'foo' );

ok( $pfm, 'constructor can make *something*' );
ok( blessed( $pfm ), 'constructor can make *something* blessed' );
ok( $pfm->isa( 'Net::PingFM' ), 'actually it can make a Net::PingFM');
ok( $pfm->user_key eq 'blah', 'User key accessor works' );
ok( $pfm->api_key eq 'foo', 'Api key accessor works' );
$pfm->user_key( 'monkey' );
ok( $pfm->user_key eq 'monkey' );
