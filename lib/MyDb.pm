package Mydb;
use strict;
use DBI;
use SeqMisc;
use File::Temp qw / tmpnam /;
use Fcntl ':flock';    # import LOCK_* constants
use Bio::DB::Universal;
use Log::Log4perl;
use Log::Log4perl::Level;
use Bio::Root::Exception;
use AppConfig qw/:argcount :expand/;
use Getopt::Long;
require Exporter;
use Error qw(:try);
use vars qw($VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(Out Error AddOpen RemoveFile callstack);    # Symbols to be exported by default
our $AUTOLOAD;

$VERSION = '20091101';
Log::Log4perl->easy_init($WARN);
our $log = Log::Log4perl->get_logger('stack'),
### Holy crap global variables!
my $config;
my $dbh;
###

sub new {
    my ($class, %arg) = @_;
    my $me = bless {}, $class;
    foreach my $key (keys %arg) {
	$me->{$key} = $arg{$key} if (defined($arg{$key}));
    }

    $me->{appconfig} = AppConfig->new({
	CASE => 1,
	CREATE => 1,
	PEDANTIC => 0,
#	ERROR => eval(),
	GLOBAL => {
	    EXPAND => EXPAND_ALL,
	    EXPAND_ENV => 1,
	    EXPAND_UID => 1,
	    DEFAULT => "<unset>",
	    ARGCOUNT => 1,
	},});
    $me->{config_file} = 'sze.conf' if (!defined($me->{config_file}));
    $me->{database_args} = {AutoCommit => 1} if (!defined($me->{database_args}));
    $me->{database_host} = ['localhost',] if (!defined($me->{database_host}));
    $me->{database_name} = 'test' if (!defined($me->{database_name}));
    $me->{database_pass} = 'guest' if (!defined($me->{database_pass}));
    $me->{database_retries} = 0 if (!defined($me->{database_retries}));
    $me->{database_timeout} = 5 if (!defined($me->{database_timeout}));
    $me->{database_type} = 'mysql' if (!defined($me->{database_type}));
    $me->{database_user} = 'guest' if (!defined($me->{database_user}));
    $me->{log} = 'sze.log' if (!defined($me->{log}));
    $me->{log_error} = 'sze.errors' if (!defined($me->{log_error}));
    my ($open, %data, $config_option);
    if (-r $me->{config_file}) {
	$open = $me->{appconfig}->file($me->{config_file});
	%data = $me->{appconfig}->varlist("^.*");
	for $config_option (keys %data) {
	    $me->{$config_option} = $data{$config_option};
	    undef $data{$config_option};
	}
    }
#    else {
#	my $cwd = `pwd`;
#	print STDERR "Can't find the config file $me->{config_file} in $cwd\n";
#	die;
#   }

    my (%conf, %conf_specification, %conf_specification_temp);
    foreach my $default (keys %{$me}) {
	$conf_specification{"$default:s"} = \$conf{$default};
    }
    %conf_specification_temp = (
	'makeblast' => \$conf{makeblast},
	);
    foreach my $name (keys %conf_specification_temp) {
	$conf_specification{$name} = $conf_specification_temp{$name};
    }
    undef(%conf_specification_temp);
    GetOptions(%conf_specification);

    foreach my $opt (keys %conf) {
	if (defined($conf{$opt})) {
	    $me->{$opt} = $conf{$opt};
	}
    }
    undef(%conf);
    $me->{errors} = undef;
    return ($me);
}

sub callstack {
  my ($path, $line, $subr);
  my $max_depth = 30;
  my $i = 1;
  if ($log->is_warn()) {
    $log->warn("--- Begin stack trace ---");
    while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
      $log->warn("$call_details[1] line $call_details[2] in function $call_details[3]");
    }
    $log->warn("--- End stack trace ---");
  }
}

sub Disconnect {
    $dbh->disconnect() if (defined($dbh));
}

