#!/usr/bin/env perl 
#
# rewrite_seed_with_rf.pl - 'jiffy' script to rewrite SEED files before Rfam 12.0 release.
# 
# The goal of this script is to have a SEED alignment be in an
# Infernal output format, that is with RF annotation and lowercase
# inserts. But we take care to copy over E-value stats from a
# calibrated version of the same CM which was already built
# *after* verifying the new CM is the same as the original.
#
# More specifically, this script:
#
# 1. Verifies SEED is younger than CM and CM is younger than 
#    'TBLOUT', 'SCORES', etc.
# 2. Reads in a SEED and a calibrated CM built from that SEED
#    and verifies the CM came from the SEED using 'cmalign
#    --mapali SEED CM c.fa', where c.fa is the consensus 
#    sequence for the CM. This gives us a new version of the SEED
#    plus the single consensus sequence, with RF annotation.
# 3. Adds RF annotation from cmalign output to original SEED to create
#    a new SEED file, and makes all inserts lowercase and 
#    consensus residues uppercase, to make even newer SEED.
# 4. Builds even newer CM from even newer SEED and verifies 
#    even newer CM is same as new CM (and also same as original CM).
# 5. Adds E-value stats from original CM to even newer CM.
# 6. Validates that we can use --mapali with new CM and new SEED
# 7. Uses 'touch' to "update" 'TBLOUT', 'SCORES', 'REVTBLOUT', 
#    'outlist', 'species', 'taxinfo', 'revspecies', 'outlist.pdf',
#    etc.

use strict;
use warnings;
use Getopt::Long;
use File::Copy;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::Infernal;
use Bio::Rfam::Utils;

use Bio::Easel::MSA;

use Getopt::Long;

my $usage  = "rewrite_seed_with_rf.pl: updates SEED to follow infernal RF conventions,\n";
$usage .= "                         preserving pseudoknots, and verifies new SEED would\n";
$usage .= "                         create an identical CM to existing CM. Other files\n";
$usage .= "                         (DESC, REVTLBOUT, SCORES, TBLOUT, SEEDTBLOUT, SEEDSCORES)\n";
$usage .= "                         are 'touch'ed to update their timestamps (this is ok since\n";
$usage .= "                         we verified CM is unchanged). This script should be called\n";
$usage .= "                         from within a family directory (requires other files besides SEED).\n\n";
$usage .= "Usage: perl rewrite_seed_with_rf.pl [OPTIONS] SEED\n\n";
$usage .= "\tOPTIONS:\n";
$usage .= "\t--keep:  leave all intermediate output files instead of deleting them\n";
$usage .= "\t--quiet: do not output per-position SS_cons differences between input SEED and newly created SEED\n";

my $do_keep  = 0;
my $do_quiet = 0;
&GetOptions( "keep"  => \$do_keep,
             "quiet" => \$do_quiet);

if(scalar(@ARGV) != 1) { die $usage; }
my ($in_seed) = @ARGV;

if($in_seed ne "SEED") { die $usage; }

# required files in three 'tiers'. Files in tier 1 must be younger
# than those in tiers 2 and 3, and files in tier 2 must be younger
# than those in tier 3.
my @reqdFiles_t1 = ("SEED");
my @reqdFiles_t2 = ("CM");
#my @reqdFiles_t3 = ("DESC", "outlist", "outlist.pdf", "REVTBLOUT", "SCORES", "species",
#                    "species.pdf", "taxinfo", "TBLOUT");
#my @nonreqdFiles = ("revoutlist", "revspecies"); # these will only exist if there were >0 reverse hits
my @reqdFiles_t3 = ("DESC", "TBLOUT", "SCORES", "SEEDSCORES", "REVTBLOUT", "SEEDTBLOUT");
my @nonreqdFiles = ("outlist", "outlist.pdf", "species", "species.pdf", "taxinfo", "revoutlist", "revspecies"); # these will only exist if rfsearch.pl/rfmake.pl has been run

foreach my $file (@reqdFiles_t1, @reqdFiles_t2, @reqdFiles_t3) { 
  if(! -e $file) { die "ERROR, required file $file does not exist"; }
}

my $config = Bio::Rfam::Config->new;

