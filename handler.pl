package HTML::Mason::Commands;
use vars qw($session $dbh $db $ah $req $config);
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
$config = new MyDb(config_file => "$ENV{MYDB_HOME}/mydb.conf");
my $database_hosts = $config->{database_host};
Apache::DBI->connect_on_init("DBI:$config->{database_type}:database=$config->{database_name};host=$database_host->[0]", $config->{database_user}, $config->{database_pass}, $config->{database_args}) or print "Can't connect to database: $DBI::errstr $!";
Apache::DBI->setPingTimeOut("DBI:$config->{database_type}:$config->{database_name}:$database_host->[0]", 0);
$db = new MyDb(config=>$config);

package MyDb::Handler;
use strict;
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @MyDb::Handler::ISA = qw(Exporter);
    @MyDb::Handler::EXPORT = qw();
    @MyDb::Handler::EXPORT_OK = qw($req $dbh $dbs);
}

my $req;
my $ah = new HTML::Mason::ApacheHandler(
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
    my $return = eval { $ah->handle_request($r) };
    if (my $err = $@) {
	$r->pnotes(error => $err);
	$r->filename($r->document_root . '/error/500.html');
	return $ah->handle_request($r);
    }
    return $return;
}
 
1;
