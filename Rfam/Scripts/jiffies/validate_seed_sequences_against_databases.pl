#!/usr/bin/env perl

use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::QC;
use Bio::Rfam::SVN::Client;
use Bio::Rfam::Utils;

my $family = shift;

unless(defined($family)){
  die "Please provide a family\n";
}
print "$family\n";

my $config = Bio::Rfam::Config->new;
my $familyIO = Bio::Rfam::FamilyIO->new;
my $rfamdb = $config->rfamlive;
my $client = Bio::Rfam::SVN::Client->new({config => $config});
my $seqDBObj = $config->rfamseqObj;

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

#my $familyObj = $familyIO->loadRfamFromSVN($family, $client);
my $familyObj = $familyIO->loadRfamFromSVN_preSEED($family, $client);
print STDERR "Successfully loaded SVN copy of $family through middleware\n";

my $nfail = Bio::Rfam::QC::checkSEEDSeqs($familyObj, $seqDBObj, 1); # the '1' tells the sub to 'be_verbose'

if($nfail > 0) { 
  printf("$family FAIL\n");
  exit 1; 
}
printf("$family PASS\n");
exit 0;