my $io     = Bio::Rfam::FamilyIO->new;
my $famObj = Bio::Rfam::Family->new(
                                    'SEED' => {
                                               fileLocation => "SEED",
                                               aliType      => 'seed',
                                               isRna        => 1
                                              },
                                    'DESC'   => $io->parseDESC("DESC"),
                                    'CM'     => $io->parseCM("CM"),
                                   );

# Preliminary: verify that CM has E-value parameters.
my $orig_cm  = $famObj->CM;
my @evalueA = ();
my @comA    = ();
my $tmp_evalue;
my $el;
foreach $el ("ecmlc", "ecmli", "ecmgc", "ecmgi") { 
  my $uc_el = uc($el);
  if(! defined $orig_cm->{cmHeader}->{$el}->[0]) { die "ERROR no E-value stats in CM"; }
  if(! defined $orig_cm->{cmHeader}->{$el}->[1]) { die "ERROR no E-value stats in CM"; }
  if(! defined $orig_cm->{cmHeader}->{$el}->[2]) { die "ERROR no E-value stats in CM"; }
  if(! defined $orig_cm->{cmHeader}->{$el}->[3]) { die "ERROR no E-value stats in CM"; }
  if(! defined $orig_cm->{cmHeader}->{$el}->[4]) { die "ERROR no E-value stats in CM"; }
  if(! defined $orig_cm->{cmHeader}->{$el}->[5]) { die "ERROR no E-value stats in CM"; }
  $tmp_evalue = sprintf("$uc_el%11s%12s%12s%12s%12s%10s\n", 
                        $orig_cm->{cmHeader}->{$el}->[0],
                        $orig_cm->{cmHeader}->{$el}->[1],
                        $orig_cm->{cmHeader}->{$el}->[2],
                        $orig_cm->{cmHeader}->{$el}->[3],
                        $orig_cm->{cmHeader}->{$el}->[4],
                        $orig_cm->{cmHeader}->{$el}->[5]);
  push(@evalueA, $tmp_evalue);
}

if(! defined $orig_cm->{cmHeader}->{com}->[0]) { die "ERROR no COM lines in CM"; }
if(! defined $orig_cm->{cmHeader}->{com}->[1]) { die "ERROR only one COM line in CM"; }
if(defined $orig_cm->{cmHeader}->{com}->[2])   { die "ERROR three COM lines in CM"; }
push(@comA, "COM      [1] $orig_cm->{cmHeader}->{com}->[0]\n");
push(@comA, "COM      [2] $orig_cm->{cmHeader}->{com}->[1]\n");

if(scalar(@evalueA) != 4) { die "ERROR creating E-value stats array"; }
if(scalar(@comA)    != 2) { die "ERROR creating COM array"; }


####################################################################################################
# 1. Verifies CM is younger than 'TBLOUT', 'SCORES', etc.
#    We used to verify SEED was younger than CM, but that's actually
#    not strictly necessary, a more important test is whether the CM
#    was built from the SEED, which is a test we DO do below. So 
#    as of now we don't require SEED be older than CM here (there
#    were about 25 families in the rethresholded dir for which 
#    SEED was younger than CM...).

my ($file1, $file2);
# verify all required files exist
foreach $file1 (@reqdFiles_t1, @reqdFiles_t2, @reqdFiles_t3) { 
  if(($file1 eq "SCORES") || ($file1 eq "SEEDSCORES")) {
    # SCORES or SEEDSCORES must exist but it may be empty
    if(! -e $file1) {
      die "ERROR required file $file1 does not exist";
    }
  }
  else { # file other than SCORES and SEEDSCORES, should be non-empty
    if(! -s $file1) {
      die "ERROR required file $file1 does not exist or is empty!";
    }
  }
}

# IF WE WANT TO MAKE SURE SEED IS YOUNGER THAN CM, UNCOMMENT THIS BLOCK
# verify files in tier 1 are older than those in tier 2
#foreach $file1 (@reqdFiles_t1) { 
#  foreach $file2 (@reqdFiles_t2) { 
#    if(! Bio::Rfam::Utils::youngerThan($file2, $file1)) { 
#      die "ERROR file in tier 1: $file1 not older than file in tier 2: $file2\n"; 
#    }
#  }
#}