sub MySelect {
    my $me = shift;
    my %args = ();
    my $input;
    my $input_type = ref($_[0]);
    my ($statement, $vars, $type, $descriptor);
    if ($input_type eq 'HASH') {
        $input = $_[0];
	$statement = $input->{statement};
	$vars = $input->{vars};
	$type = $input->{type};
	$descriptor = $input->{descriptor};
    } elsif (!defined($_[1])) {
	$statement = $_[0];
    } else {
	%args = @_;
	$statement = $args{statement};
	$vars = $args{vars};
	$type = $args{type};
	$descriptor = $args{descriptor};
        $input = \%args;
    }

    my $return = undef;
    if (!defined($statement)) {
	die("No statement in MySelect");
    }

    my $dbh = $me->MyConnect($statement);
    my $selecttype;
    my $sth = $dbh->prepare($statement);
    my $rv;
    if (defined($vars)) {
	$rv = $sth->execute(@{$vars});
    } else {
	$rv = $sth->execute();
    }
    
    if (!defined($rv)) {
	callstack();
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
	if (defined($input->{caller})) {
	    $me->{errors}->{caller} = $input->{caller};
	}
	return(undef);
    }

    ## If $type AND $descriptor are defined, do selectall_hashref
    if (defined($type) and defined($descriptor)) {
	$return = $sth->fetchall_hashref($descriptor);
	$selecttype = 'selectall_hashref';
    } elsif (defined($type) and $type eq 'row') {
	## If $type is defined, AND if you ask for a row, do a selectrow_arrayref
	$return = $sth->fetchrow_arrayref();
	$selecttype = 'selectrow_arrayref';
    }

    ## A flat select is one in which the returned elements are returned as a single flat arrayref
    ## If you ask for multiple columns, then it will return a 2d array ref with the first d being the cols
    elsif (defined($type) and $type eq 'single') {
	my $tmp = $sth->fetchrow_arrayref();
	$return = $tmp->[0];
    } elsif (defined($type) and $type eq 'flat') {
	my $selecttype = 'flat';
	my @ret = ();
	my $data = $sth->fetchall_arrayref();
	if (!defined($data->[0])) {
	    return (undef);
	}
	if (scalar(@{$data->[0]}) == 1) {
	    foreach my $c (0 .. $#$data) {
		push(@ret, $data->[$c]->[0]);
	    }
	} else {
	    foreach my $c (0 .. $#$data) {
		my @elems = @{$data->[$c]};
		foreach my $d (0 .. $#elems) {
		    $ret[$d][$c] = $data->[$c]->[$d];
		}
	    }
	}
	$return = \@ret;
	## Endif flat
    } elsif (defined($type) and $type eq 'list_of_hashes') { 
	$return = $sth->fetchall_arrayref({});
	$selecttype = 'selectall_arrayref({})';     
    } elsif (defined($type)) {    ## Usually defined as 'hash'
	## If only $type is defined, do a selectrow_hashref
	$return = $sth->fetchrow_hashref();
	$selecttype = 'selectrow_hashref';
    } else {
    ## The default is to do a selectall_arrayref
	$return = $sth->fetchall_arrayref();
	$selecttype = 'selectall_arrayref';
    }

    if (defined($DBI::errstr)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
	if (defined($vars->{caller})) {
	    $me->{errors}->{caller} = $vars->{caller};
	}
	Write_SQL($statement);
    }
    return ($return);
}

sub MyExecute {
    my $me = shift;
    my %args = ();
    my $input;
    my $input_type = ref($_[0]);
    my ($statement, $vars, $caller);
    if ($input_type eq 'HASH') {
        $input = $_[0];
	$caller = $input->{caller};
	$vars = $input->{vars};
	$statement = $input->{statement};
    } elsif (!defined($_[1])) {
	$statement = $_[0];
    } else {
	%args = @_;
	$statement = $args{statement};
	$vars = $args{vars};
	$caller = $args{caller};
        $input = \%args;
    }

    my $dbh = $me->MyConnect($statement);
    my $sth = $dbh->prepare($statement);
    my $rv;
    my @vars;
    if (defined($input->{vars})) {
	@vars = @{$input->{vars}};
    }
    if (scalar(@vars) > 0) {
	$rv = $sth->execute(@{$input->{vars}}) or callstack();
    } else {
	$rv = $sth->execute() or callstack();
    }
    
    my $rows = 0;
    if (!defined($rv)) {
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	print STDERR "$hour:$min:$sec $mon-$mday Execute failed for: $statement
from: $input->{caller}
with: error $DBI::errstr\n";
	print STDERR "Host: $config->{database_host} Db: $config->{database_name}\n" if (defined($config->{debug}) and $config->{debug} > 0);
	$me->{errors}->{statement} = $statement;
	$me->{errors}->{errstr} = $DBI::errstr;
	if (defined($input->{caller})) {
	    $me->{errors}->{caller} = $input->{caller};
	}
	return(undef);
    } else {
	$rows = $dbh->rows();
    }
    return($rows);
}

