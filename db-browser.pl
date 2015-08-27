use common::sense;

use Valence;
use DBI;
use Cwd;


my $dbi_connect_string = shift || die "need DBI connect string (ie 'dbi:SQLite:dbname=/tmp/junk.db')";
my $username = shift || '';
my $password = shift || '';

my $dbh = DBI->connect($dbi_connect_string, $username, $password,
                       { RaiseError => 0, AutoCommit => 1 }
                       ) || die "couldn't connect to DB";


my $v = Valence->new;
 
$v->require('app')->on(ready => sub {
  my $ipc = $v->require('ipc');

  my $main_window = $v->require('browser-window')->new({
                       width => 1000,
                       height => 600,
                       title => "DB Browser: $dbi_connect_string",
                       icon => Cwd::abs_path() . "/app/icon.png",
                    });

  my $web_contents = $main_window->attr('webContents');
 
  $main_window->loadUrl('file://' . Cwd::abs_path() . "/app/client.html");

  $main_window->openDevTools() if $ENV{DEVTOOLS};

  $main_window->on(close => sub { exit });

  $ipc->on(new_query => sub {
    my ($event, $cmd) = @_;

    my $sth = $dbh->prepare($cmd->{sql});

    if (!$sth) {
      $web_contents->send(query_results => { key => $cmd->{key}, err => "Couldn't prepare: " . $dbh->errstr });
      return;
    }

    my $result = $sth->execute;

    if (!$result) {
      $web_contents->send(query_results => { key => $cmd->{key}, err => "Couldn't execute: " . $dbh->errstr });
      return;
    }

    $web_contents->send(query_results => { key => $cmd->{key}, results => { column_names => $sth->{NAME_lc}, rows => $sth->fetchall_arrayref, } });
  });
});
 

$v->run;
