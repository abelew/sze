package HTML::Mason::Commands;
use vars qw($session $mydbh $mydb $myah $myreq);
use Apache2::Request;
use Apache2::Upload;
use Data::Dumper;
use Apache::DBI;
use File::Temp qw/ tmpnam /;
use lib qq"$ENV{MYDB_HOME}/lib";
use MyDb qw/ AddOpen RemoveFile /;
use MyGraph;
use SeqMisc;
use HTMLMisc;
BEGIN {
    if (!defined($ENV{MYDB_HOME})) {
	die("MYDB_HOME is not set.  Either set it in your apache env vars or shell profile.");
    }
}
$mydb = new MyDb(config_file => "$ENV{MYDB_HOME}/mydb.conf");
my $database_hosts = $mydb->{database_host};
my $database_host = $database_hosts->[0];
print STDERR "TESTME: $database_host\n";
Apache::DBI->connect_on_init("DBI:$mydb->{database_type}:database=$mydb->{database_name};host=$database_host", $mydb->{database_user}, $mydb->{database_pass}, $mydb->{database_args}) or print "Can't connect to database: $DBI::errstr $!";
Apache::DBI->setPingTimeOut("DBI:$mydb->{database_type}:$mydb->{database_name}:$database_host", 0);

package MyDb::Handler;
use strict;
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @MyDb::Handler::ISA = qw(Exporter);
    @MyDb::Handler::EXPORT = qw();
    @MyDb::Handler::EXPORT_OK = qw($myreq $mydbh $mydbs);
}

my $myreq;
my $myah = new HTML::Mason::ApacheHandler(
					comp_root => $ENV{MYDB_HOME},
					data_dir => $ENV{MYDB_HOME},
					args_method => "mod_perl",
					request_class => 'MasonX::Request::WithApacheSession',
					session_class => 'Apache::Session::File',
					session_cookie_domain => 'umd.edu',
					session_directory => "$ENV{MYDB_HOME}/sessions/data",
					session_lock_directory => "$ENV{MYDB_HOME}/sessions/locks",
					session_use_cookie => 1,
					);

sub handler {
    my ($r) =  @_;
    my $return = eval { $myah->handle_request($r) };
    if (my $err = $@) {
	$r->pnotes(error => $err);
	$r->filename($r->document_root . '/error/500.html');
	return $myah->handle_request($r);
    }
    return $return;
}
 
1;
