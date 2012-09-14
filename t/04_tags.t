#!/usr/bin/env perl -w

use Test::More;

use WebService::Simplenote::Note;
use DateTime;

my $date = DateTime->now;

my $note = WebService::Simplenote::Note->new(
    createdate => $date,
    modifydate => $date->epoch,
    content    => "# Some Content #\n This is a test",
);

ok(!$note->has_tags, 'Has NO tags');
ok($note->add_tag('chimpanzee'), 'Added a tag');
ok($note->has_tags, 'Has tags');

ok($note->add_tag([qw/gorilla orangutan/]), 'Added an array of tags');

ok($note->remove_tag([qw/chimpanzee orangutan/]), 'Removed an array of tags');
ok($note->remove_tag('gorilla'), 'Removed a tag');
ok(!$note->has_tags, 'Has NO tags');

done_testing;
