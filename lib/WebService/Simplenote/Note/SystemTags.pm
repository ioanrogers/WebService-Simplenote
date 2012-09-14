package WebService::Simplenote::Note::SystemTags;

# ABSTRACT: handle systemtags

use v5.10.1;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use Method::Signatures;
with 'WebService::Simplenote::Role::Note::SystemTags';

has markdown => ( is => 'rw', isa => Bool, default => sub {0} );
has pinned   => ( is => 'rw', isa => Bool, default => sub {0} );
has unread   => ( is => 'rw', isa => Bool, default => sub {0} );
has list     => ( is => 'rw', isa => Bool, default => sub {0} );

method is_markdown {
    return $self->markdown;
}

method set_markdown($arg = 1) {
    $self->markdown($arg);
    return 1;
}

method is_pinned {
    return $self->pinned;
}

method set_pinned($arg = 1) {
    $self->pinned($arg);
    return 1;
}

method is_unread {
    return $self->unread;
}

method set_unread($arg = 1) {
    $self->unread($arg);
    return 1;
}

method is_list {
    return $self->list;
}

method set_list($arg = 1) {
    $self->list($arg);
    return 1;
}

method has_systemtags {
    foreach my $systemtag (qw/markdown pinned unread list/) {
        my $method = "is_$systemtag";
        if ($self->$method) {
            return 1;
        }
    }
    return 0;
}

method to_array {
    my @systemtags;
    foreach my $systemtag (qw/markdown pinned unread list/) {
        my $method = "is_$systemtag";
        if ($self->$method) {
            push @systemtags, $systemtag;
        }
    }
    return wantarray ? @systemtags : \@systemtags;
}

method to_string {
    return join ',', $self->to_array;
}

1;
