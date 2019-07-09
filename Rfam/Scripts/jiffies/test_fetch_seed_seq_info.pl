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

my $usage  = "Usage:\nperl test_fetch_seed_seq_info.pl <accession>\nOR\n";
   $usage .= "perl test_fetch_seed_seq_info.pl -a <alifile>\n";

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

print "$acc_or_alifile\n";

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

my $seed = undef;
if(! $do_ali) { # load from DB
  my $config = Bio::Rfam::Config->new;
  my $familyIO = Bio::Rfam::FamilyIO->new;
  my $rfamdb = $config->rfamlive;
  my $client = Bio::Rfam::SVN::Client->new({config => $config});
  my $seqDBObj = $config->rfamseqObj;

  #my $familyObj = $familyIO->loadRfamFromSVN($acc_or_alifile, $client);
  my $familyObj = $familyIO->loadRfamFromSVN_preSEED($acc_or_alifile, $client);
  print STDERR "Successfully loaded SVN copy of $acc_or_alifile through middleware\n";
  $seed = $familyObj->SEED;
}
else { # -a used
  $seed = Bio::Easel::MSA->new({
    fileLocation => $acc_or_alifile,
    isDna => 1});  
}

my %seed_info_HH; # 1D key is seed sequence name (name/start-end format)
                  # 2D keys are many of the field names in Rfamseq and Taxonomy tables 
                  # (see fetch_seed_sequence_info() for details)
Bio::Rfam::FamilyIO::fetch_seed_sequence_info($seed, undef, undef, \%seed_info_HH);
printf("HEYA back from fetch_seed_sequence_info()\n");

exit 0;


