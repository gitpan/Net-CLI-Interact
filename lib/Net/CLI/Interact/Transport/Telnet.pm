package Net::CLI::Interact::Transport::Telnet;
BEGIN {
  $Net::CLI::Interact::Transport::Telnet::VERSION = '1.111150';
}

{
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
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

use Moose;
extends 'Net::CLI::Interact::Transport';

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::Telnet::Options',
    coerce => 1,
    required => 1,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_app {
    my $self = shift;
    confess "please pass location of plink.exe in 'app' parameter to new()\n"
        if $^O eq 'MSWin32';
    return 'telnet'; # unix
}

sub runtime_options {
    return (
        ($^O eq 'MSWin32' ? '-telnet' : ()),
        (shift)->connect_options->host,
    );
}

1;

# ABSTRACT: TELNET based CLI connection


__END__
=pod

=head1 NAME

Net::CLI::Interact::Transport::Telnet - TELNET based CLI connection

=head1 VERSION

version 1.111150

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of a TELNET client for
use by L<Net::CLI::Interact>.

=head1 INTERFACE

=head2 app

On Windows platforms you B<must> download the C<plink.exe> program, and pass its
location to the library in this parameter. On other platforms, this defaults to
C<telnet>.

=head2 runtime_options

Based on the C<connect_options> hash provided to Net::CLI::Interact on
construction, selects and formats parameters to provide to C<app> on the
command line. Supported attributes:

=over 4

=item host (required)

Host name or IP address of the host to which the TELNET application is to
connect.

=back

=head1 COMPOSITION

See the following for further interface details:

=over 4

=item *

L<Net::CLI::Interact::Transport>

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

