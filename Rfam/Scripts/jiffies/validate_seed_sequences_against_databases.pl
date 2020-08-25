#!/usr/bin/env perl

use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::QC;
use Bio::Rfam::SVN::Client;
use Bio::Rfam::Utils;
use Moose;

use Getopt::Long;

my $usage  = "Usage:\nperl validate_seed_sequences_against_databases.pl <accession>\nOR\n";
   $usage .= "perl validate_seed_sequences_against_databases.pl -a <alifile>\n";

my $acc_or_alifile = undef; # single command line arg
my $a_opt          = undef; # defined if -a used

my $options_okay = &GetOptions("a" => \$a_opt);

my $exit_early = 0;
if(! $options_okay) { 
  printf("ERROR, unrecognized option;\n\n"); 
  $exit_early = 1;
}
if(scalar(@ARGV) != 1) { 
  $exit_early = 1;
}

if($exit_early) { 
  printf $usage;
  exit 0;
}
                               
$acc_or_alifile = ($ARGV[0]);
my $do_ali = (defined $a_opt) ? 1 : 0;

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

print "$acc_or_alifile\n";

my $config = Bio::Rfam::Config->new;
my $familyIO = Bio::Rfam::FamilyIO->new;
my $rfamdb = $config->rfamlive;
my $client = Bio::Rfam::SVN::Client->new({config => $config});
my $seqDBObj = $config->rfamseqObj;
my $nfail;
if(! $do_ali) { # load from DB
  #my $familyObj = $familyIO->loadRfamFromSVN($acc_or_alifile, $client);
  my $familyObj = $familyIO->loadRfamFromSVN_preSEED($acc_or_alifile, $client);
  print STDERR "Successfully loaded SVN copy of $acc_or_alifile through middleware\n";
  $nfail = Bio::Rfam::QC::checkSEEDSeqs($familyObj, $seqDBObj, 1); # the '1' tells the sub to 'be_verbose'
}
else { # -a used
  my $seed = Bio::Easel::MSA->new({
    fileLocation => $acc_or_alifile,
    isDna => 1});  
  $nfail = Bio::Rfam::QC::checkSEEDSeqs_helper($seed, $seqDBObj, 1); # the '1' tells the sub to 'be_verbose'
}

if($nfail > 0) { 
  printf("$acc_or_alifile FAIL\n");
  exit 1; 
}
printf("$acc_or_alifile PASS\n");
exit 0;


