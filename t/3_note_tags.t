#!/usr/bin/env perl -w

use Test::More; #tests => 6;

use WebService::Simplenote::Note;
use DateTime;
use Data::Printer;

my $date = DateTime->now;

my $note = WebService::Simplenote::Note->new(
    createdate => $date,
    modifydate => $date->epoch,
    content    => "# Some Content #\n This is a test",
);

ok(!$note->is_markdown, 'NOT flagged markdown');
ok($note->set_markdown, 'Setting markdown');
ok($note->is_markdown, 'IS flagged markdown');
ok($note->set_markdown(0), 'UNsetting markdown');
ok(!$note->is_markdown, 'NOT flagged markdown again');

ok(!$note->is_pinned, 'NOT pinned');
ok($note->set_pinned, 'Pinning');
ok($note->is_pinned, 'IS pinned');
ok($note->set_pinned(0), 'UNpinning');
ok(!$note->is_pinned, 'NOT pinned again');

ok(!$note->is_list, 'NOT list');
ok($note->set_list, 'Setting list');
ok($note->is_list, 'IS list');
ok($note->set_list(0), 'UNsetting list');
ok(!$note->is_list, 'NOT list again');

ok($note->is_unread, 'IS unread');
ok($note->set_unread(0), 'UNsetting unread');
ok(!$note->is_unread, 'NOT unread');
ok($note->set_unread, 'Setting unread');
ok($note->is_unread, 'IS unread again');
p $note;
done_testing;
