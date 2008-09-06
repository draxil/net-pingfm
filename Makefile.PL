use inc::Module::Install;
use strict;

name 'Net-PingFM';
all_from 'lib/Net/PingFM.pm';

# prompt user to see if they want to run online tests?
my $prompt = "Online tests will need api/user keys and an internet connection.\n Don't worry the tests (should not) post anything as we'll send posts with the debug flag!\nRun online tests?";
my $run_online_tests = prompt $prompt, 'n';
my ( $api_key, $user_key ) = @_;

# if yes, prompt for user & api keys:
if ( $run_online_tests eq 'y' ) {
     $api_key = prompt 'Api key?';
     $user_key = prompt 'User key?';

    unless( $user_key && $api_key ){
        print qq|Don't have information to run online tests. Skipping them!\n|;
    }
}

# online tests run/don't run on the basis of the file t/run_online_tests
my $online_test_file = 't/run_online_tests';

# write test user/key info to cause online tests to be run
if ( $api_key && $user_key ) {
    open( OT, '>',  $online_test_file );
    print OT join ',', $api_key, $user_key;
    print OT "\n";
    close( OT );
}
# otherwise.. Ensure online tests file is removed.
else {
    unlink $online_test_file;
}


# ok, do the hard work!
WriteAll;

#fin#

