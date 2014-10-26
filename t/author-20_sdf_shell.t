#!/usr/bin/perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}


use strict; use warnings FATAL => 'all';
use Test::More 0.88;

BEGIN { use_ok( 'Net::CLI::Interact') }

my $s = Net::CLI::Interact->new(
    transport => 'SSH',
    ($^O eq 'MSWin32' ?
        (app => '..\..\..\Desktop\plink.exe') : () ),
    connect_options => { host => 'ollyg@sdf.org' },
    personality => 'sdf',
);

ok($s->macro('sdf_login', { params => [$ENV{SDF_PASS} || 'letmein'] }),
    'logged in using SSH');

ok( $s->cmd('ls -la'), 'ran ls -la' );

like( $s->last_prompt, qr{sdf:/udd/o/ollyg> $}, 'command ran and prompt looks ok' );

my @out = $s->last_response;
cmp_ok( scalar @out, '>=', 5, 'sensible number of lines in the command output');

done_testing;
