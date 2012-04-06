package WebService::Simplenote;

# ABSTRACT: Note-taking through simplenoteapp.com

# TODO: cache authentication token between runs, use LWP cookie_jar for auth token
# TODO: Net::HTTP::Spore?

our $VERSION = '0.001';

use v5.10;
use Moose;
use MooseX::Types::Path::Class;
use namespace::autoclean;

use LWP::UserAgent;
use Log::Any qw//;
use DateTime;
use MIME::Base64 qw//;
use JSON;
use Try::Tiny;
use Class::Load;

use WebService::Simplenote::Note;

has [ 'email', 'password' ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has token => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    builder  => '_build_token',
);

has notes => (
    is      => 'rw',
    isa     => 'HashRef[WebService::Simplenote::Note]',
    default => sub { {} },
);

has allow_server_updates => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
);

has logger => (
    is       => 'ro',
    isa      => 'Object',
    lazy     => 1,
    required => 1,
    default  => sub { return Log::Any->get_logger },
);

has _uri => (
    is       => 'ro',
    isa      => 'Str',
    default  => 'https://simple-note.appspot.com/api2',
    required => 1,
);

has _ua => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    default => sub {
        my $headers = HTTP::Headers->new( Content_Type => 'application/json', );
        return LWP::UserAgent->new(
            agent           => "WebService::Simplenote/$VERSION",
            default_headers => $headers,
        );
    },
);

# Connect to server and get a authentication token
sub _build_token {
    my $self = shift;

    my $content = MIME::Base64::encode_base64( sprintf 'email=%s&password=%s', $self->email, $self->password );

    $self->logger->debug( 'Network: get token' );

    # the login uri uses api instead of api2 and must always be https
    my $response = $self->_ua->post( 'https://simple-note.appspot.com/api/login', Content => $content );

    if ( !$response->is_success ) {
        die "Error logging into Simplenote server: " . $response->status_line . "\n";
    }

    return $response->content;
}

# Get list of notes from simplenote server
# TODO since, mark, length options
sub get_remote_index {
    my $self  = shift;
    my $notes = {};

    $self->logger->debug( 'Network: get note index' );
    my $req_uri  = sprintf '%s/index?auth=%s&email=%s', $self->_uri, $self->token, $self->email;
    my $response = $self->_ua->get( $req_uri );
    my $index    = decode_json( $response->content );

    $self->logger->debugf( 'Network: Index returned [%s] notes', $index->{count} );

    # iterate through notes in index and load into hash
    foreach my $i ( @{ $index->{data} } ) {
        $notes->{ $i->{key} } = WebService::Simplenote::Note->new( $i );
    }

    return $notes;
}

# Given a local file, upload it as a note at simplenote web server
sub put_note {
    my ( $self, $note ) = @_;

    if ( !$self->allow_server_updates ) {
        $self->logger->warn( 'Sending notes to the server is disabled' );
        return;
    }

    my $req_uri = sprintf '%s/data', $self->_uri;

    if ( defined $note->key ) {
        $self->logger->infof( '[%s] Updating existing note', $note->key );
        $req_uri .= '/' . $note->key,;
    } else {
        $self->logger->debug( 'Uploading new note' );
    }

    $req_uri .= sprintf '?auth=%s&email=%s', $self->token, $self->email;
    $self->logger->debug( "Network: POST to [$req_uri]" );

    my $content = $note->freeze;

    my $response = $self->_ua->post( $req_uri, Content => $content );

    if ( !$response->is_success ) {
        $self->logger->errorf( 'Failed uploading note: %s', $response->status_line );
        return;
    }

    my $note_tmp = WebService::Simplenote::Note->thaw( $response->content );

    # a brand new note will have a key generated remotely
    if ( !defined $note->key ) {
        return $note_tmp->key;
    }

    #TODO better return values
    return;
}

# Save local copy of note from Simplenote server
sub get_note {
    my ( $self, $key ) = @_;

    $self->logger->infof( 'Retrieving note [%s]', $key );

    # TODO are there any other encoding options?
    my $req_uri = sprintf '%s/data/%s?auth=%s&email=%s', $self->_uri, $key, $self->token, $self->email;
    my $response = $self->_ua->get( $req_uri );

    if ( !$response->is_success ) {
        $self->logger->errorf( '[%s] could not be retrieved: %s', $key, $response->status_line );
        return;
    }

    my $note = WebService::Simplenote::Note->thaw( $response->content );

    return $note;
}

# Delete specified note from Simplenote server
sub delete_note {
    my ( $self, $note ) = @_;
    if ( !$self->allow_server_updates ) {
        return;
    }

    # XXX worth checking if note is flagged as deleted?
    $self->logger->infof( '[%s] Deleting from trash', $note->key );

    my $req_uri = sprintf '%s/data?key=%s&auth=%s&email=%s', $self->_uri, $note->key, $self->token, $self->email;

    my $response = $self->_ua->delete( $req_uri );

    if ( !$response->is_success ) {
        $self->logger->errorf( '[%s] Failed to delete note from trash: %s', $note->key, $response->status_line );
        return;
    }

    delete $self->notes->{ $note->key };
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 LIMITATIONS

* If the simplenotesync.db file is lost, SimplenoteSync.pl is currently unable
  to realize that a text file and a note represent the same object --- instead
  you should move your local text files, do a fresh sync to download all notes
  locally, and manually replace any missing notes.

* Simplenote supports multiple notes with the same title, but two files cannot
  share the same filename. If you have two notes with the same title, only one
  will be downloaded. I suggest changing the title of the other note.

=head1 TROUBLESHOOTING

Optionally, you can enable or disable writing changes to either the local
directory or to the Simplenote web server. For example, if you want to attempt
to copy files to your computer without risking your remote data, you can
disable "$allow_server_updates". Or, you can disable "$allow_local_updates" to
protect your local data.

=head1 KNOWN ISSUES

* No merging when both local and remote file are changed between syncs - this
  might be enabled in the future

=head1 SEE ALSO

Designed for use with Simplenote:

<http://www.simplenoteapp.com/>

Based on SimplenoteSync:

<http://fletcherpenney.net/other_projects/simplenotesync/>