# verify files in tier 2 are older than those in tier 3
foreach $file1 (@reqdFiles_t2) { 
  foreach $file2 (@reqdFiles_t3) { 
    if(! Bio::Rfam::Utils::youngerThan($file2, $file1)) { 
      die "ERROR file in tier 2: $file1 not older than file in tier 3: $file2\n"; 
    }
  }
}

####################################################
# 2. Reads in a SEED and a calibrated CM built from that SEED
#    and verifies the CM came from the SEED using 'cmalign
#    --mapali SEED CM c.fa', where c.fa is the consensus 
#    sequence for the CM. This gives us a new version of the SEED
#    plus the single consensus sequence, with RF annotation.
#
# A. verify a --mapali will work, this will make sure the checksum of the input alignment 
#    matches the one in the CM file, and save the output alignment
#    as SEED.1, we'll use this to map RF annotation to the original
#    SEED.
verify_cm_built_from_seed($config, "CM", "SEED", "SEED.1", $do_keep);

# B. verify the COM cmbuild line matches the passed in $desc_opts
#    which were read from the DESC file.
my $desc = $famObj->DESC;
my $desc_buildopts = $desc->{'BM'};
my $cm_buildopts = $orig_cm->{cmHeader}->{com}->[0];
$cm_buildopts =~ s/^.+cmbuild/cmbuild/;

if($desc_buildopts ne $cm_buildopts) { die "ERROR cmbuild option/command read from DESC differs from that in CM file: $desc_buildopts != $cm_buildopts"; }

###############################################################
# 3. Adds RF annotation from new SEED to original SEED to create
#    a new SEED file, and makes all inserts lowercase and 
#    consensus residues uppercase, to make even newer SEED.
#
# OLD WAY: use cmbuild -O output alignment, this worked on nearly all models but was NOT
# guaranteed to work on zero basepair models because cmbuild 'doctor's those parsetrees
# a la HMMER and may shift an insert into a match which eliminates the guarantee that 
# we can map the RF onto the original SEED. 
# add_rf_and_ss_cons_given_cmbuild_O("SEED", "SEED.1", "SEED.2", $orig_cm->{cmHeader}->{clen});

# NEW WAY: use cmalign --mapali output alignment, which preserves the input alignment
# (the original seed in this case) exactly (it never doctors parsetrees (yes, HMMER
# works the same way)).

# if --checkonly used, 

if(-e "SEED") { copy("SEED", "SEED.0"); }
my $diff_str = add_rf_and_ss_cons_given_cmalign_mapali_output("SEED", "SEED.1", "SEED.2", $orig_cm->{cmHeader}->{clen}, $do_quiet);

##############################################################
# 4. Builds even newer CM from even newer SEED and verifies 
#    even newer CM is same as new CM (and also same as original CM).
my $outfile = "b2.$$.out";
my $buildopts = $desc_buildopts; 
$buildopts =~ s/^cmbuild\s+//; # remove 'cmbuild ', cmbuild_wrapper will automatically add this
$buildopts =~ s/\s*-F\s*/ /;   # remove -F,         cmbuild_wrapper will automatically add this
$buildopts =~ s/\s*CM\s*/ /;   # remove 'CM',       cmbuild_wrapper will automatically add this
$buildopts =~ s/\s*SEED\s*/ /; # remove 'SEED',     cmbuild_wrapper will automatically add this
if(-e "CM")   { copy("CM"  , "CM.0"); }

Bio::Rfam::Infernal::cmbuild_wrapper($config, "$buildopts", "CM.1", "SEED.2", $outfile);
verify_two_cms_have_identical_parameters("CM.1", "CM", 0.00000001);
if(! $do_keep) { 
  unlink $outfile;
}

##############################################################
# 5. Adds E-value stats from original CM to even newer CM.
add_evalue_and_com_lines_to_cm("CM.1", "CM.2", \@evalueA, \@comA);

################################################################
# 6. Validates that we can use --mapali with new CM and new SEED
if(-e "CM.2") { copy("CM.2", "CM"); }
else          { die "ERROR, CM.2 does not exist"; }

if(-e "SEED.2") { copy("SEED.2", "SEED"); }
else          { die "ERROR, SEED.2 does not exist"; }

