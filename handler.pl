package HTML::Mason::Commands;
use vars qw($session $dbh $db $ah $req $config);
use Apache2::Request;
use Apache2::Upload;
use Data::Dumper;
use Apache::DBI;
use File::Temp qw/ tmpnam /;
use lib qq"$ENV{SZE_HOME}/lib";
use Mydb qw/ AddOpen RemoveFile /;
use MyGraph;
use SeqMisc;
use HTMLMisc;
BEGIN {
    if (!defined($ENV{SZE_HOME})) {
	die("SZE_HOME is not set.  Either set it in your apache env vars or shell profile.");
    }
}
$config = new Mydb(config_file => "$ENV{SZE_HOME}/config");
my $database_hosts = $config->{database_host};
Apache::DBI->connect_on_init("DBI:$config->{database_type}:database=$config->{database_name};host=$database_host->[0]", $config->{database_user}, $config->{database_pass}, $config->{database_args}) or print "Can't connect to database: $DBI::errstr $!";
Apache::DBI->setPingTimeOut("DBI:$config->{database_type}:$config->{database_name}:$database_host->[0]", 0);
$db = new PRFdb(config=>$config);

package Mydb::Handler;
use strict;
use HTML::Mason::ApacheHandler;
BEGIN {
    use Exporter ();
    @Mydb::Handler::ISA = qw(Exporter);
    @Mydb::Handler::EXPORT = qw();
    @Mydb::Handler::EXPORT_OK = qw($req $dbh $dbs);
}
my $req;
my $ah = new HTML::Mason::ApacheHandler(
					comp_root => $ENV{SZE_HOME},
					data_dir  => $ENV{SZE_HOME},
					args_method   => "mod_perl",
					request_class => 'MasonX::Request::WithApacheSession',
					session_class => 'Apache::Session::File',
					session_cookie_domain => 'umd.edu',
					session_directory => "$ENV{SZE_HOME}/sessions/data",
					session_lock_directory => "$ENV{SZE_HOME}/sessions/locks",
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
