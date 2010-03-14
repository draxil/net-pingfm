=head1 NAME

Net::PingFM::Trigger - Object which describes a ping fm trigger

=head1 DESCRIPTION

Ping.fm triggers let you post to multiple services

=head1 MISSING!

This object doesn't yet know which services a trigger contains. This will
hopefully be added soon!

=cut

package Net::PingFM::Trigger;

use strict; # For show as moose does this anyway
use Moose;
use Moose::Util::TypeConstraints;

=head1 ACCESSORS

=head2 id

Identifier for this trigger

=cut
has id => (
    is => 'rw',
    isa => 'Str',
);

=head2 method

Post method for this trigger: e.g microblog, status.

=cut
has method => (
    is => 'rw',
    isa => 'Str',
);

no Moose;
;1;
