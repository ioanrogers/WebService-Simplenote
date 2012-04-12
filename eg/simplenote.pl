#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

use WebService::Simplenote;
use WebService::Simplenote::Note;

my $email    = shift;
my $password = shift;

my $sn = WebService::Simplenote->new(
    email    => $email,
    password => $password,
);

my $notes = $sn->get_remote_index;

foreach my $note_id (keys %$notes) {
    say "Retrieving note id [$note_id]";
    my $note = $sn->get_note($note_id);
    printf "[%s] %s\n %s\n",
        $note->modifydate->iso8601,
        $note->title,
        $note->content;
    $sn->delete_note($note_id);
}

my $new_note = WebService::Simplenote::Note->new(
    content => "Some stuff",
);

#$sn->put_note($new_note);