sub MyGet {
    my $me = shift;
    my $vars = shift;
    my $final_statement = qq(SELECT);
    my $tables = $vars->{table};
    delete($vars->{table});
    my $order = $vars->{order};
    delete($vars->{order});
    my @select_columns = ();
    my $select_count = 0;
    foreach my $criterion (keys %{$vars}) {
	if (!defined($vars->{$criterion})) {
	    $select_count++;
	    push(@select_columns, $criterion);
	    $final_statement .= "$criterion, "
	    }
    }
    if ($select_count == 0) {
	$final_statement .= "* ";
    }
    $final_statement =~ s/, $/ /g;
    $final_statement .= "FROM $tables WHERE ";
    my $criteria_count = 0;
    foreach my $criterion (keys %{$vars}) {
	if (defined($vars->{$criterion})) {
	    $criteria_count++;
	    if ($vars->{$criterion} =~ /\s+/) {
		$final_statement .= "$criterion $vars->{$criterion} AND ";
	    }
	    else {
		$final_statement .= "$criterion = '$vars->{$criterion}' AND ";
	    }
	}
    }
    if ($criteria_count == 0) {
	$final_statement =~ s/ WHERE $//g;
    }
    $final_statement =~ s/ AND $//g;
    if (defined($order)) {
	$final_statement .= " ORDER BY $order";
    }

    my $dbh = $me->MyConnect($final_statement);
    my $stuff = $me->MySelect(statement => $final_statement,);

    print "Column order: @select_columns\n";
    my $c = 1;
    foreach my $datum (@{$stuff}) {
	print "$c\n";
	$c++;
	foreach my $c (0 .. $#select_columns) {
	    print "  ${select_columns[$c]}: $datum->[$c]\n";
	}
    }
    return($final_statement);
}

