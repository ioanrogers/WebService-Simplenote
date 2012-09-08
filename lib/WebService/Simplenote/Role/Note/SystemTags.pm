package WebService::Simplenote::Role::Note::SystemTags;

# ABSTRACT: handle systemtags

use v5.10.1;
use Moo::Role;

requires qw/
    is_markdown set_markdown is_pinned set_pinned
    is_unread   set_unread   is_list   set_list
/;

1;
