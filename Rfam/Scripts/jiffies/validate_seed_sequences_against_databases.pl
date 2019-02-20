#!/usr/bin/env perl

use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
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

my $familyObj = $familyIO->loadRfamFromSVN($family, $client);
print STDERR "Successfully loaded SVN copy of $family through middleware\n";

my $nrfm_pass = 0;
my $ngbk_pass = 0;
my $nrnc_pass = 0;
my $nfail = 0;
# look-up each SEED sequence
for ( my $i = 0 ; $i < $familyObj->SEED->nseq ; $i++ ) {
  my $name_or_nse  = $familyObj->SEED->get_sqname($i);
  my $seed_msa_seq = $familyObj->SEED->get_sqstring_unaligned($i);
  my $seed_md5 = Bio::Rfam::Utils::md5_of_sequence_string($seed_msa_seq);

  # lookup in rfamseq
  my ($rfamseq_has_source_seq, $rfamseq_has_exact_seq, $rfamseq_md5) = Bio::Rfam::Utils::rfamseq_nse_lookup_and_md5($seqDBObj, $name_or_nse);

  # lookup in GenBank
  my ($genbank_has_source_seq, $genbank_has_exact_seq, $genbank_md5) = Bio::Rfam::Utils::genbank_nse_lookup_and_md5($name_or_nse);

  # lookup in RNAcentral
  my ($rnacentral_has_exact_seq, $rnacentral_md5, $rnacentral_id) = Bio::Rfam::Utils::rnacentral_md5_lookup($seed_md5);

  # output
  my $passfail = "PASS";
  my $outstr   = "";
  # check if it fails for any of following reasons:
  # 1) not in any of Rfamseq, GenBank, or RNAcentral
  # 2) source seq exists in Rfamseq, but not subseq (start-end)
  # 3) source seq exists in GenBank, but not subseq (start-end)
  # 4) subseq appears to exist in Rfamseq, but md5 does not match
  # 5) subseq appears to exist in GenBank, but md5 does not match
  # 6) subseq appears to exist in RNAcentral, but md5 does not match
  #    (THIS SHOULD BE IMPOSSIBLE BECAUSE WE LOOK UP IN RNACENTRAL BASED ON md5)
  if((! $rfamseq_has_source_seq) && (! $genbank_has_source_seq) && (! $rnacentral_has_exact_seq)) { 
    # 1) not in any of Rfamseq, GenBank, or RNAcentral
    $passfail = "FAIL";
    $outstr .= "NO-MATCHES";
  }
  if(($rfamseq_has_source_seq) && (! $rfamseq_has_exact_seq)) { 
    # 2) source seq exists in Rfamseq, but not subseq (start-end)
    $passfail = "FAIL";
    $outstr .= "RFM:found-seq-but-not-subseq;";
  }
  if(($genbank_has_source_seq) && (! $genbank_has_exact_seq)) { 
    # 3) source seq exists in GenBank, but not subseq (start-end)
    $passfail = "FAIL";
    $outstr .= "GBK:found-seq-but-not-subseq;";
  }
  if($rfamseq_has_exact_seq) { 
    if($rfamseq_md5 ne $seed_md5) {
      # 4) subseq appears to exist in Rfamseq, but md5 does not match
      $passfail = "FAIL";
      $outstr .= "RFM:md5-fail;";
    }
    else { 
      $outstr .= "RFM:md5-pass;";
      $nrfm_pass++;
    }        
  }
  if($genbank_has_exact_seq) { 
    if($genbank_md5 ne $seed_md5) {
      # 5) subseq appears to exist in GenBank, but md5 does not match
      $passfail = "FAIL";
      $outstr .= "GBK:md5-fail;";
    }
    else { 
      $outstr .= "GBK:md5-pass;";
      $ngbk_pass++;
    }        
  }
  if($rnacentral_has_exact_seq) { 
    if($rnacentral_md5 ne $seed_md5) {
      # 6) subseq appears to exist in RNAcentral, but md5 does not match
      #    (THIS SHOULD BE IMPOSSIBLE BECAUSE WE LOOK UP IN RNACENTRAL BASED ON md5)
      $passfail = "FAIL";
      $outstr .= "RNC:md5-fail;";
    }
    else { 
      $outstr .= "RNC:md5-pass;";
      $nrnc_pass++;
    }
  }

  printf("%-30s  $passfail  $outstr\n", $name_or_nse);
  
  if($passfail eq "FAIL") { $nfail++; }
}
print("nrfm_pass: $nrfm_pass\n");
print("ngbk_pass: $ngbk_pass\n");
print("nrnc_pass: $nrnc_pass\n");
print("nfail:     $nfail\n");

if($nfail > 0) { 
  printf("$family FAIL\n");
  exit 1; 
}
printf("$family PASS\n");
exit 0;