verify_cm_built_from_seed($config, "CM", "SEED", undef, $do_keep);
# now CM and SEED are the updated versions

##############################################################
# 7. Uses 'touch' to "update" 'TBLOUT', 'SCORES', 'REVTBLOUT', 
#    'outlist', 'species', 'taxinfo', 'revspecies', 'outlist.pdf',
#    etc.

my $file;
foreach $file (@reqdFiles_t1, @reqdFiles_t2, @reqdFiles_t3) { 
  if(! -e $file) { die "ERROR file $file does not exist"; }
  system("touch $file");
  sleep(1);
}

foreach $file (@nonreqdFiles) { 
  if(-e $file) { 
    system("touch $file");
  }
  sleep(1);
}

# clean up
if(! $do_keep) { 
  foreach $file ("SEED.1", "SEED.2", "CM.1", "CM.2") { 
    if(-e $file) { unlink $file; }
  }
}

print "New      CM and seed alignment saved as CM and SEED\n";
print "Original CM and seed alignment saved as CM.0 and SEED.0\n";
print "CM parameters verified to be identical in files CM and CM.0\n";
print $diff_str . "\n";


###############
# SUBROUTINES #
###############

# add_rf_and_ss_cons_given_cmalign_mapali_output():
# Given an original SEED alignment ($orig_infile) used to build a CM, and an alignment
# output from cmalign --mapali ($cmalign_mapali_infile) with a single extra sequence other
# than the original SEED, add RF and SS_cons annotation to the original SEED alignment 
# and save it as $outfile.
#
# Returns possibly multi-line string reporting per-position changes in SS_cons
# or "SS_cons unchanged" if it does not change.
sub add_rf_and_ss_cons_given_cmalign_mapali_output {
  my ($orig_infile, $cmalign_mapali_infile, $outfile, $clen, $do_quiet) = @_;

  # read in original seed
  my $orig_seed = Bio::Easel::MSA->new({
    fileLocation => $orig_infile,
    forceText    => 1
                                       });
  my $save_orig_ss_cons = $orig_seed->get_ss_cons();
  
  # read in new seed plus consensus sequence aligned (created with cmalign --mapali SEED CM c.fa)
  my $tmp_seed  = Bio::Easel::MSA->new({
    fileLocation => $cmalign_mapali_infile,
    forceText    => 1
   });
  
  # remove final sequence, the consensus sequence, to get a new alignment
  my @usemeA = ();
  my $i;
  for($i = 0;                  $i < $orig_seed->nseq; $i++) { $usemeA[$i] = 1; }
  for($i = $orig_seed->nseq(); $i < $tmp_seed->nseq;  $i++) { $usemeA[$i] = 0; }
  my $new_seed = $tmp_seed->sequence_subset(\@usemeA);
  undef $tmp_seed;

  # verify sequences are in the same order in each MSA
  for(my $i = 0; $i < $orig_seed->nseq(); $i++) { 
    if($orig_seed->get_sqname($i) ne $new_seed->get_sqname($i)) { 
      die "ERROR sequences in SEED and SEED.1 are in a different order.";
    }
  }

  # Map the two alignments: for each nongap RF column in the $new_seed,
  # we should be able to unambiguously match an identical column in the $orig_seed.
  # We'll use this map to create the RF and SS_cons strings for the original
  # alignments.
  my $orig_alen = $orig_seed->alen();
  my $new_alen  = $new_seed->alen();
  
  my $new_rf       = $new_seed->get_rf();
  my @new_rfA      = split("", $new_rf);
  
  my $new_ss_cons  = $new_seed->get_ss_cons();
  my @new_ss_consA = split("", $new_ss_cons);
  
  my $cpos         = 0;
  my $new_apos     = 0;
  my $orig_apos    = 0;
  my $orig_rf      = "";
  my $orig_ss_cons = "";
  while(($new_apos < $new_alen) && ($cpos < $clen)) { 
    while($new_rfA[$new_apos] !~ m/[a-zA-Z]/) { 
      $new_apos++;
    }
    $cpos++;
    #printf("cpos: $cpos new_apos: $new_apos orig_apos: $orig_apos\n");
    # get this column of the original seed
    my $new_col = $new_seed->get_column($new_apos+1);
    # find identical column in new seed
    my $found_match = 0;
    while((! $found_match) && ($orig_apos < $orig_alen)) { 
      my $orig_col = $orig_seed->get_column($orig_apos+1);
      $orig_col =~ tr/a-z/A-Z/;     # translate to upper case
      $orig_col =~ tr/T/U/;         # translate Ts to Us
      $orig_col =~ s/[^A-Za-z]/-/g; # translate non-alphacharacters to Infernal consensus gap char: '-'
      if($orig_col eq $new_col) { 
        $found_match = 1; 
        # printf("\tfound match new:orig $new_apos:$orig_apos\n"); 
        $orig_rf      .= "$new_rfA[$new_apos]";
        $orig_ss_cons .= "$new_ss_consA[$new_apos]";
      }
      else { 
        $orig_rf      .= ".";
        $orig_ss_cons .= ".";
      }
      $orig_apos++;
    }
    $new_apos++;
    if((! $found_match) && ($orig_apos == $orig_alen)) { die "ERROR unable to find match for consensus position $cpos"; }
  }
  # we've reached clen, deal with possibility of inserts after final cpos
  while(length($orig_rf) < $orig_alen) { $orig_rf .= "."; $orig_ss_cons .= "."; }

  $orig_seed->set_rf($orig_rf);
  $orig_seed->set_ss_cons($orig_ss_cons);
  $orig_seed->capitalize_based_on_rf();
  $orig_seed->remove_gap_rf_basepairs(1); # 1: wussify SS_cons and change gap RF columns to '.' in SS_cons

  # determine if SS_cons has changed, and construct return string
  my $new_orig_ss_cons = $orig_seed->get_ss_cons();
  my $ret_str = undef;
  if($save_orig_ss_cons ne $new_orig_ss_cons) {
    if(length($save_orig_ss_cons) == length($new_orig_ss_cons)) {
      if(! $do_quiet) { 
        $ret_str = "Between SEED and SEED.0, SS_cons changed, per-position differences:\n";
        my @save_A = split("", $save_orig_ss_cons);
        my @new_A  = split("", $new_orig_ss_cons);
        for(my $z = 0; $z < scalar(@save_A); $z++) {
          if($save_A[$z] ne $new_A[$z]) { 
            $ret_str .= sprintf("\tposition %5d changed from %s to %s\n", $z, $save_A[$z], $new_A[$z]);
          }
        }
      }
      else {
        $ret_str = "Between SEED and SEED.0, SS_cons changed.";
      }
    }
    else { 
      $ret_str = "Between SEED and SEED.0, SS_cons changed, lengths differ, compare SEED.0 and SEED to see differences.";
    }
  }
  else {
    $ret_str = "Between SEED and SEED.0 SS_cons unchanged.";
  }
  
  $orig_seed->write_msa($outfile);
  
  return $ret_str;
}

