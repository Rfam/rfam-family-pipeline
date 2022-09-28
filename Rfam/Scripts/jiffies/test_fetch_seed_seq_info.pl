#!/usr/bin/env perl
#
# test_fetch_seed_seq_info.pl: 
# Call FamilyIO::fetch_seed_sequence_info.pl for a family's SEED
# either given the family's accession (if it's already in the DB)
# or given the stockholm SEED alignment with '-a <alifile>'
#
use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::QC;
use Bio::Rfam::SVN::Client;
use Bio::Rfam::Utils;

use Getopt::Long;

my $usage  = "Usage:\nperl test_fetch_seed_seq_info.pl <accession>\n";
$usage  .= "\tOPTIONS:\n";
$usage  .= "\t-a: input cmdline argument is an <alifile> not <accession>\n";
$usage  .= "\t-f: force getting info NCBI for all sequences, even those already in RfamLive\n";

my $acc_or_alifile = undef; # single command line arg
my $a_opt          = undef; # defined if -a used
my $f_opt          = undef; # defined if -f used

my $options_okay = &GetOptions("a" => \$a_opt,
                               "f" => \$f_opt);

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
my $do_ali   = (defined $a_opt) ? 1 : 0;
my $do_force = (defined $f_opt) ? 1 : 0;

print "$acc_or_alifile\n";

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

my $seed = undef;
my $config = undef;
my $familyIO = undef;
my $rfamdb = undef;
my $client = undef;
my $seqDBObj = undef;

# setup the config and db unless -a and -f both used 
if((! $do_force) || (! $do_ali)) {
  $config = Bio::Rfam::Config->new;
  $rfamdb = $config->rfamlive;
  $familyIO = Bio::Rfam::FamilyIO->new;
  $client = Bio::Rfam::SVN::Client->new({config => $config});
  $seqDBObj = $config->rfamseqObj;
}
if(! $do_ali) { # load from DB
  #my $familyObj = $familyIO->loadRfamFromSVN($acc_or_alifile, $client);
  my $familyObj = $familyIO->loadRfamFromSVN_preSEED($acc_or_alifile, $client);
  print STDERR "Successfully loaded SVN copy of $acc_or_alifile through middleware\n";
  $seed = $familyObj->SEED;
}
else { # -a used, load from alignment file
  $seed = Bio::Easel::MSA->new({
    fileLocation => $acc_or_alifile,
    isDna => 1});  
}

my %seed_info_HH; # 1D key is seed sequence name (name/start-end format)
                  # 2D keys are many of the field names in Rfamseq and Taxonomy tables 
                  # (see fetch_seed_sequence_info() for details)

if($do_force) { # -f used, force ncbi fetch of all seqs
  Bio::Rfam::FamilyIO::fetch_seed_sequence_info($seed, undef, undef, \%seed_info_HH);
}
else { # -f not used, only fetch info on seqs not already in rfamlive
  my $sthRfamseqSeed = $rfamdb->prepare_seqaccToTaxIdDescLengthMolTypeAndSource();
  my $sthTaxSeed     = $rfamdb->prepare_taxIdToSpeciesDisplayNamesAndTaxString();
  Bio::Rfam::FamilyIO::fetch_seed_sequence_info($seed, $sthRfamseqSeed, $sthTaxSeed, \%seed_info_HH);
}

for(my $i = 0; $i < $seed->nseq; $i++) { 
  my $seed_name = $seed->get_sqname($i);
  printf("$seed_name\n");
  if(! defined $seed_info_HH{$seed_name}) { 
    printf("\tNO DATA\n");
  }
  else { 
    foreach my $key (sort keys %{$seed_info_HH{$seed_name}}) { 
      print("\t$key: $seed_info_HH{$seed_name}{$key}\n");
    }
  }
}

exit 0;


