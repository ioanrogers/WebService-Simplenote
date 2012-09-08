package WebService::Simplenote::Note;

# ABSTRACT: represents an individual note

use v5.10.1;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use WebService::Simplenote::Types qw/:all/;
use WebService::Simplenote::Note::SystemTags;
use DateTime;
use JSON qw//;
use Log::Any qw//;
use List::Util qw/first/;
use Method::Signatures;
use Data::Printer;

with qw/WebService::Simplenote::Role::Logger/;

sub BUILDARGS {
    my ($class, @args) = @_;
    
    # new can be called with a scalar containing JSON string, a hash or a hashref
    if (@args == 1 && !ref $args[0] ) {
        say $args[0];
        my $note = JSON->new->utf8->decode($args[0]);
        return $note;
    } elsif (@args == 1 && ref $args[0] eq 'HASH') {
        return $args[0];
    } else {
        return { @args };
    }
};

# set by server
has key        => ( is => 'rw', isa => Str ) ;
has publishkey => ( is => 'ro', isa => Str );
has sharekey   => ( is => 'ro', isa => Str );
has syncnum    => ( is => 'ro', isa => Int );
has version    => ( is => 'ro', isa => Int );
has minversion => ( is => 'ro', isa => Int );

has title   => ( is => 'rw', isa => Str );
has deleted => ( is => 'rw', isa => Bool, default => sub { 0 } );
# XXX: always coerce to utf-8?
has content => ( is => 'rw', isa => Str, trigger => 1 );

# XXX should default to DateTime->now?
# TODO DateTime type
has createdate => (
    is     => 'rw',
    isa    => WSSnDateTime,
    coerce => sub { WebService::Simplenote::Types::to_DateTime(shift) },
);

has modifydate => (
    is     => 'rw',
    isa    => WSSnDateTime,
    coerce => sub { WebService::Simplenote::Types::to_DateTime(shift) },
);

has tags => (
    is      => 'rw',
    isa     => ArrayRef[Str],
    default => sub { [] },
    # #handles => {
        # #add_tag     => 'push',
        # #join_tags   => 'join',
        # #has_tags    => 'count',
        # #has_no_tags => 'is_empty',
    # #},
);

has systemtags => (
    is      => 'rw',
    #isa     => ArrayRef[WSSnSystemTag],
    isa     => Object,
    default => sub {WebService::Simplenote::Note::SystemTags->new },
    handles => 'WebService::Simplenote::Role::Note::SystemTags',
    coerce =>  sub {
        if (ref $_[0] ne 'ARRAY') {
            return $_[0];
        }
        my %tags = map { $_ => 1 } @{$_[0]};
        return WebService::Simplenote::Note::SystemTags->new(%tags);
    },
);

method serialise {
    $self->logger->debug('Serialising note using: ', JSON->backend);
    my $json = JSON->new;
    $json->allow_blessed;
    $json->convert_blessed;
    my $serialised_note = $json->utf8->encode($self);

    return $serialised_note;
}

method TO_JSON {
    my %hash = %{$self};
    
    # convert dates, if present
    if (exists $hash{createdate}) {
        $hash{createdate} = $self->createdate->epoch;
    }

    if (exists $hash{modifydate}) {
        $hash{modifydate} = $self->modifydate->epoch;
    }

    delete $hash{logger}; # don't serialise the logger
    
    $hash{systemtags} = $self->systemtags->to_array;
    
    return \%hash;
}

sub _trigger_content {
    my $self = shift;

    my $content = $self->content;

    # First line is title
    $content =~ /(.+)/;
    my $title = $1;

    # Strip prohibited characters
    # XXX preferable encoding scheme?
    chomp $title;

    # non-word chars to space
    $title =~ s/\W/ /g;

    # trim leading and trailing spaces
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;

    $self->title($title);

    return 1;
}

1;

=head1 SYNOPSIS

  use WebService::Simplenote::Note;

  my $note = WebService::Simplenote::Note->new(
      content => "Some stuff",
  );

  printf "[%s] %s\n %s\n",
      $note->modifydate->iso8601,
      $note->title,
      $note->content;
  }

=head1 DESCRIPTION

This class represents a note suitable for use with Simplenote. You should read the 
L<Simplenote API|http://simplenoteapp.com/api/> docs for full details

=head1 METHODS

=over

=item WebService::Simplenote::Note->new($args)

The minimum required attribute to set is C<content>.

=item add_tag($str)

Push a new tag onto C<tags>.

=item set_markdown

Shortcut to set the C<markdown> system tag.

=item set_pinned

Shortcut to set the C<pinned> system tag.

=back

=head1 ATTRIBUTES

=over

=item logger

L<Log::Any> logger

=item key

Server-set unique id for the note.

=item title

Simplenote doesn't use titles, so we autogenerate one from the first line of content.

=item deleted

Boolean; is this note in the trash?

=item createdate/modifydate

Datetime objects

=item tags

Arrayref[Str]; user-generated tags.

=item systemtags

Arrayref[Str]; special tags.

=item content

The body of the note
