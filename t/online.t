#!/usr/bin/perl -T

# try setting default method to blog, we'll probably fail as the default
# tests don't use a title.

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
    plan( tests => 16 );
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

# test shorthand 'method'
ok( $pfm->post('test!', {method => 'status'}), 'using method seems to work');
ok( !$pfm->post( 'test!', {method => 'blog'}), 'Shorthand still makes an error for blog with no title');



# specifically test the synopsis except use our pfm for the online bits!
my $spfm = Net::PingFM->new( user_key => 'blah',
                            api_key => 'foo' );
ok( $spfm, 'synopsis made an object' );

# check they like our keys (you don't need to do this!)
ok( $pfm->user_validate or die 'Couldn\'t log in to ping.fm!', 'synopsis: logincheck');

# make a post using our default method:
ok( $pfm->post( 'Hello ping.fm!' ), 'Synopsis: post' );
 
 # make a microblog post:
ok( $pfm->post( 'Testing Net::PingFM' , { method => 'microblog' } ), 'Synopsis: microblog' );

# make a real blog post, with title and everything!
ok( $pfm->post( 'Testing Net::PingFM. Hours of fun..',
             { method => 'blog', title => 'Testing Testing!'} ),
    'Synopsis: blog!' );
