#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use PRFConfig;
use PRFdb qw"AddOpen RemoveFile";
use RNAMotif;
use RNAFolders;
use Bootlace;
use Overlap;
use SeqMisc;
use PRFBlast;
use Agree;
use PRFGraph;
$SIG{INT} = 'CLEANUP';
$SIG{BUS} = 'CLEANUP';
$SIG{SEGV} = 'CLEANUP';
$SIG{PIPE} = 'CLEANUP';
$SIG{ABRT} = 'CLEANUP';
$SIG{QUIT} = 'CLEANUP';

$config = new PRFConfig(config_file => "$ENV{PRFDB_HOME}/prfdb.conf");
$db = new PRFdb(config => $config);
setpriority(0,0,$config->{niceness});

if (defined($config->{shell})) {
    my $host = $config->{database_host}->[0];
    my @command = ('mysql', '-h', "$host", '-u', "$config->{database_user}", "--password=$config->{database_pass}", "$config->{database_name}");
    system(@command);
    exit($?);
}
