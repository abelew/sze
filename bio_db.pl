#!/usr/local/bin/perl -w 
use strict;
use vars qw"$db $config";
use autodie qw(:all);
use DBI;
use lib "$ENV{MYDB_HOME}/usr/lib/perl5";
use lib "$ENV{MYDB_HOME}/lib";
use MyDb qw"AddOpen RemoveFile";
use MyGraph;
use Class::CSV;

## Set up the (hopefully) limited list of globals
my $db = new MyDb(config_file => "$ENV{MYDB_HOME}/mydb.conf");


## Process the possible command line arguments
if (defined($db->{import_pollen})) {
    $db->Create_Pollen() if (!$db->Tablep('pollen'));
    my $pollen_count = $db->MySelect(statement => "SELECT count(id) FROM pollen", type => 'single');
    if ($pollen_count < 100) {
	Import_Pollen();
    }
}
if (defined($db->{import_genome})) {
    $db->Create_Genome() if (!$db->Tablep('genome'));
    Import_Genome();
}

## All the functions which actually do work go below here.

sub Import_Genome {
    open(IN, "<data/genome.csv");
    my $count = 0;
    while (my $line = <IN>) {
	$count++;
	next if ($count == 1);
	chomp $line;
	my $stmt = qq"INSERT INTO genome (affy_id,accession,c_code,description,family,family_no,description_honys,description_qin,aramemnon_con,conpred_con,cluster,pollen_pref,protein_qin,ms,bc,tc,mp,empty,dry_pol,05_pt,4h_pt,siv_pt,avg_rt_7d,avg_rt_17d,avg_seed_8d,avg_seed_21d,avg_rosette_17,avg_ovary,avg_stigma,pol_spec,maxp,maxs,maxps) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
	my @datum = split(/\t/, $line);
	my $result = $db->MyExecute(statement => $stmt, vars => \@datum);
	die("no") if (!defined($result));
    }
}

sub Import_Pollen {
    open(IN, "<data/pollen.csv");
    my $count = 0;
    while (my $line = <IN>) {
	$count++;
	next if ($count == 1);
	chomp $line;
	my $stmt = qq"INSERT INTO pollen (accession,tc_code,tc_description,family,family_num,protein_description,aramemnon_con,conpred_con,cluster,pollen_pref,affy_id,protein_id,ms,bc,tc,mp,dry_pol,30min_pt,4h_pt,siv_pt) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
	my @datum = split(/\}/, $line);
#	foreach my $c (0 .. $#datum) {
#	    $datum[$c] =~ s/\"//g;
#	}
	## column 16 is blank
	$db->MyExecute(statement => $stmt,
		       vars => [$datum[10],$datum[0],$datum[1],$datum[2],$datum[3],$datum[4],$datum[5],$datum[6],$datum[7],$datum[8],$datum[9],$datum[11],$datum[12],$datum[13],$datum[14],$datum[15],$datum[17],$datum[18],$datum[19],$datum[20]],);
    }
}

sub Import_Annotation {    
    my $csv = Class::CSV->parse(
	filename => 'annotations.csv',
	fields   => [qw/category tc_code family_name family_abbrev family_num prot_descr_tair prot_descr_honys prot_descr_qin tm pollen_specific affy_id_qin agi_num_qin protein_id/]
         );
    foreach my $line (@{$csv->lines()}) {
	my $stmt = qq"INSERT INTO annotations (category, tc_code, family_name, family_abbrev, family_num, prot_descr_tair, prot_descr_honys, prot_descr_qin, tm, pollen_specific, affy_id_qin, agi_num_qin, protein_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)";
	$db->MyExecute(statement => $stmt,
		       vars => [$csv->category, $csv->tc_code, $csv->family_name, $csv->family_abbrev, $csv->family_num, $csv->prot_descr_tair, $csv->prot_descr_honys, $csv->prot_descr_qin, $csv->tm, $csv->pollen_specific, $csv->affy_id_qin, $csv->agi_num_qin, $csv->protein_id]);
    }
	
}
