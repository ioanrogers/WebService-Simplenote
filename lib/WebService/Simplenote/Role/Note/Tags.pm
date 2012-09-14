package WebService::Simplenote::Role::Note::Tags;

# ABSTRACT: handle tags

use v5.10.1;
use Moo::Role;

requires qw/
    add_tag remove_tag has_tags
/;

1;