sub MyConnect {
    my $me = shift;
    my $statement = shift;
    my $alt_dbd = shift;
    my $alt_user = shift;
    my $alt_pass = shift;
    my @hosts = @{$config->{database_host}};
    my $host = sub {
	my $value = shift;
	my $range = scalar(@hosts);
	my $index = $value % $range;
	return($hosts[$index]);
    };
    my $hostname = $host->($config->{database_retries});
    my $dbd;
    if (defined($alt_dbd)) {
	$dbd = $alt_dbd;
    } else {
	$dbd = qq"dbi:$config->{database_type}:database=$config->{database_name};host=$hostname";
    }
    my $dbh;
    use Sys::SigAction qw( set_sig_handler );
    eval {
	my $h = set_sig_handler('ALRM', sub {return("timeout");});
	#implement 2 second time out
	alarm($config->{database_timeout});  ## The timeout in seconds as defined by PRFConfig
	my ($user, $pass);
	if (defined($alt_user)) {
	    $user = $alt_user;
	    $pass = $alt_pass;
	} else {
	    $user = $config->{database_user};
	    $pass = $config->{database_pass};
	}
	$dbh = DBI->connect_cached($dbd, $user, $pass, $config->{database_args},) or callstack();
	alarm(0);
    }; #original signal handler restored here when $h goes out of scope
    alarm(0);
    if (!defined($dbh) or
	(defined($DBI::errstr) and
	 $DBI::errstr =~ m/(?:lost connection|Server shutdown|Can't connect|Unknown MySQL server host|mysql server has gone away)/ix)) {  ##'
	my $success = 0;
	while ($config->{database_retries} < $me->{num_retries} and $success == 0) {
	    $config->{database_retries}++;
	    $hostname = $host->($config->{database_retries});
	    $dbd = qq"dbi:$config->{database_type}:database=$config->{database_name};host=$hostname";
	    print STDERR "Doing a retry, attempting to connect to $dbd\n";
	    eval {
		my $h = set_sig_handler( 'ALRM' ,sub { return("timeout") ; } );
		alarm($config->{database_timeout});  ## The timeout in seconds as defined by PRFConfig
		$dbh = DBI->connect_cached($dbd, $config->{database_user}, $config->{database_pass}, $config->{database_args},) or callstack();
		alarm(0);
	    }; #original signal handler restored here when $h goes out of scope
	    alarm(0);
	    if (defined($dbh) and
		(!defined($dbh->errstr) or $dbh->errstr eq '')) {
		$success++;
	    }
	} ## End of while
    }

    if (!defined($dbh)) {
	$me->{errors}->{statement} = $statement, Write_SQL($statement) if (defined($statement));
	$me->{errors}->{errstr} = $DBI::errstr;
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	my $error = qq"$hour:$min:$sec $mon-$mday Could not open cached connection: dbi:$config->{database_type}:database=$config->{database_name};host=$config->{database_host}, $DBI::err. $DBI::errstr";
	die($error);
    }
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{InactiveDestroy} = 1;
    return ($dbh);
}

sub MakeTempfile {
    my %args = @_;
    $File::Temp::KEEP_ALL = 1;
    my $fh = new File::Temp(DIR => defined($args{directory}) ? $args{directory} : $config->{workdir},
			    TEMPLATE => defined($args{template}) ? $args{template} : 'XXXXX',
			    UNLINK => defined($args{unlink}) ? $args{unlink} : 0,
			    SUFFIX => defined($args{SUFFIX}) ? $args{SUFFIX} : '.fasta',);

    my $filename = $fh->filename();
    AddOpen($filename);
    return ($fh);
}

sub AddOpen {
    my $file = shift;
    my @open_files = @{$config->{open_files}};

    if (ref($file) eq 'ARRAY') {
	foreach my $f (@{$file}) {
	    push(@open_files, $f);
	}
    }
    else {
	push(@open_files, $file);
    }
    $config->{open_files} = \@open_files;
}

sub RemoveFile {
    my $file = shift;
    my @open_files = @{$config->{open_files}};
    my @new_open_files = ();
    my $num_deleted = 0;
    my @comp = ();
    
    if ($file eq 'all') {
	foreach my $f (@{open_files}) {
	    unlink($f);
	    print STDERR "Deleting: $f\n" if (defined($config->{debug}) and $config->{debug} > 0);
	    $num_deleted++;
	}
	$config->{open_files} = \@new_open_files;
	return($num_deleted);
    }

    elsif (ref($file) eq 'ARRAY') {
	@comp = @{$file};
    }
    else {
	push(@comp, $file);
    }

    foreach my $f (@open_files) {
	foreach my $c (@comp) {
	    if ($c eq $f) {
		$num_deleted++;
		unlink($f);
	    }
	}
	push(@new_open_files, $f);
    }
    $config->{open_files} = \@new_open_files;
    return($num_deleted);
}

sub Error_Db {
    my $me = shift;
    my $message = shift;
    my $species = shift;
    my $accession = shift;
    $species = '' if (!defined($species));
    $accession = '' if (!defined($accession));
    print "Error: '$message'\n";
    my $statement = qq(INSERT into errors (message, accession) VALUES(?,?));
    ## Don't call Execute here or you may run into circular crazyness
    $me->MyConnect($statement,);
    my $sth = $dbh->prepare($statement);
    $sth->execute($message, $accession);
}

sub Drop_Table {
    my $me = shift;
    my $table = shift;
    my $statement = "DROP table $table";
    my ($cp,$cf,$cl) = caller();
    $me->MyExecute(statement => $statement, caller =>"$cp, $cf, $cl");
}

sub Write_SQL {
    my $statement = shift;
    my $genome_id = shift;
    open(SQL, ">>failed_sql_statements.txt");
    ## OPEN SQL in Write_SQL
    my $string = "$statement" . ";\n";
    print SQL "$string";
    
    if (defined($genome_id)) {
	my $second_statement = "UPDATE queue set done='0', checked_out='0' where genome_id = '$genome_id';\n";
	print SQL "$second_statement";
    }
    close(SQL);
    ## CLOSE SQL in Write_SQL
}

sub Check_Defined {
    my %args = @_;
    my $return = '';
    foreach my $k (keys %args) {
	if (!defined($args{$k})) {
	    $return .= "$k,";
	}
    }
    return ($return);
}

sub Tablep {
    my $me = shift;
    my $table = shift;
    my $statement = qq"SHOW TABLES LIKE '$table'";
    my $info = $me->MySelect($statement);
    my $answer = scalar(@{$info});
    return (scalar(@{$info}));
}


#################################################
### Functions used to create tables
#################################################

sub Create_Pollen {
    my $me = shift;
    my $statement = qq/CREATE table pollen (
id $config->{sql_id},
accession $config->{sql_accession},
type $config->{sql_accession},
genename $config->{sql_genename},
lastupdate $config->{sql_timestamp},
INDEX(accession),
INDEX(genename),
PRIMARY KEY (id))/;
    my ($cp, $cf, $cl) = caller();
    $me->MyExecute(statement =>$statement, caller => "$cp, $cf, $cl",);
}

1;
