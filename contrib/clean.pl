#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{MYDB_HOME}/usr/lib/perl5";
use lib "$ENV{MYDB_HOME}/lib";
use MyDb qw"AddOpen RemoveFile";
use MyGraph;

## Set up the (hopefully) limited list of globals
my $db = new MyDb(config_file => "$ENV{MYDB_HOME}/mydb.conf");

my $column = $ARGV[0];
print "cleaning: $column\n";
if (defined($column)) {
    my $start = qq"SELECT id, $column FROM pollen";
    my $entries = $db->MySelect(statement => $start);
    foreach my $entry (@{$entries}) {
	my $id = $entry->[0];
	my $va = $entry->[1];
	$va =~ s/\"//g;
	my $update = qq"UPDATE pollen SET $column = '$va' WHERE id = '$id'";
	$db->MyExecute($update);
    }
} else {
    print "
#+---------------------+---------------------+------+-----+-------------------+----------------+
#| Field               | Type                | Null | Key | Default           | Extra          |
#+---------------------+---------------------+------+-----+-------------------+----------------+
#| id                  | bigint(20) unsigned | NO   | PRI | NULL              | auto_increment | 
#| accession           | varchar(40)         | NO   | MUL | NULL              |                | 
#| tc_code             | varchar(10)         | YES  |     | NULL              |                | 
#| tc_description      | varchar(80)         | YES  |     | NULL              |                | 
#| family              | varchar(20)         | YES  |     | NULL              |                | 
#| family_num          | int(4)              | YES  |     | NULL              |                | 
#| protein_description | varchar(80)         | YES  |     | NULL              |                | 
#| aramemnon_con       | int(3)              | YES  |     | NULL              |                | 
#| conpred_con         | int(3)              | YES  |     | NULL              |                | 
#| cluster             | int(3)              | YES  |     | NULL              |                | 
#| pollen_pref         | varchar(10)         | YES  |     | NULL              |                | 
#| affy_id             | int(10)             | YES  |     | NULL              |                | 
#| protein_id          | varchar(50)         | YES  |     | NULL              |                | 
#| ms                  | float               | YES  |     | NULL              |                | 
#| bc                  | float               | YES  |     | NULL              |                | 
#| tc                  | float               | YES  |     | NULL              |                | 
#| mp                  | float               | YES  |     | NULL              |                | 
#| dry_pol             | float               | YES  |     | NULL              |                | 
#| 30min_pt            | float               | YES  |     | NULL              |                | 
#| 4h_pt               | float               | YES  |     | NULL              |                | 
#| siv_pt              | float               | YES  |     | NULL              |                | 
#| lastupdate          | timestamp           | NO   |     | CURRENT_TIMESTAMP |                | 
#+---------------------+---------------------+------+-----+-------------------+----------------+
";
    die("You forgot a column\n");
}
