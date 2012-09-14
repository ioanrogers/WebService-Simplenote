package WebService::Simplenote::Note::Tags;

# ABSTRACT: handle tags

use v5.10.1;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use Method::Signatures;

with qw/
    WebService::Simplenote::Role::Note::Tags
    WebService::Simplenote::Role::Logger
/;

sub BUILDARGS {
    my ($class, @args) = @_;

    if (!defined $args[0]) {
        # empty, do nothing
        return {};
    } elsif (ref $args[0] eq 'ARRAY') {
        # a single araryref should be converted to a hashref
        my %tags = map { $_ => 1 } @{$args[0]};
        return { tags => \%tags };
    }
};

has tags => ( is => 'ro', isa => HashRef[Str], default => sub {{}} );

# takes a string or arrayref of strings
method add_tag($tags) {
    given (ref $tags) {
        when (!$_) {
            $self->_add_tag($tags) || return 0;
        }
        when ('ARRAY') {
            foreach my $tag (@$tags) {
                $self->_add_tag($tag) || return 0;
            }
        }
        default { return 0 }
    };
    return 1;
}

method _add_tag(Str $tag) {
    if  (exists $self->tags->{$tag} ) {
        $self->logger->warn("Trying to add already existing tag: [$tag]");
        return 0;
    }
    $self->tags->{$tag} = 1;
    return 1;
}

method remove_tag($tags) {
    given (ref $tags) {
        when (!$_) {
            delete $self->tags->{$tags};
        }
        when ('ARRAY') {
            delete @{$self->tags}{@$tags};
        }
        default { return 0 }
    };
    return 1;
}

method has_tags {
    if (scalar keys %{$self->tags} > 0) {
        return 1;
    }
    return 0;
}

method to_array {
    my @tags;
    foreach my $tag ( keys %{$self->tags} ) {
        push @tags, $tag;
    }
    return wantarray ? @tags : \@tags;
}

method to_string {
    return join ',', $self->to_array;
}

1;
