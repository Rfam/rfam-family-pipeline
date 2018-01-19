#!/usr/bin/env perl 
# usage: perl convert_bitscores.pl rfam_acc >> full_region.txt
# The script will use the regions from the familyIO object which loads from the database,
# convert and use the 
use strict;
use warnings;
use File::Copy;
use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::Infernal;
use Bio::Rfam::Utils;
use Bio::Rfam::Family;

# parameters
my $rfam_acc = $ARGV[0];

my $config = Bio::Rfam::Config->new;
my $familyIO = Bio::Rfam::FamilyIO->new;
my $rfamdb = $config->rfamlive; # may not need this one
my $familyIO_obj = $familyIO->loadRfamFromRDB($rfam_acc);

my $regions = $familyIO_obj->{'SCORES'}->regions;

# variable declaration and initialization
my $new_evalue = 0.0;
my $bit_score = 0;

my $opt = "-Z --rfam --nohmmonly --notextw --cut_ga --tblout --mpi --acc";

# may need to change $config->seqdbConfig("rfamseq")->{"dbSize"} to a command line argument
foreach my $region (@$regions) {
	$bit_score = $region->[4];
	$new_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($familyIO_obj->{'CM'}, $bit_score, $config->seqdbConfig("rfamseq")->{"dbSize"}, $opt); 
	print "$rfam_acc\t$region->[3]\t$region->[1]\t$region->[2]\t$region->[4]\t$new_evalue\t$region->[6]\t$region->[7]\t$region->[8]\t$region->[9]\t$region->[10]\n";
	$bit_score = 0;
	$new_evalue = 0.0;
}
1;


