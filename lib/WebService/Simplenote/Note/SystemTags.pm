package WebService::Simplenote::Note::SystemTags;

# ABSTRACT: handle systemtags

use v5.10.1;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
with 'WebService::Simplenote::Role::Note::SystemTags';

has markdown => ( is => 'rw', isa => Bool, default => sub {0} );
has pinned   => ( is => 'rw', isa => Bool, default => sub {0} );
has unread   => ( is => 'rw', isa => Bool, default => sub {1} );
has list     => ( is => 'rw', isa => Bool, default => sub {0} );

sub is_markdown {
    return shift->markdown;
}

sub set_markdown {
    my ($self, $arg) = @_;
    $arg //= 1; # no args always turns it on
    $self->markdown($arg);
    return 1;
}

sub is_pinned {
    return shift->pinned;
}

sub set_pinned {
    my ($self, $arg) = @_;
    $arg //= 1; # no args always turns it on
    $self->pinned($arg);
    return 1;
}

sub is_unread {
    return shift->unread;
}

sub set_unread {
    my ($self, $arg) = @_;
    $arg //= 1; # no args always turns it on
    $self->unread($arg);
    return 1;
}

sub is_list {
    return shift->list;
}

sub set_list {
    my ($self, $arg) = @_;
    $arg //= 1; # no args always turns it on
    $self->list($arg);
    return 1;
}

sub to_array {
    my $self = shift;
    
    my @systemtags;
    foreach my $systemtag (qw/markdown pinned unread list/) {
        my $method = "is_$systemtag";
        if ($self->$method) {
            push @systemtags, $systemtag;
        }
    }
    
    return \@systemtags;
}

1;
