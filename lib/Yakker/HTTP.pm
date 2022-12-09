package Yakker::HTTP;
use Moo;

use v5.20.0;
use experimental qw(postderef signatures);
use utf8;

use Yakker;
use DBI;
use DBD::SQLite;
use Time::HiRes ();

use IO::Async::Loop;

sub new_with_timing_db {
  my ($class, $dbname) = @_;
  $dbname //= 'clim8-timing.sqlite';

  my $new = ! -e $dbname;

  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef);

  if ($new) {
    $dbh->do(q{
      CREATE TABLE requests (
        request_id  INTEGER PRIMARY KEY,
        http_method TEXT NOT NULL,
        url         TEXT NOT NULL,
        content     TEXT NOT NULL,
        http_status TEXT NOT NULL, /* 3 bytes */
        start_time  REAL NOT NULL,
        end_time    REAL NOT NULL
      );
    });
  }

  $class->new({ _timing_dbh => $dbh });
}

has _timing_dbh => (is => 'ro');

sub _log_request {
  return unless my $dbh = $_[0]->_timing_dbh;

  my ($self, $arg) = @_;

  my @vals = $arg->@{
    qw( http_method url content http_status start_time end_time )
  };

  $dbh->do(
    q{
      INSERT INTO requests
        (http_method, url, content, http_status, start_time, end_time)
      VALUES (?, ?, ?, ?, ?, ?)
    },
    undef,
    @vals,
  );

  return;
}

has _agent_cache => (
  is => 'rw',
);

sub _agent ($self) {
  my $cache = $self->_agent_cache;

  if ($cache && (time - $cache->[0] < 180)) {
    # This is kinda crap, because we could fetch the agent and not use it, but
    # whatever. -- rjbs, 2020-04-14
    $cache->[0] = time;
    return $cache->[1];
  }

  # Is this a bad idea?  What if there's a request in flight?  Well, shouldn't
  # take >3m.  Again, crap but probably actually just fine. -- rjbs, 2020-04-14
  Yakker->loop->remove($cache->[1]) if $cache;

  require Net::Async::HTTP;
  $cache = [
    time,
    Net::Async::HTTP->new,
  ];

  Yakker->loop->add($cache->[1]);
  $self->_agent_cache($cache);
  return $cache->[1];
}

sub do_request {
  my ($self, %rest) = @_;

  my $http  = $self->_agent;
  my $label = delete $rest{m8_label};

  my $start = Time::HiRes::time;

  my $req_f = $http->do_request(%rest)->then_with_f(sub ($f, $res) {
    my $end = Time::HiRes::time;

    $self->_log_request({
      http_method => $res->request->method,
      url         => $res->request->uri,
      content     => $res->request->content,
      http_status => $res->code,
      start_time  => $start,
      end_time    => $end,
    });

    return $f;
  });

  return Yakker->wait_with_spinner($req_f, { label => $label });
}

no Moo;
1;
