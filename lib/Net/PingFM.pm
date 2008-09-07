=head1 NAME

Net::PingFM - Interact with ping.fm from perl

=head1 SYNOPSIS

my $pfm = Net::PingFM->new( user_key => 'blah',
                            api_key => 'foo' );


=head1 DESCRIPTION

Simple little module for posting to http://ping.fm/

=head1 STATUS

Currently the library can do basic posting to different services, and that's
about it!

=head1 CONSTRUCTOR

 Your user and application keys are required). Module will die without them.

my $pfm = Net::PingFM->new( api_key => 'blah', user_key => 'blah' );

Additional constructor parameters:

debug_mode => 1, # will stop posts from actually appearing
dump_responses => 1 # will cause us to print our XML responses for debug


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

no Moose;

our $VERSION = '0.2';

# constants #
Readonly my $PINGFM_URL => 'http://api.ping.fm/v1/';
Readonly my $UAGENT => 'PerlNetPingFM/' . $VERSION;

# request definitions #
Readonly my $USER_VALIDATE => 'user.validate';
Readonly my $USER_POST => 'user.post';
Readonly my %REQUESTS => (
    $USER_VALIDATE => 1,
    $USER_POST => 1,
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


=head2 post( $body , \%optional_params )

Post! We at least need a $body which is the body of the post we'll send to
ping.fm.

Optional parameter hashref can contain:

post_method => What you would like to post to.

Valid post_method's are blog, microblog, status and default. Default will use your default post method on ping.fm. Default is our default!

title => The title for the post. Ping.fm requires this for post_method 'blog' but we don't enforce that in the module!

service => Just post to one service

=cut
Readonly my %VALID_POST_PARAMS => (
    post_method => 1, title => 1, service => 1
);
Readonly my %VALID_POST_METHODS => (
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
    $ARGS{post_method} = $opts->{post_method};
    $ARGS{post_method} ||= 'default';

    # validate post_method
    exists $VALID_POST_METHODS{ $ARGS{post_method} }
    	or confess 'Invalid post method: ' . $ARGS{post_method};

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

    # dump responses:
    if ( $self->dump_responses ) {
        print $twig->sprint, "\n";
    }

    my $rsp = $twig->root;

    # maybe have a fit if our XML doesn't look right
    if ( ! __valid_rsp( $rsp ) ) {
        die 'Invalid XML response!';
    }

    # possibly stash an error message
    if ( ! __rsp_ok( $rsp ) ) {
        if ( my $msg = $rsp->first_child_text('message') ) {
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

    my $lwp = $self->_lwp();

    # form always takes user & api keys:
    my %form = (
        user_app_key => $self->user_key,
        api_key => $self->api_key,
        debug => $self->debug_mode,
        %$extra_params,
    );

    my $url =  __request_url( $request );
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

;1;
__END__

=head1 ERROR HANDLING

If something goes wrong at the network or XML parsing level the methods will
die. If thing go wrong at the API level, as in ping.fm gives us an actual
error then the method will generally return false and set last_error with an
error message from ping.fm.

=head1 API INFO

http://groups.google.com/group/pingfm-developers/web/api-documentation

=head1 AUTHOR

Joe Higton

=head1 COPYRIGHT

Copyright 2008 Joe Higton

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