#######################################################################
# OLD WAY: we used to map RF and SS_cons using this method but it
# can fail on zero basepair models because cmbuild doctors parsetrees.
#
# add_rf_and_ss_cons_given_cmbuild_O():
# Given an original SEED alignment ($orig_infile) used to build a CM, and the output -O 
# alignment from cmbuild ($cmbuild_O_infile) created when the CM was built from the SEED,
# add RF and SS_cons annotation to the original SEED alignment and save it as $outfile in
# Pfam format.
sub add_rf_and_ss_cons_given_cmbuild_O {

  my ($orig_infile, $cmbuild_O_infile, $outfile, $clen) = @_;

  # read in original seed
  my $orig_seed = Bio::Easel::MSA->new({
    fileLocation => $orig_infile,
    forceText    => 1
      });
  
  # read in new seed (created with cmbuild -O)
  my $new_seed  = Bio::Easel::MSA->new({
    fileLocation => $cmbuild_O_infile,
    forceText    => 1
      });
  

  # verify sequences are in the same order in each MSA
  for(my $i = 0; $i < $orig_seed->nseq(); $i++) { 
    if($orig_seed->get_sqname($i) ne $new_seed->get_sqname($i)) { 
      die "ERROR sequences in SEED and SEED.1 are in a different order.";
    }
  }

  # Map the two alignments: for each nongap RF column in the $new_seed,
  # we should be able to unambiguously match an identical column in the $orig_seed.
  # We'll use this map to create the RF and SS_cons strings for the original
  # alignments.
  my $orig_alen = $orig_seed->alen();
  my $new_alen  = $new_seed->alen();
  
  my $new_rf       = $new_seed->get_rf();
  my @new_rfA      = split("", $new_rf);
  
  my $new_ss_cons  = $new_seed->get_ss_cons();
  my @new_ss_consA = split("", $new_ss_cons);
  
  my $cpos         = 0;
  my $new_apos     = 0;
  my $orig_apos    = 0;
  my $orig_rf      = "";
  my $orig_ss_cons = "";
  while(($new_apos < $new_alen) && ($cpos < $clen)) { 
    while($new_rfA[$new_apos] !~ m/[a-zA-Z]/) { 
      $new_apos++;
    }
    $cpos++;
    printf("cpos: $cpos new_apos: $new_apos orig_apos: $orig_apos\n");
    # get this column of the original seed
    my $new_col = $new_seed->get_column($new_apos+1);
    # find identical column in new seed
    my $found_match = 0;
    while((! $found_match) && ($orig_apos < $orig_alen)) { 
      my $orig_col = $orig_seed->get_column($orig_apos+1);
      $orig_col =~ tr/a-z/A-Z/;     # translate to upper case
      $orig_col =~ s/[^A-Za-z]/-/g; # translate non-alphacharacters to Infernal consensus gap char: '-'
      if($orig_col eq $new_col) { 
        $found_match = 1; 
        # printf("\tfound match new:orig $new_apos:$orig_apos\n"); 
        $orig_rf      .= "$new_rfA[$new_apos]";
        $orig_ss_cons .= "$new_ss_consA[$new_apos]";
      }
      else { 
        $orig_rf      .= ".";
        $orig_ss_cons .= ".";
      }
      $orig_apos++;
    }
    $new_apos++;
    if((! $found_match) && ($orig_apos == $orig_alen)) { die "ERROR unable to find match for consensus position $cpos"; }
  }
  # we've reached clen, deal with possibility of inserts after final cpos
  while(length($orig_rf) < $orig_alen) { $orig_rf .= "."; $orig_ss_cons .= "."; }

  $orig_seed->set_rf($orig_rf);
  $orig_seed->set_ss_cons($orig_ss_cons);
  $orig_seed->capitalize_based_on_rf();
  
  $orig_seed->write_msa($outfile);
  
  return;
}

