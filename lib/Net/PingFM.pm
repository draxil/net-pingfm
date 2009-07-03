=head1 NAME

Net::PingFM - Interact with ping.fm from perl

=head1 SYNOPSIS

 # Make pingfm object with our user and api keys:
 my $pfm = Net::PingFM->new( user_key => 'blah',
                            api_key => 'foo' );
 
 # check they like our keys (you don't need to do this!)
 $pfm->user_validate or die 'Couldn\'t log in to ping.fm!';

 # make a post using our default method:
 $pfm->post( 'Hello ping.fm!' );
 
 # make a microblog post:
 $pfm->post( 'Testing Net::PingFM' , { method => 'microblog' } );
 
 # make a real blog post, with title and everything!
 $pfm->post( 'Testing Net::PingFM. Hours of fun..',
             { method => 'blog', title => 'Testing Testing!'} );
 
 # get the list of services for the account:
 my @services = $pfm->services;



=head1 DESCRIPTION

Simple little module for posting to http://ping.fm/

=head1 STATUS

Currently the library can do basic posting to different services, and that's
about it!

=head1 CONSTRUCTOR

Your user and application keys are required). Module will die without them.

 my $pfm = Net::PingFM->new( api_key => 'blah', user_key => 'blah' );

The API key is your developer api key which you get from ping.fm and is
associated with your app, and the user key is the key to authenticate you with
a particular account. See the L<<a
href='http://groups.google.com/group/pingfm-developers/web/api-documentation'>api
docs</a>> for more details.

Additional constructor parameters:

=over

=item * debug_mode => 1,
 # will stop posts from actually appearing

=item * dump_responses => 1
# will cause us to print our XML responses for debug

=back

=cut

package Net::PingFM;

use strict; # moose will do this anyway, but...
use Moose;
use Moose::Util::TypeConstraints;

require 5.008;

use Readonly;
use LWP;
use Hash::Util qw{ lock_hash };
use XML::Twig;
use Carp;

# our internals:
use Net::PingFM::Service;

# moose attribute defininitions
has api_key => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);
has user_key => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);
has debug_mode => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has dump_responses => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has _lwp => (
    is => 'ro',
    isa => 'LWP::UserAgent',
    lazy => 1,
    builder => '__lwp',
);

has last_error => (
    is => 'ro',
    isa => 'Str',
    writer => '_last_error',
);


# supply a class to use in place of LWP ( for testing )
has _use_lwp_replacement => (
    is => 'rw',
    default => 0,
);

# save our posts for test script inspection:
has '_debug_save_last_post' => (
    is => 'rw',
    default => 0,
);

has '_debug_last_post' => (
    is => 'rw',
);



our $VERSION = '0.4_002';

# constants #
Readonly my $PINGFM_URL => 'http://api.ping.fm/v1/';
Readonly my $UAGENT => 'PerlNetPingFM/' . $VERSION;

# request definitions #
Readonly my $USER_VALIDATE => 'user.validate';
Readonly my $USER_POST => 'user.post';
Readonly my $SERVICES => 'user.services';

Readonly my %REQUESTS => (
    $USER_VALIDATE => 1,
    $USER_POST => 1,
    $SERVICES => 1,
);
lock_hash( %REQUESTS );


=head1 METHODS


=head2 user_validate

 if ( $pfm->user_validate ){
    # we have a valid user key
 }
 else{
   # we don't!
 }

Validate the user's application key. Returns true value if the user key is OK
and false otherwise.

=cut

sub user_validate{
    my $self = shift;
    my $rsp = $self->_request( $USER_VALIDATE );
    __rsp_ok( $rsp );
}


=head2 post

 $pfm->post( $body , \%optional_params );
 $pfm->post( 'Hacking on Net::PingFM', { post_method => 'status' });
 $pfm->post( 'Posting using my default method' );
 $pfm->post( 'Hacking on Net::PingFM, don\'t tell facebook', { service => 'twitter' });

Make a post! We at least need a $body which is the body of the post we'll send
to ping.fm.

Optional parameter hashref can contain:

=over

=item * post_method => What you would like to post to.

=item * method => shorthand for post_method

Valid post_method's are blog, microblog, status and default. Default will use
your default post method on ping.fm. Default is our default! 'method' is a
less cumbersome option to type, if for some reason you choose to use both
parameters then 'post_method' is the one which will be used.

=item * title => The title for the post. Ping.fm requires this for post_method
'blog' but we don't enforce that in the module!

=item * service => Just post to one service. Fot the value  use the service id
or a Net::PingFM::Service object.

=back

=cut
Readonly our %VALID_POST_PARAMS => (
    post_method => 1, title => 1, service => 1
);
Readonly our %VALID_POST_METHODS => (
    default => 1, blog => 1, microblog => 1, status => 1,
);

sub post {
    my $self = shift;
    my $body = shift or confess 'Need a post body!';
    my $opts = shift || {};

    my %ARGS;

    # fill in the main post body:
    $ARGS{body} = $body;

    # what kind of post?:
    $ARGS{post_method} = $opts->{post_method} || $opts->{method};
    $ARGS{post_method} ||= 'default';

    # validate post_method
    exists $VALID_POST_METHODS{ $ARGS{post_method} }
    	or confess 'Invalid post method: ' . $ARGS{post_method};


    if ( $opts->{service}
         && ( my $service = __parse_service_opt( $opts->{service} )))
    {
        $ARGS{ service } = $service;
    }

    # copy in misc. options:
    for ( 'title', ) {
    	if ( exists $opts->{$_} ) {
            $ARGS{$_}  = $opts->{$_};
        }
    }

    # do the request!
    my $response = $self->_request( $USER_POST, \%ARGS );
    return __rsp_ok( $response );
}

