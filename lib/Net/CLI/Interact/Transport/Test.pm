package # hide from pause
    Net::CLI::Interact::Transport::Test::Options;
use Moose;

use Moose::Util::TypeConstraints;
coerce 'Net::CLI::Interact::Transport::Test::Options'
    => from 'HashRef[Any]'
        => via { Net::CLI::Interact::Transport::Test::Options->new($_) };

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

package Net::CLI::Interact::Transport::Test;
BEGIN {
  $Net::CLI::Interact::Transport::Test::VERSION = '1.110890';
}

use Moose;
with 'Net::CLI::Interact::Role::Transport';

has 'connect_options' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Transport::Test::Options',
    default => sub { {} },
    coerce => 1,
    required => 1,
);

has 'app' => (
    is => 'ro',
    isa => 'Str',
    default => $^X,
    required => 0,
);

#sub _which_perl {
#    use Config;
#    $secure_perl_path = $Config{perlpath};
#    if ($^O ne 'VMS')
#        {$secure_perl_path .= $Config{_exe}
#            unless $secure_perl_path =~ m/$Config{_exe}$/i;}
#    return $secure_perl_path;
#}

sub runtime_options {
    return ('-ne', 'BEGIN { $| = 1 }; print $_, time, "\nPROMPT>\n";');
}

1;

# ABSTRACT: Testable CLI connection


__END__
=pod

=head1 NAME

Net::CLI::Interact::Transport::Test::Options - Testable CLI connection

=head1 VERSION

version 1.110890

=head1 DECRIPTION

This module provides an L<IPC::Run> wrapped instance of Perl which simply
echoes back any input provided. This is used for the L<Net::CLI::Interact>
test suite.

=head1 INTERFACE

=head2 app

Defaults to the value of C<$^X>.

=head2 runtime_options

Returns Perl options which turn it into a C<cat> emulator:

 -pe 'BEGIN { $| = 1 }'

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