#################################
# verify_two_cms_have_identical_parameters()
# Given the names of two CM files, verify that they 
# have identical model parameters, including profile
# HMM filter parameters. Do not check that other information
# is identical, e.g. checksum, or E-value statistics.

sub verify_two_cms_have_identical_parameters { 

  my ($cmfile1, $cmfile2, $thr) = @_;

  my ($line1, $line2, $i, $nlines);
  my $cm1 = $io->parseCM($cmfile1);
  my $cm2 = $io->parseCM($cmfile2);

  # check CM parameters
  $nlines = scalar(@{$cm1->{cmBody}});
  for($i = 0; $i < $nlines; $i++) { 
    $line1 = $cm1->{cmBody}->[$i];
    $line2  = $cm2->{cmBody}->[$i];
    if($line1 ne $line2) { 
      validate_line_given_precision_threshold($line1, $line2, $thr);
      # this will die if lines are not equal with allowed precision difference
    }
  }

  # check profile HMM filter parameters
  $nlines = scalar(@{$cm1->{hmmBody}});
  for(my $i = 0; $i < $nlines; $i++) { 
    $line1 = $cm1->{hmmBody}->[$i];
    $line2  = $cm2->{hmmBody}->[$i];
    if($line1 ne $line2) { 
      validate_line_given_precision_threshold($line1, $line2, $thr); 
      # this will die if lines are not equal with allowed precision difference
    }
  }

  # printf("$cmfile1 and $cmfile2 have identical model parameters.\n");
  return;
}

