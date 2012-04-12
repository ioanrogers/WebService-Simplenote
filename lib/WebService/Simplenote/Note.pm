package WebService::Simplenote::Note;

# ABSTRACT: represents an individual note

use v5.10;
use Moose;
use MooseX::Types::DateTime qw/DateTime/;
use DateTime;
use MooseX::Storage;
use Log::Any qw//;
use namespace::autoclean;

with Storage( 'format' => 'JSON', traits => [qw|OnlyWhenBuilt|] );

has logger => (
    is       => 'ro',
    isa      => 'Object',
    lazy     => 1,
    required => 1,
    default  => sub { return Log::Any->get_logger },
    traits   => ['DoNotSerialize'],
);

# set by server
has key => (
    is  => 'rw',
    isa => 'Str',

    #required => 1,
);

# set by server
has [ 'sharekey', 'publishkey' ] => (
    is  => 'ro',
    isa => 'Str',
);

has title => (
    is  => 'rw',
    isa => 'Str',
);

has deleted => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has [ 'createdate', 'modifydate' ] => (
    is     => 'rw',
    isa    => DateTime,
    coerce => 1,
);

# set by server
has [ 'syncnum', 'version', 'minversion' ] => (
    is  => 'rw',
    isa => 'Int',
);

has tags => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has systemtags => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },

    # pinned, unread, markdown, list
);

# XXX: always coerce to utf-8?
has content => (
    is      => 'rw',
    isa     => 'Str',
    trigger => \&_get_title_from_content,
);

MooseX::Storage::Engine->add_custom_type_handler(
    'DateTime' => (
        expand   => sub { $_[0] },
        collapse => sub { $_[0]->epoch }
    )
);

# TODO: auto change title on content change?
sub _get_title_from_content {
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

    $self->title( $title );

    return 1;
}

__PACKAGE__->meta->make_immutable;

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


