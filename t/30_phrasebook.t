#!/usr/bin/perl

use strict; use warnings FATAL => 'all';
use Test::More 0.88;

use lib 't/lib';
use Net::CLI::Interact;

my $s = new_ok('Net::CLI::Interact' => [{
    transport => 'Test',
    personality => 'testing',
    add_library => 't/phrasebook',
}]);

my $pb = $s->phrasebook;

ok(eval { $pb->prompt('TEST_PROMPT_ONE') }, 'prompt exists');
ok(! eval { $pb->prompt('TEST_PROMPT_XXX') }, 'prompt does not exist');

my $p = $pb->prompt('TEST_PROMPT_ONE');
isa_ok($p, 'Net::CLI::Interact::ActionSet');

ok(eval { $pb->macro('TEST_MACRO_ONE') }, 'macro exists');
ok(! eval { $pb->macro('TEST_MACRO_XXX') }, 'macro does not exist');

my $m = $pb->macro('TEST_MACRO_ONE');
isa_ok($m, 'Net::CLI::Interact::ActionSet');

ok($s->set_phrasebook({ personality => 'cisco' }), 'new phrasebook loaded');
$pb = $s->phrasebook;

ok(eval { $pb->prompt('basic') }, 'prompt exists');
ok(! eval { $pb->prompt('basic_XXX') }, 'prompt does not exist');

my $p2 = $pb->prompt('privileged');
isa_ok($p2, 'Net::CLI::Interact::ActionSet');

ok(eval { $pb->macro('begin_privileged') }, 'macro exists');
ok(! eval { $pb->macro('begin_privileged_XXX') }, 'macro does not exist');

my $m2 = $pb->macro('end_privileged');
isa_ok($m2, 'Net::CLI::Interact::ActionSet');

done_testing;