##########################################
# validate_line_given_precision_threshold
sub validate_line_given_precision_threshold { 
  my($line1, $line2, $thr) = @_;

  if($thr >= 1) { die "in validate_line_given_precision_threshold() threshold too high"; }
  
  my @elA1 = split(/\s+/, $line1);
  my @elA2 = split(/\s+/, $line2);

  my $nel1 = scalar(@elA1);
  my $nel2 = scalar(@elA2);
  if($nel1 != $nel2) { die "validate_line_given_precision_threshold() different number of elements on lines:\n$line1\n$line2"; }

  for(my $i = 0; $i < $nel1; $i++) { 
    my $el1 = $elA1[$i];
    my $el2 = $elA2[$i];
    if($el1 ne $el2) { 
      # check if it's a number
      if($el1 =~ /(\d+)(\.\d+)/) { 
        my($n1a, $n1b) = ($1, $2);
        if($el2 =~ /(\d+)(\.\d+)/) { 
          my($n2a, $n2b) = ($1, $2);
          if($n1a ne $n2a) { die "validate_line_given_precision_threshold() number mismatch $n1a != $n2a in ($el1 vs $el2) on lines:\n$line1\n$line2"; }
          if($n1b ne $n2b) { 
            if(abs($n1b - $n2b) > $thr) { 
              die "validate_line_given_precision_threshold() number mismatch given precision $thr, $n1b != $n2b in ($el1 vs $el2) on lines:\n$line1\n$line2"; 
            }
          }
        }
        else { 
          die "validate_line_given_precision_threshold() mismatch that isn't a number on lines:\n$line1\n$line2"; 
        }
      }
    }
  }
  return;
}

#################################
# add_evalue_lines_to_cm
#
# Given a CM file without E-value lines, and an array of E-value
# parameter lines and COM lines, create a new CM file that is identical to the
# given one but has the E-value lines added and its COM lines replaced with 
# those in comAR.

sub add_evalue_and_com_lines_to_cm {

  my ($in_cmfile, $out_cmfile, $evalueAR, $comAR) = @_;

  open(IN,  $in_cmfile)        || die "ERROR unable to open $in_cmfile for reading";
  open(OUT, ">" . $out_cmfile) || die "ERROR unable to open $out_cmfile for writing";

  my ($line, $line2);
  while($line = <IN>) { 
    if($line =~ m/^COM/) { 
      foreach $line2 (@{$comAR}) { 
        print OUT $line2;
      }
    }
    else { # not a COM line, regurgitate it
      print OUT $line;
      if($line =~ m/^EFP7GF/) { 
        foreach $line2 (@{$evalueAR}) { 
          print OUT $line2;
        }
      }
      if($line =~ m/^ECM/) { 
        die "ERROR, output CM already has E-value statistics"; 
      }
    }
  }
  close(OUT);
  return;
}      

#################################
# verify_cm_built_from_seed
#
# Given a CM file and a SEED, verify that the SEED was used to build
# the CM, with verifying that a --mapali will work, this will make 
# sure the checksum of the input alignment matches the one in the CM file.
#
# If $stkfile is undefined, unlink it at end of function, otherwise
# save output alignment as $stkfile and don't unlink it.
#
# If $do_keep: don't unlink any files
sub verify_cm_built_from_seed { 

  my ($config, $cmfile, $seedfile, $stkfile, $do_keep) = @_;

  my $unlink_stkfile;

  # 1. verify a --mapali will work, this will make sure the checksum of the input alignment 
  #    matches the one in the CM file.

  # generate $fafile using 'cmemit -c'
  my $fafile = "$$.fa";
  Bio::Rfam::Infernal::cmemit_wrapper($config, "-c -o $fafile", $cmfile, undef, 0);

  # align to CM with --mapali
  if(! defined $stkfile) { 
    $stkfile = "$$.stk";
    $unlink_stkfile = 1;
  }
  else { 
    $unlink_stkfile = 0;
  }
  Bio::Rfam::Infernal::cmalign_wrapper($config, "", "", "--mapstr --mapali $seedfile -o $stkfile", "CM", $fafile, undef, "", 1, 100, 1, 0, 0, "", 1, undef, 0);
  # we'll die if $seedfile wasn't used to build $cmfile

  if(! $do_keep) { 
    unlink $fafile;
    if($unlink_stkfile) { 
      unlink $stkfile;
    }
  }

  return;
}
