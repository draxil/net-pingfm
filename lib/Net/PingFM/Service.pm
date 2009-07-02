=head1 NAME

Net::PingFM::Service - Class To Describe a ping.fm service

=head1 DESCRIPTION

Class to describe a ping.fm service, generaly spat out by Net::PingFM.

=head1 ACCESSORS

=cut

package Net::PingFM::Service;
use strict; # For show as moose does this anyway
use Moose;
use Moose::Util::TypeConstraints;


=head2 name

Name for this service

=cut

has 'name' => (
    is => 'ro',
    isa => 'Str',
);

=head2 id

id for this service

=cut

has 'id' => (
    is => 'ro',
    isa => 'Str',
);



=head2 trigger

Trigger for this service, such as '@fb'

=cut

has 'trigger' => (
    is => 'ro',
    isa => 'Str',
);

=head2 url

Url for this service, such as http://twitter.com

=cut

has 'url' => (
    is => 'ro',
    isa => 'Str'
);

=head2

Icon (url) for this service

=cut

has 'icon' => (
    is => 'ro',
    isa => 'Str',
);

subtype PingFM_method => as 'Str'
                      => where{ $_ =~ / blog | microblog | status /x };

=head2 can_blog

If we can use the blog method with this service returns 1 (true), otherwise
returns 0 (false)

=cut

has 'can_blog' => (
    is => 'ro',
    lazy => 1,
    builder => '_can_blog',
);

sub _can_blog{
    my $self = shift;
    return $self->methods_hash->{blog};
}


=head2 can_microblog

If we can use the microblog method with this service returns 1 (true), otherwise
returns 0 (false)

=cut

has 'can_microblog' => (
    is => 'ro',
    lazy => 1,
    builder => '_can_microblog',
);

sub _can_microblog{
    my $self = shift;
    return $self->methods_hash->{microblog};
}


=head2 can_status

If we can use the status method with this service returns 1 (true), otherwise
returns 0 (false)

=cut

has 'can_status' => (
    is => 'ro',
    lazy => 1,
    builder => '_can_status',
);

sub _can_status{
    my $self = shift;
    return $self->methods_hash->{status};
}

=head1 SECONDARY METHODS

Whilst these aren't "private" they're not really nessasery or required, but
feel free to use them if you want.

=cut

=head2 methods

List (reference) containing acceptable methods for this service (blog, microblog, status )

=cut

has 'methods' => (
    is => 'ro',
    isa => 'ArrayRef[PingFM_method]',
);

=head2 methods_hash

my $meths = $srv->methods_hash;

if( $meths->{blog} ){
   print 'we can blog';
}

Returns a hash reference where the keys are the method labels (blog,
microblog, status) and the values are 1 or 0. A value of 1 indicates that
method is available to the service zero indicates that it is not.

=cut

has 'methods_hash' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_methods_hash',
);

sub _methods_hash{
    my $self = shift;
    my %init = map { $_ => 0 } %Net::PingFM::VALID_POST_METHODS; 
    return { %init, map{ $_ => 1 } @{ $self->methods } };
}

no Moose;
;1;
__END__

=head1 AUTHOR

Joe Higton

=head1 COPYRIGHT

Copyright 2008 Joe Higton

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
