package # hide from pause
    Net::CLI::Interact::Transport::Telnet::Options;
use Moose;

has 'host' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

use Moose::Util::TypeConstraints;
coerce 'Net::CLI::Interact::Transport::Telnet::Options'
    => from 'HashRef[Any]'
        => via { Net::CLI::Interact::Transport::Telnet::Options->new($_) };

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

package Net::CLI::Interact::Transport::Telnet;
BEGIN {
  $Net::CLI::Interact::Transport::Telnet::VERSION = '1.110890';
}

use Moose;
with 'Net::CLI::Interact::Role::Transport';

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::Telnet::Options',
    coerce => 1,
    required => 1,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    default => 'telnet',
    required => 0,
);

sub runtime_options {
    # simple, for now
    return (shift)->connect_options->host;
}

1;

# ABSTRACT: TELNET based CLI connection


__END__
=pod

=head1 NAME

Net::CLI::Interact::Transport::Telnet::Options - TELNET based CLI connection

=head1 VERSION

version 1.110890

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of the TELNET application
for use by L<Net::CLI::Interact>.

=head1 INTERFACE

=head2 app

Defaults to C<telnet> but can be changed to the name of the local application
which provides TELNET.

=head2 runtime_options

Based on the C<connect_options> hash provided to C<Net::CLI::Interact> on
construction, selects attributes to provide to C<app> on the command line.
Supported attributes:

=over 4

=item host

Host name or IP address of the host to which the TELNET application is to
connect.

=back

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Role::Transport>

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

