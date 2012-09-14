package WebService::Simplenote;

# ABSTRACT: Note-taking through simplenoteapp.com

our $VERSION = '0.3.0';

use v5.10.1;
use open qw(:std :utf8);
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use JSON;
use LWP::UserAgent;
use HTTP::Cookies;
use Log::Any qw//;
use MIME::Base64 qw//;
use WebService::Simplenote::Note;
use Method::Signatures;

with qw/WebService::Simplenote::Role::Logger/;

has email    => ( is => 'ro', isa => Str, required => 1);
has password => ( is => 'ro', isa => Str, required => 1);

has _token => ( is => 'rw', isa => Str, predicate => 'has_logged_in');

has no_server_updates => ( is => 'ro', isa => Bool, default  => sub { 0 }, );
has page_size => (is => 'ro', isa => Int, default => sub {20});

has logger => (
    is      => 'ro',
    lazy    => 1,
    isa     => Object,
    default => sub { return Log::Any->get_logger },
);

has _url => ( is => 'ro', isa => Str, default => sub {'https://simple-note.appspot.com/api2'});
has _ua => ( is => 'lazy', isa => Object);

method _build__ua {
    my $headers = HTTP::Headers->new(Content_Type => 'application/json',);

    # XXX is it worth saving cookie?? How is password more valuable than auth token?
    # logging in is only a fraction of a second!
    my $ua = LWP::UserAgent->new(
        agent           => "WebService::Simplenote/$VERSION",
        default_headers => $headers,
        env_proxy       => 1,
        cookie_jar      => HTTP::Cookies->new,
    );

    return $ua;
}

# Connect to server and get a authentication token
method _login {
    my $content = MIME::Base64::encode_base64(sprintf 'email=%s&password=%s',
        $self->email, $self->password);

    $self->logger->debug('Network: getting auth token');

    # the login url uses api instead of api2 and must always be https
    my $response =
      $self->_ua->post('https://simple-note.appspot.com/api/login',
        Content => $content);

    if (!$response->is_success) {
        die 'Error logging into Simplenote server: '
          . $response->status_line . "\n";
    }

    $self->_token($response->content);
    return 1;
}

sub _build_req_url {
    my ($self, $path, $options) = @_;

    my $req_url = sprintf '%s/%s', $self->_url, $path;

    if (!$self->has_logged_in) {
        $self->_login;
    }

    return $req_url if !defined $options;

    $req_url .= '?';
    while (my ($option, $value) = each %$options) {
        $req_url .= "&$option=$value";
    }

    return $req_url;
}

method _get_remote_index_page($mark?) {
    my $notes;

    my $req_url = $self->_build_req_url('index', {length => $self->page_size});

    if (defined $mark) {
        $self->logger->debug('Network: retrieving next page');
        $req_url .= '&mark=' . $mark;
    }

    $self->logger->debug('Network: retrieving ' . $req_url);

    my $response = $self->_ua->get($req_url);
    if (!$response->is_success) {
        $self->logger->error('Network: ' . $response->status_line);
        return;
    }

    my $index = decode_json($response->content);

    if ($index->{count} > 0) {
        $self->logger->debugf('Network: Index returned [%s] notes',
            $index->{count});

        # iterate through notes in index and load into hash
        foreach my $i (@{$index->{data}}) {
            $notes->{$i->{key}} = WebService::Simplenote::Note->new($i);
        }

    } elsif ($index->{count} == 0 && !exists $index->{mark}) {
        $self->logger->debugf('Network: No more pages to retrieve');
    } elsif ($index->{count} == 0) {
        $self->logger->debugf('Network: No notes found');
    }

    if (exists $index->{mark}) {
        return ($notes, $index->{mark});
    }

    return $notes;
}

# Get list of notes from simplenote server
# TODO since, length options
method get_remote_index {
    $self->logger->debug('Network: getting note index');

    my ($notes, $mark) = $self->_get_remote_index_page;

    while (defined $mark) {
        my $next_page;
        ($next_page, $mark) = $self->_get_remote_index_page($mark);
        @$notes{keys %$next_page} = values %$next_page;
    }

    $self->logger->infof('Network: found %i remote notes',
        scalar keys %$notes);
    return $notes;
}

