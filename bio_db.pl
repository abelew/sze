#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use DBI;
use lib "$ENV{HOME}/usr/lib/perl5";
use lib 'lib';
use MyDb qw"AddOpen RemoveFile";
use MyGraph;

my $db = new MyDb;

if (defined($db->{import_pollen})) {
    if (!$db->Tablep('pollen')) {
	$db->Create_Pollen();
    }
    open(IN, "<data/sheet.csv");
    my $count = 0;
    while (my $line = <IN>) {
	$count++;
	next if ($count == 1);
	chomp $line;
	my $stmt = qq"INSERT INTO pollen (accession,tc_code,tc_description,family,family_num,protein_description,aramemnon_con,conpred_con,cluster,pollen_pref,affy_id,protein_id,ms,bc,tc,mp,dry_pol,30min_pt,4h_pt,siv_pt) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
	my @datum = split(/\,/, $line);
	my ($cp,$cf,$cl) = caller();
	$db->MyExecute(statement => $stmt,
		       caller => "$cp,$cf,$cl",
		       vars => [$datum[10],$datum[0],$datum[1],$datum[2],$datum[3],$datum[4],$datum[5],$datum[6],$datum[7],$datum[8],$datum[9],$datum[11],$datum[12],$datum[13],$datum[14],$datum[15],$datum[16],$datum[17],$datum[18],$datum[19]],);
    }
}
