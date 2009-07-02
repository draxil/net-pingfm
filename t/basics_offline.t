#!/usr/bin/perl -T

# test very little of use but if this one fails the other ones don't stand a
# chance :)

use strict;
use Test::More tests => 7;


use Scalar::Util qw{ blessed };

my $pfm = Net::PingFM->new( user_key => 'blah',
                            api_key => 'foo' );
BEGIN{ use_ok( 'Net::PingFM' );}

require Net::PingFM;

ok( $pfm, 'constructor can make *something*' );
ok( blessed( $pfm ), 'constructor can make *something* blessed' );
ok( $pfm->isa( 'Net::PingFM' ), 'actually it can make a Net::PingFM');
ok( $pfm->user_key eq 'blah', 'User key accessor works' );
ok( $pfm->api_key eq 'foo', 'Api key accessor works' );
$pfm->user_key( 'monkey' );
ok( $pfm->user_key eq 'monkey', 'Can re-assign the user key' );