# Given a local file, upload it as a note at simplenote web server
method put_note($note) {

    if ($self->no_server_updates) {
        $self->logger->warn('Sending notes to the server is disabled');
        return;
    }

    my $req_url = $self->_build_req_url('data');

    if (defined $note->key) {
        $self->logger->infof('[%s] Updating existing note', $note->key);
        $req_url .= '/' . $note->key,;
    } else {
        $self->logger->debug('Uploading new note');
    }

    $self->logger->debug("Network: POST to [$req_url]");

    my $content = $note->serialise;

    my $response = $self->_ua->post($req_url, Content => $content);

    if (!$response->is_success) {
        $self->logger->errorf('Failed uploading note: %s',
            $response->status_line);
        return;
    }

    my $note_tmp = WebService::Simplenote::Note->new($response->content);

    # a brand new note will have a key generated remotely
    if (!defined $note->key) {
        return $note_tmp->key;
    }

    #TODO better return values
    return;
}

# Save local copy of note from Simplenote server
method get_note($key) {
    
    $self->logger->infof('Retrieving note [%s]', $key);

    # TODO are there any other encoding options?
    my $req_url = $self->_build_req_url("data/$key");
    $self->logger->debug("Network: GETting [$req_url]");
    my $response = $self->_ua->get($req_url);

    if (!$response->is_success) {
        $self->logger->errorf('[%s] could not be retrieved: %s',
            $key, $response->status_line);
        return;
    }
say "MAKING NEW NOTE";
    my $note = WebService::Simplenote::Note->new($response->content);

    return $note;
}

# Delete specified note from Simplenote server
method delete_note($note) {

    if ($self->no_server_updates) {
        $self->logger->warnf(
            '[%s] Attempted to delete note when "no_server_updates" is set',
            $note->key);
        return;
    }

    if (!$note->deleted) {
        $self->logger->warnf(
            '[%s] Attempted to delete note which was not marked as trash',
            $note->key);
        return;
    }

    $self->logger->infof('[%s] Deleting from trash', $note->key);
    my $req_url = $self->_build_req_url('data/' . $note->key);
    $self->logger->debug("Network: DELETE on [$req_url]");
    my $response = $self->_ua->delete($req_url);

    if (!$response->is_success) {
        $self->logger->errorf('[%s] Failed to delete note from trash: %s',
            $note->key, $response->status_line);
        $self->logger->debug("url: [$req_url]");
        return;
    }

    return 1;
}

1;

=head1 SYNOPSIS

  use WebService::Simplenote;
  use WebService::Simplenote::Note;

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
  }

  my $new_note = WebService::Simplenote::Note->new(
      content => "Some stuff",
  );

  $sn->put_note($new_note);

=head1 DESCRIPTION

This module proves v2.1.5 API access to the cloud-based note software at
L<Simplenote|https://simplenoteapp.com>.

=head1 ERRORS

Will C<die> if unable to connect/login. Returns C<undef> for other errors.

=head1 METHODS

=over

=item WebService::Simplenote->new($args)

Requires the C<email> and C<password> for your simplenote account. You can also
provide a L<Log::Any> compatible C<logger>.

=item get_remote_index

Returns a hashref of L<WebService::Simplenote::Note|notes>. The notes are keyed by id.

=item get_note($note_id)

Retrieves a note from the remote server and returns it as a L<WebService::Simplenote::Note>.
C<$note_id> is an alphanumeric key generated on the server side.

=item put_note($note)

Puts a L<WebService::Simplenote::Note> to the remote server

=item delete_note($note_id)

Delete the specified note from the server. The note should be marked as C<deleted>
beforehand.

=back

=head1 TESTING

Setting the environment variables C<SIMPLENOTE_USER> and C<SIMPLENOTE_PASS> will enable remote tests.
If you want to run the remote tests B<MAKE SURE YOU MAKE A BACKUP OF YOUR NOTES FIRST!!>

=head1 SEE ALSO

Designed for use with Simplenote:

<http://www.simplenoteapp.com/>

Based on SimplenoteSync:

<http://fletcherpenney.net/other_projects/simplenotesync/>

