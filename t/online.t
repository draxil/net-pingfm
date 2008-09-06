#!/usr/bin/perl -T

use strict;
use Net::PingFM;
use Test::More;

my ( $api_key, $user_key );
my $online_test_file = 't/run_online_tests';


if ( -f $online_test_file ) {
    open( OT, '<', $online_test_file );
    my $raw_line = <OT>;
    chomp $raw_line;
    ( $api_key, $user_key ) = split ',', $raw_line;
}

# decide on a plan!
if ( ! $api_key || ! $user_key ) {
    plan( skip_all => 'Skipping network tests!' );
}
else {
    plan( tests => 9 );
}


# OK, now we can test! Woo!

my $pfm = Net::PingFM->new(
    api_key => $api_key,
    user_key => $user_key,
    debug_mode => 1, # we won't actually post anything to your account
);

ok( $pfm , 'Object with api/user & debug is ok!' );
ok( $pfm->user_validate, 'User validate' );

my $pfm_bad_user = Net::PingFM->new(
    api_key => $api_key,
    user_key => 'FOO'. $user_key,
    debug_mode => 1, # we won't actually post anything to your account
);

ok( ! $pfm_bad_user->user_validate, 'Bad user, no validate!' );

ok( $pfm->post( 'Test!' ), 'Basic post!');
ok( $pfm->post( 'Test!', { post_method => $_ }), 'Post with '.$_.' method' )
                                                for( 'status', 'microblog' );
ok( ! $pfm->post( 'Test!', { post_method => 'blog' }) && $pfm->last_error,
    'Post with blog method produces error with no subject' );
ok( eval{$pfm->post( 'test', { post_method => 'blog', title => 'foo' })},
    'Post with blog method' );
eval{ $pfm->post( 'Test!', {post_method => 'monlkey'} ); };
ok( $@, 'Die on bad method!' );