# work out what we were given
sub __parse_service_opt{
    my $so = shift;

    # maybe a service object?:
    if ( ref  $so ) {
        if ( $so->isa( 'Net::PingFM::Service' ) ) {
            return $so->id;
        }
        confess 'Can\'t use a reference for your "service" unless that reference is a Net::PingFM::Service. What you provided seems to be a :'. ref $so;
    }

    # probably a service id:
    return $so;
}

=head2 services

 my @services = $pfm->services;

Get a list of services for this account.

Returns a list of Net::PingFM::Service objects

=cut
sub __service_xml_to_object;
sub services{
    my $self = shift;
    my $rsp = $self->_request( $SERVICES );

    # bail if we've failed:
    if ( ! __rsp_ok( $rsp )) {
        return;
    }

    # otherwise build our response
    return map{ __service_xml_to_object }
           $rsp->get_xpath( './services/service' );
}

sub __service_xml_to_object{
    my @c_args;

    # direct properties of the service object:
    foreach my $prop ( 'id', 'name' ) {
        if ( my $val = $_->att( $prop )) {
            push @c_args, $prop => $val;
        }
    }

    # deal with the strings:
    foreach my $prop ( 'trigger', 'url', 'icon' ) {
        if ( my $val = $_->first_child_text( $prop ) ) {
            push @c_args, $prop => $val;
        }
    }

    # now the list of methods:
    if ( my $methods = $_->first_child_text( 'methods' ) ) {
        push @c_args, 'methods' => [ split ',', $methods ];
    }

    # make object!
    return Net::PingFM::Service->new( @c_args  );
}

=head2 last_error

Last error message we were sent from ping.fm

=cut

###INTERNALS###

sub _request{
    my $self = shift;

    # collect and validate args #
    my ( $request ) = shift or confess 'Need $request!';
    my $extras = shift || {};

    exists $REQUESTS{$request} or confess qq+Unknown request $request+;

    my $raw_rsp = $self->_web_request( $request, $extras );

    # parse response:
    my $twig = XML::Twig->new();
    eval{
        $twig->parse( $raw_rsp );
    };
    if ( $@ ) {
        die join '', "Error parsing response for '$request': $@";
    }

    # dump response? 
    if ( $self->dump_responses ) {
        print $twig->sprint, "\n";
    }

    my $rsp = $twig->root;

    # maybe have a fit if our XML doesn't look right
    if ( ! __valid_rsp( $rsp ) ) {
        die 'Invalid XML response!';
    }

    if ( $rsp->first_child_text( 'method' ) ne $request ) {
        warn 'Response method doesn\'t match request method. Something has probably gone wrong!';
    }

    # possibly stash an error message
    if ( ! __rsp_ok( $rsp ) ) {
        if ( my $msg = $rsp->first_child_text( 'message' ) ) {
            $self->_last_error( $msg );
        }
        else {
            $self->_last_error( 'None set' );
        }
    }

    return $rsp;
}

# handle the nuts'n'bolts of talking over the web
sub _web_request{
    my $self = shift;
    my ( $request, $extra_params ) = @_
    	or confess 'Need $request and $extra_params';

    my $lwp;

    # get our lwp user agent
    unless ( $lwp = $self->_use_lwp_replacement ) {
        $lwp = $self->_lwp();
    }

    # form always takes user & api keys:
    my %form = (
        user_app_key => $self->user_key,
        api_key => $self->api_key,
        debug => $self->debug_mode,
        %$extra_params,
    );

    # are we recording things for tests?
    if ( $self->_debug_save_last_post ) {
        $self->_debug_last_post( \%form );
    }

    # make a url for this request:
    my $url =  __request_url( $request );

    # POST!
    my $response = $lwp->post( $url, \%form );

    # handle failure:
    if ( ! $response || ! $response->is_success ) {
        die join '', "Request '$request' failed to $url",
                     ( $response ? ( ': ', $response->status_line )
                                 : '.' );
    }

    return $response->content;
}

# make a lwp request object
sub __lwp{
    my $ua = LWP::UserAgent->new();
    $ua->agent( $UAGENT );
    return $ua;
}

# build the url for a parictular request
sub __request_url{
    my $request = shift;
    return join '' => $PINGFM_URL, $request;
}

# check response OK/Fail status
sub __rsp_ok{
    my $rsp = shift;
    $rsp->att( 'status' ) eq 'OK';
}

# check rsp looks like a rsp
sub __valid_rsp{
    my $rsp = shift;
    return $rsp->tag eq 'rsp' && $rsp->att('status');
}

no Moose;

;1;
__END__

=head1 ERROR HANDLING

If something goes wrong at the network or XML parsing level the methods will
die. If things go wrong at the API level, as in ping.fm gives us an actual
error then the method will generally return false and set last_error with an
error message from ping.fm.

=head1 MOOSE!

This is implemented using moose, so can be messed with in a moosey way if you
feel like it!

=head1 API INFO

http://groups.google.com/group/pingfm-developers/web/api-documentation

=head1 DEVELOPMENT

Follow development of this library (and or fork it!) on github:

http://github.com/draxil/net-pingfm/

=head1 AUTHOR

Joe Higton

=head1 COPYRIGHT

Copyright 2008 Joe Higton

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

