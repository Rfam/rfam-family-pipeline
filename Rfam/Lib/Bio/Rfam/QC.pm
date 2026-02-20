
=head1 NAME

Bio::Rfam::QC - a module that performs QC on Rfam data.

=cut

package Bio::Rfam::QC;

=head1 DESCRIPTION

A more detailed description of what this class does and how it does it.

=head1 COPYRIGHT

File: QC.pm

Copyright (c) 2013:


Author: Rob Finn (rdf 'at' ebi.ac.uk or finnr 'at' janelia.hhmi.org)
Incept: finnr, Jan 25, 2013 8:43:56 AM

=cut

use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Copy;
use Data::Printer;
use Data::Dump qw(dump);
use IPC::Run qw(run);
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

#Templating this off the old code.....
sub checkFamilyFiles {
  my ( $family, $upFamilyObj ) = @_;

  #Removed QC check below; this is now conducted as part of the checkin, and
  #not prior to checkin as it was in Sanger. Therefore no point looking for
  #qcpassed file:

  #&checkQCPerformed($family, $upFamilyObj);

  #Now return result of timestamp check:
  return checkTimestamps($family,$upFamilyObj);
	#return 1 on failure.
}

sub checkQCPerformed {
  #my ($dir, $acc, $config ) = @_;
  my ($dir, $config, $acc ) = @_;

 #need to add in this for checking the qc has been done-dont allow ci otherwise.
  if ( !-e "$dir/$acc/qcpassed" ) {
    die "rfci: [$acc] has not been passed by qc checks so not ready to check in - run rqc-all.pl\n";
  }

  foreach my $f ( @{ $config->mandatoryFiles } ) {

    if( -M "$dir/$acc/$f" <= -M "$dir/$acc/qcpassed" ){
    die
  "You need to rerun the rqc-all.pl as $f has changed since you ran it last\n";
    }
  }

}

#Ended templating...I feel dirty.

#------------------------------------------------------------------------------

=head2 checkFamilyFormat

  Title    : checkFamilyFormat
  Incept   : finnr, Jul 24, 2013 2:29:22 PM
  Usage    : Bio::Rfam::QC::checkFamily($familyObj)
  Function : Performs series of format checks
  Args     : A Bio::Rfam::Family object
  Returns  : 1 if an error is found,

=cut

sub checkFamilyFormat {
  my ($familyObj, $config) = @_;
	#print "$familyObj\n";
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    #print "$familyObj\n";
	die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  my $error = 0;
  $error = checkDESCFormat($familyObj);
  if ($error) {
    return $error;
  }
  $error = checkSEEDFormat($familyObj);
  if ($error) {
    return $error;
  }
  $error = checkCMFormat($familyObj, $config);
  if ($error) {
    return $error;
  }
  $error = checkScoresFormat($familyObj);
  return $error;

}

#------------------------------------------------------------------------------

=head2 checkSEEDFormat

  Title    : checkSEEDFormat
  Incept   : finnr, Jul 24, 2013 2:36:13 PM
  Usage    : Bio::Rfam::QC::checkSEEDFormat($familyObj)
  Function : Performs format QC steps on the SEED, via the object.
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on error, 0 on passing checks.

=cut

sub checkSEEDFormat {
  my ($familyObj) = @_;

  #
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  my $error = 0;

  #Check that the SEED is in stockholm format
  if ( $familyObj->SEED->format ne 'Stockholm' ) {
    warn "FATAL: SEED is not in Stockholm format, "
      . $familyObj->SEED->format . "\n";
    $error++;
  }

  #Check that there are no all gap columns
  if ( $familyObj->SEED->any_allgap_columns ) {
    warn "FATAL: SEED has all gap columns";
    $error++;
  }

  #Check that there are more than 2 sequences in the SEED alignment
  if ( $familyObj->SEED->nseq < 2 ) {
    warn "FATAL: SEED has less than 2 sequences";
    $error++;
  }

  #Check that the SEED has a RF annotation line.
  if ( !$familyObj->SEED->has_rf ) {
    warn "FATAL: SEED does not have an RF line\n";
    $error++;
  }

  #Check that the SEED has a SS_cons annotation line.
  if ( !$familyObj->SEED->has_ss_cons ) {
    warn "FATAL: SEED does not have an SS_cons line\n";
    $error++;
  }

  #If family is a lncRNA, ensure it does not have any secondary
  #structure in the SS line.
  if( defined($familyObj->DESC->TP) and
      $familyObj->DESC->TP eq 'Gene; lncRNA;' ){
      if(!($familyObj->SEED->get_ss_cons =~ /^(\.|\:)*$/)){
        warn "Found family type lncRNA (TP line in DESC), but the seed contains secondary structure.\n";
        $error++;
      }

  }

  return $error;
}

#------------------------------------------------------------------------------

=head2 checkCMFormat

  Title    : checkCMFormat
  Incept   : finnr, Jul 24, 2013 2:36:13 PM
  Usage    : Bio::Rfam::QC::checkCMFormat($familyObj)
  Function : Performs format QC steps on the CM, via the object.
           : Although largely done via the FamilyIO, that just parses fields and
           : does not perform integrity checks. This checks that the number of
           : SEED sequences and CM are consistent and that the number of sequences
           : in the CM and internal HMM agree.
           : Also checks that the secondary structure of the CM matches that of the
           : SEED.
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on error, 0 on passing checks.

=cut

sub checkCMFormat {
  my ($familyObj, $config) = @_;

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }
  my $error = 0;

  #Check that the CM and internal HMM agree.
  if ( $familyObj->CM->cmHeader->{nSeq} != $familyObj->CM->hmmHeader->{nSeq} ) {
    $error = 1;
    print STDERR
"Somehow the number of sequences in the CM does not agree with its own internal HMM\n";
    return $error;
  }

  # Cross reference the number of SEED sequences with the number in the CM.
  if ( $familyObj->CM->cmHeader->{nSeq} != $familyObj->SEED->nseq ) {
    $error = 1;
    print STDERR
"The number of sequences in the CM does not agree with the number in the SEED.\n";
    return $error;
  }

  # Make sure the checksums match between the SEED and the CM
  if($familyObj->CM->cmHeader->{cksum} != $familyObj->SEED->checksum) {
    $error = 1;
    # checksums don't match, SEED may not be in digital mode
    if(! $familyObj->SEED->is_digitized) {
      printf STDERR ("Checksum mismatch between SEED and CM, possibly because SEED was read in text mode, inspect Bio::Rfam::Family object declaration.\n");
    }
    else {
      printf STDERR ("Checksum mismatch between SEED and CM, CM was not built from SEED.\n");
    }
    return $error;
  }

  # Make sure the CLEN in the CM is the same as the nongap RF length in the SEED
  # also make sure that secondary structure in CM matches that in the SEED
  # get the SS_cons from the CM using cmemit -c | cmalign
  my $ss_cons_file = "$$.ss_cons";
  my $cmemitPath  = $config->infernalPath . "cmemit";
  my $cmalignPath = $config->infernalPath . "cmalign";
  my $cmPath = $familyObj->CM->path;
  my $line;
  my $cmd = "$cmemitPath -c $cmPath | $cmalignPath --outformat pfam $cmPath - | grep SS\_cons > $$.ss_cons";
  eval{
    Bio::Rfam::Utils::run_local_command("$cmd");
  };
  if($@) {
    foreach $line ($@) {
      warn $line . "\n";
    }
    $error = 1;
    return $error;
  }

  my $cm_ss_cons = undef;
  if(open(IN, $ss_cons_file)) {
    $line = <IN>;
    chomp $line;
    if($line =~ /^#=GC\s+SS_cons\s+(\S+)/) {
      $cm_ss_cons = $1;
      # remove any gaps, this is rare but gaps can occur if cmalign thinks a consensus position
      # should be inserted followed by a nearby deletion (e.g. RF00023 and RF03057 for Rfam
      # 15.0 with infernal 1.1.5)
      $cm_ss_cons =~ s/\.//g;
    }
    else {
      warn "Failed to read SS_cons from alignment created with command $cmd\n";
      $error = 1;
      return $error;
    }
    close(IN);
    unlink $ss_cons_file;
  }
  else {
    warn "Failed to create alignment with command $cmd\n";
    $error = 1;
    return $error;
  }
  
  if(! $familyObj->SEED->has_rf) {
    printf STDERR "FATAL: SEED does not have an RF line\n";
    $error = 1;
    return $error;
  }
  my $rf      = $familyObj->SEED->get_rf;
  my $ss_cons = $familyObj->SEED->get_ss_cons;
  my @rf_A      = split("", $rf);
  my @ss_cons_A = split("", $ss_cons);
  my $gapless_rf      = "";
  my $gapless_ss_cons = "";
  for(my $i = 0; $i < scalar(@rf_A); $i++) {
    if($rf_A[$i] ne ".") {
      $gapless_rf      .= $rf_A[$i];
      $gapless_ss_cons .= $ss_cons_A[$i];
    }
  }

  # the following should be equal:
  # - length of $gapless_rf
  # - length of $gapless_ss_cons
  # - CM's clen
  # - length of $cm_ss_cons
  if(length($gapless_rf) != $familyObj->CM->cmHeader->{clen}) {
    printf STDERR ("FATAL: CLEN in CM does not match nongap RF length in SEED.\n");
    $error = 1;
    return $error;
  }
  if(length($gapless_ss_cons) != length($cm_ss_cons)) { # this shouldn't happen since cmemit -c length should be clen
    printf STDERR ("FATAL: length of SS_cons from SEED does not match CM structure length.\n");
    $error = 1;
    return $error;
  }

  my @seed_ss_cons_A = split("", $gapless_ss_cons);
  my @cm_ss_cons_A   = split("", $cm_ss_cons);
  my $identical = 1;  # set to 0 if not identical in basepaired positions
  my $compatible = 1; # set to 0 if not compatible (different base pairs)
  for(my $i = 0; $i < scalar(@seed_ss_cons_A); $i++) {
    my $seed_left  = ($seed_ss_cons_A[$i] =~ m/[\<\(\{\[]/) ? 1 : 0;
    my $seed_right = ($seed_ss_cons_A[$i] =~ m/[\>\)\}\]]/) ? 1 : 0;
    my $seed_ss    = ($seed_left || $seed_right) ? 0 : 1;
    my $cm_left    = ($cm_ss_cons_A[$i] =~ m/[\<\(\{\[]/) ? 1 : 0;
    my $cm_right   = ($cm_ss_cons_A[$i] =~ m/[\>\)\}\]]/) ? 1 : 0;
    my $cm_ss      = ($cm_left || $cm_right) ? 0 : 1;
    #print STDERR ("$i $seed_ss_cons_A[$i] $cm_ss_cons_A[$i] $seed_left $seed_right $seed_ss $cm_left $cm_right $cm_ss\n");
    if(($seed_left  && $cm_left)  || 
       ($seed_right && $cm_right) || 
       ($seed_ss    && $cm_ss)) {
      if($seed_left || $seed_right) { # a left or right half of a basepair
        if($seed_ss_cons_A[$i] ne $cm_ss_cons_A[$i]) {
          print STDERR ("$i $seed_ss_cons_A[$i] $cm_ss_cons_A[$i] $seed_left $seed_right $seed_ss $cm_left $cm_right $cm_ss\n");
          $identical = 0;
        }
        else {
          #print STDERR ("$i $seed_ss_cons_A[$i] eq $cm_ss_cons_A[$i]\n");
        }
      }
    }
    else { # CM and SEED don't match left/right/ss
      printf STDERR ("RF nongap position %d: SEED SS_cons character (%s) doesn't match CM SS_cons character (%s)\n", ($i+1), $seed_ss_cons_A[$i], $cm_ss_cons_A[$i]);
      $compatible = 0;
      $identical  = 0;
    }        
  }

  if(! $compatible) {
    printf STDERR ("FATAL: SS_cons implied by CM differs from that in SEED.\n");
    $error = 1;
    return $error;
  }
  if(! $identical) { 
    printf STDERR ("FATAL: SS_cons format in CM differs from that in SEED. Run rewrite_seed_with_rf.pl jiffy script to update SEED.\n");
    $error = 1;
    return $error;
  }
  return $error;
}

#------------------------------------------------------------------------------

=head2 checkDESCFormat

  Title    : checkDESCFormat
  Incept   : finnr, Jul 24, 2013 2:36:13 PM
  Usage    : Bio::Rfam::QC::checkDESCFormat($familyObj)
  Function : Performs format QC steps on the DESC, via the object.
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on error, 0 on passing checks.

=cut

sub checkDESCFormat {
  my ($familyObj) = @_;

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  my $error = 0;

  #Get the required fields and check that they are present.
  #Also check that SO and GO terms are set in the xrefs.
  $error = checkRequiredFields($familyObj);
  return $error if ($error);

  #The DESC can have SQ tags, these should not be standard
  if ( $familyObj->DESC->SQ ) {
    warn "FATAL: your DESC file has SQ tags, please remove.\n";
    $error++;
  }
  return $error if ($error);

  #Now check the type field.
  $error = checkTPField($familyObj);

  return $error;
}

#------------------------------------------------------------------------------

=head2 checkScoresFormat

  Title    : checkScoresFormat
  Incept   : finnr, Jul 24, 2013 2:36:13 PM
  Usage    : Bio::Rfam::QC::checkScoresFormat($familyObj)
  Function : Performs format QC steps on the scores, via the object.
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on error, 0 on passing checks.

=cut

sub checkScoresFormat {
  my ( $familyObj ) = @_;

  my $threshold = $familyObj->DESC->CUTGA;
  #Should check that no regions exceed threshold?

  #Now we have to ensure that all sequences are present and correct w.r.t to the
  #GA threshold. Run over the TBLOUT file and get all data from that raw,
  #infernal output.

  my $count = 0;
  my(@tbloutMatches, $nres);
  open(T, '<', $familyObj->TBLOUT->fileLocation)
      or die "Failed to open TBLOUT file for reading.[$!]\n";

  while(<T>){
    next if(/^#/); #Ignore lines starting with #
    my @line = split(/\s+/); #split on whitespace
    if($line[14] >= $threshold){ #If above threshold (bit score)
      $count++;
      #array of nse
      push(@tbloutMatches, $line[0].'/'.$line[7].'-'.$line[8]);
      #Get the total number of residues
      if($line[7] <= $line[8]){
        $nres += (($line[8] - $line[7]) + 1);
      }else{
        #Reverse strand
        $nres += (($line[7] - $line[8]) + 1);
      }
    }
  }
  close(T);

  my $error = 0;
  if($count != $familyObj->SCORES->numRegions){
    warn "The number of regions scoring above threshold in the TBLOUT file and SCORES differs.\n";
    $error = 1;
  }
  if(scalar( @{$familyObj->SCORES->regions}) != $familyObj->SCORES->numRegions){
    warn "The number of regions in the SCORES [".scalar(@{$familyObj->SCORES->regions}).
         "] array differs from the count [". ($familyObj->SCORES->numRegions) ."].\n";
    $error = 1;
  }

  $familyObj->SCORES->determineNres if(!$familyObj->SCORES->nres);
  if($nres != $familyObj->SCORES->nres){
    warn "The number of residues in the SCORES [".$familyObj->SCORES->nres.
          "] and TBLOUT [$nres] do not match.\n";
  }

  return($error) if($error);

  #Now a deep comparison, if everything looks okay. Do this by making a string
  #out of all of the NSE from the TBLOUT and SCORES - then compare.
  my $scoresMatches = join(" ",
                           sort { $a cmp $b }
                           map { $_->[0]   }
                           @{$familyObj->SCORES->regions});

  my $tbloutMatches = join(" ", sort { $a cmp $b } @tbloutMatches);

  if($scoresMatches ne $tbloutMatches){
    warn "The matches between SCORES and TBLOUT differ!\n";
    $error = 1;
  }
  return($error);
}

#------------------------------------------------------------------------------

=head2 checkRequiredFields

  Title    : checkRequiredFields
  Incept   : finnr, Jul 24, 2013 2:47:01 PM
  Usage    : Bio::Rfam::QC::checkRequiredFields($familyObj, $config)
  Function : Ensures that all of the required fields and database cross references
           : are present in the DESC file.
  Args     : A Bio::Rfam::Family object, a Bio::Rfam::Config object (optional).
  Returns  :  1 on error, 0 on passing checks.

=cut

sub checkRequiredFields {
  my ( $familyObj, $config ) = @_;

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  if ( !$config ) {
    $config = Bio::Rfam::Config->new;
  }

  if ( !$config->isa('Bio::Rfam::Config') ) {
    die "Expeceted an Bio::Rfam::Config object\n";
  }
  my $error = 0;
  foreach my $f ( @{ $familyObj->DESC->requiredFields } ) {
    if ( !defined( $familyObj->DESC->$f ) ) {
      warn "Required DESC field $f not defined.\n";
      $error++;
    }
    elsif ( ref( $familyObj->DESC->$f ) eq 'ARRAY' ) {
      if ( !scalar( @{ $familyObj->DESC->$f } ) ) {
        warn "Required DESC field $f not defined [ARRAY].\n";
        $error++;
      }
    }
  }

  #Make sure none of the default values set in writeEmptyDESC still exist
  foreach my $key ( keys %{ $familyObj->DESC->defaultButIllegalFields } ) {
    if ( !defined( $familyObj->DESC->$key ) ) { #make sure it's defined first
      warn "Required DESC field $key not defined.\n";
      $error++;
    }
    elsif( $familyObj->DESC->$key eq $familyObj->DESC->defaultButIllegalFields->{$key} ) {
      warn "DESC field $key illegal value (appears unchanged from an 'rfsearch.pl -nodesc' call).\n";
      $error++;
    }

    # a special case: make sure that --nohmmonly appears in the SM (search method)
    # so we can't check-in a family run with the -hmmonly option in rfsearch, which
    # is meant to be a option used for debugging only, not for production.
    if(defined $familyObj->DESC->SM) {
      if($familyObj->DESC->SM !~ m/\-\-nohmmonly/) {
        warn "DESC SM field does not contain --nohmmonly.\n";
        $error++;
      }
    }
  }

  #There are also two special cases......
  my ( $SOseen, $GOseen, $SOsuggestions, $GOsuggestions );

  $SOsuggestions = $config->SOsuggestions;
  $GOsuggestions = $config->GOsuggestions;
  if ( $familyObj->DESC->DBREFS ) {
    foreach my $xref ( @{ $familyObj->DESC->DBREFS } ) {
      if ( $xref->{db_id} eq 'SO' ) {
        $SOseen++;
      }
      elsif ( $xref->{db_id} eq 'GO' ) {
        $GOseen++;
      }
    }
  }
  if ( !$SOseen ) {
    warn
"\nFATAL: There are no SO mappings for this family\nLook up:\n$SOsuggestions\n\n";
    $error = 1;
  }
  if ( !$GOseen ) {
    warn
"\nNo GO mappings for this family-have you tried to add any?\nLook up:\n$GOsuggestions\n\n";
  }

  return ($error);
}

#------------------------------------------------------------------------------

=head2 checkTPField

  Title    : checkTPField
  Incept   : finnr, Jul 24, 2013 2:22:18 PM
  Usage    : Bio::Rfam::QC::checkTPField( $familyObj, $config)
  Function : Takes the DESC file and checks that the TP field conforms to the
           : the expected data structure that is stored in the config.
  Args     : A Bio::Rfam::Family object, a Bio::Rfam::Config object (optional)
  Returns  : 0 if everything is okay, 1 if there is an error detected.

=cut

sub checkTPField {
  my ( $familyObj, $config ) = @_;

  if ( !$config ) {
    $config = Bio::Rfam::Config->new;
  }

  if ( !$config->isa('Bio::Rfam::Config') ) {
    die "Expeceted an Bio::Rfam::Config object\n";
  }

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  my $error = 0;

  #There should always be a TP line when the DESC has been written.
  if ( !$familyObj->DESC->TP ) {
    warn "The DESC file has no TP line.\n";
    $error = 1;
    return $error;
  }

  #Process the DESC line, semi-colon separated list.
  my @TPline = split( /\; /, $familyObj->DESC->TP );
  $TPline[-1] =~ s/\;//;

  #Get the predefined, okay data structure
  my $tpHashRef = $config->descTypes;
  #For each element/TP we find, descend down the hash.
  for ( my $i = 0 ; $i < scalar(@TPline) ; $i++ ) {
	if ( $tpHashRef->{ $TPline[$i] } ) {
      $tpHashRef = $tpHashRef->{ $TPline[$i] };
    }
    else {
      warn "\nFATAL: Invalid TP line: "
        . $familyObj->DESC->TP
        . ", because $TPline[$i] not found in hash\n";
      #$i = scalar(@TPline);    #Break out as nothing will work
      $error = 1;
    }
  }
  return ($error);
}

#------------------------------------------------------------------------------
=head2 checkFixedFields

  Title    : checkFixedFields
  Incept   : finnr, Aug 5, 2013 10:51:59 AM
  Usage    : Bio::Rfam::QC::checkFixedFields($newFamily, $oldFamily);
  Function : Checks that nobody has changes the ID, AC, PI lines
  Args     : Bio::Rfam::Family object for old and new family.
  Returns  : 1 on error, 0 on success.

=cut

sub checkFixedFields {
  my ($newFamilyObj, $oldFamilyObj) = @_;

  my $error = 0;

  if ( !$newFamilyObj or !$newFamilyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object (new)\n";
  }

  if ( !$oldFamilyObj or !$oldFamilyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object (old)\n";
  }

  if($newFamilyObj->DESC->AC ne $oldFamilyObj->DESC->AC){
    warn "Your accession (AC) differs between the old and new version of the family.\n";
    $error = 1;
  }

  if($newFamilyObj->DESC->ID ne $oldFamilyObj->DESC->ID){
    warn "Your identifier (ID) differs between the old and new version of the family.\n";
    $error = 1;
  }

  if( defined( $newFamilyObj->DESC->PI )){
    if($newFamilyObj->DESC->PI ne $oldFamilyObj->DESC->PI){
      warn "Your pervious identifers (PI) differs between the old and new version of the family.\n";
      $error = 1;
    }
  }

  return $error;
}


#------------------------------------------------------------------------------
=head2 checkClanFixedFields

  Title    : checkClanFixedFields
  Incept   : finnr, Aug 5, 2013 10:51:59 AM
  Usage    : Bio::Rfam::QC::checkClanFixedFields($newClan, $oldClan);
  Function : Checks that nobody has changes the ID, AC, PI and MB lines
  Args     : Bio::Rfam::Clan object for old and new clan.
  Returns  : 1 on error, 0 on success.

=cut

sub checkClanFixedFields {
  my ($newClanObj, $oldClanObj) = @_;

  my $error = 0;

  if ( !$newClanObj or !$newClanObj->isa('Bio::Rfam::Clan') ) {
    die "Did not get passed in a Bio::Rfam::Clan object (new)\n";
  }

  if ( !$oldClanObj or !$oldClanObj->isa('Bio::Rfam::Clan') ) {
    die "Did not get passed in a Bio::Rfam::Clan object (old)\n";
  }

  if($newClanObj->DESC->AC ne $oldClanObj->DESC->AC){
    warn "Your accession (AC) differs between the old and new version of the clan.\n";
    $error = 1;
  }

  if($newClanObj->DESC->ID ne $oldClanObj->DESC->ID){
    warn "Your identifier (ID) differs between the old and new version of the clan.\n";
    $error = 1;
  }

  if( defined( $newClanObj->DESC->PI )){
    if($newClanObj->DESC->PI ne $oldClanObj->DESC->PI){
      warn "Your pervious identifers (PI) differs between the old and new version of the Clan. This should be performed by CL move.\n";
      $error = 1;
    }
  }

  #Now compare the membership of the old and new to check that nobody has change it here.
  my $old_members = defined $oldClanObj->DESC->MEMB ? $oldClanObj->DESC->MEMB : [];
  my $new_members = defined $newClanObj->DESC->MEMB ? $newClanObj->DESC->MEMB : [];

  my %count;
  foreach my $m ( @{$old_members}, @{$new_members} ) {
    $count{$m}++;
  }

  my ( @isect, @diff );
  foreach my $m ( keys %count ) {
    push @{ $count{$m} == 2 ? \@isect : \@diff }, $m;
  }

  $error = 0;
  if ( scalar(@diff) ) {
    $error = 0;
    warn "Detected the following differences between the memberships\n";
    my %newMem = map { $_ => 1 } @{$new_members};
    foreach my $d (@diff) {
      print STDERR defined( $newMem{$d} )
        ? "$d is not in the old membership\n"
        : "$d is not in the new membership\n";
    }
  }

  return $error;
}

#------------------------------------------------------------------------------
=head2 checkNonFreeText

  Title    : checkNonFreeText
  Incept   : finnr, Aug 5, 2013 11:03:29 AM
  Usage    : Bio::Rfam::QC::checkNonFreeText($newFamilyObj, $oldFamilyObj)
  Function : Checks that certain fields in the DESC have not changed between
           : different the checked-in and modified versions
  Args     : Bio::Rfam::Family object for both the old and updated families.
  Returns  : 1 on error, 0 on success.

=cut

sub checkNonFreeText {
  my($upFamilyObj, $oldFamilyObj) = @_;
  #Check that none of the lines that should not be touch are not

  #Need to check that we have correct objects.
  if ( !$upFamilyObj or !$upFamilyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  if ( !$oldFamilyObj or !$oldFamilyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  #The list of fields  that cannot be altered are:
  # NC, TC, GA,
  my $error = 0;
  foreach my $tag (qw(NC TC GA)) {
    my $ftag = 'CUT'.$tag;
    unless ( $oldFamilyObj->DESC->$ftag eq $upFamilyObj->DESC->$ftag )
    {
      warn
"There is a differnce in your $tag lines between what is in the SVN repository and this local copy.".
        " You can not do this when only commint a DESC file!\n";
      $error = 1;
    }
  }

  #ID, AC, PI, SE, SS, BM, SM
  foreach my $tag (qw(ID AC PI SE BM SM CB CL)) {
    next unless(defined($oldFamilyObj->DESC->$tag));
    unless ( $oldFamilyObj->DESC->$tag eq $upFamilyObj->DESC->$tag ) {
      warn
"You are only checking in the DESC file, yet the $tag line has change. You can not do this!\n";
      $error = 1;
    }
  }

  return ($error);
}
#------------------------------------------------------------------------------

=head2 compareSeedAndSeedScores

  Title    : compareSeedAndSeedScores
  Incept   : finnr, Jul 24, 2013 1:03:53 PM
             EPN, Thu May  9 17:05:49 2019
  Usage    : Bio::Rfam::QC::compareSeedAndSeedScores($familyObj);
  Function : Takes a family object and compares the SEED to the SEEDSCORES file to
           : ensure that all sequences are found. It does not look at co-ordinates
           : just sequence accessions.
  Args     : A Bio::Rfam::Family object
  Returns  : 0 when all sequences found, otherwise 1

=cut

sub compareSeedAndSeedScores {
  my ($familyObj) = @_;

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  if (!$familyObj->SEEDSCORES) {
    die "ERROR in compareSeedAndSeedScores() no SEEDSCORES object exists";
  }

  #Hash of SEED sequence accessions
  my %seed;
  for ( my $i = 0 ; $i < $familyObj->SEED->nseq ; $i++ ) {
    my $s = $familyObj->SEED->get_sqname($i);
    $seed{$s} = 1;
  }

  #Now loop over the scores files and delete keys when we find accessions
  #present, with the hope we have an empty seed hash
  foreach my $r ( @{ $familyObj->SEEDSCORES->regions } ) {
    if ( exists( $seed{ $r->[3] } ) ) {
      delete( $seed{ $r->[3] } );
    }
    last if ( !%seed );    #If we empty, break the loop
  }

  #Report as necessary.
  if (%seed) {
    foreach my $seq ( keys %seed ) {
      warn "SERIOUS ERROR: $seq in SEED in not in SCORES list!\n";
    }
    return 1;
  }
  else {
    return 0;
  }
}

#------------------------------------------------------------------------------

=head2 compareOldAndNew

  Title    : compareOldAndNew
  Incept   : finnr, Jul 24, 2013 1:07:21 PM
  Usage    : Bio::Rfam::QC::compareOldAndNew($oldFamily, $updatedFamily, $path)
  Function : Compares the SCORES files from the old and update family to identify
           : new and missing sequences. If a path is supplied, it will write files
           : containing the found/missing sequence accessions
  Args     : Two family objects, first the old, second the updated family.  Third
           : argument is an optional path of the directory where missng and found
           : files should be written
  Returns  : array references to the arrays containing the found or missing
           : sequence accessions.

=cut

sub compareOldAndNew {
  my ( $oldFamObj, $newFamObj, $path ) = @_;

  if ( !$oldFamObj or !$oldFamObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object as first argument.\n";
  }
  if ( !$newFamObj or !$newFamObj->isa('Bio::Rfam::Family') ) {
    die
      "Did not get passed in a Bio::Rfam::Family object as second argument.\n";
  }
  if ($path) {
    if ( !-d $path ) {
      die "You passed in a path, but is does not appear to be a directory.\n";
    }
  }

  #Find the things that are in the old, but not the new. Generate a hash of the
  #new things the pull out the unique sequence accessions (fourth element)
  my %e = map { $_->[3] => undef } @{ $newFamObj->SCORES->regions };
  my @missing = keys %{
    {
      map { $_->[3] => 1 }
      sort { $a->[3] cmp $b->[3] }
      grep( !exists( $e{ $_->[3] } ), @{ $oldFamObj->SCORES->regions } )
    }
  };

  %e = map { $_->[3] => undef } @{ $oldFamObj->SCORES->regions };
  my @found = keys %{
    {
      map { $_->[3] => 1 }
      sort { $a->[3] cmp $b->[3] }
      grep( !exists( $e{ $_->[3] } ), @{ $newFamObj->SCORES->regions } )
    }
  };

  if ( $path and -d $path ) {

    #Remove the files if they are there.
    unlink( $path . '/missing' ) if ( -e ( $path . '/missing' ) );
    unlink( $path . '/found' )   if ( -e ( $path . '/found' ) );

    if (@missing) {
      open( M, '>', $path . '/missing' )
        or die "Failed to open missing ($path/missing) file:[$!]\n";
      foreach (@missing) {
        print M "$_ not found\n";
      }
      close(M);
    }
    if (@found) {
      open( M, '>', $path . '/found' )
        or die "Failed to open found ($path/found) file:[$!]\n";
      foreach (@found) {
        print M "$_ found\n";
      }
      close(M);
    }
  }

  if ( !scalar(@found) and !scalar(@missing) ) {
    print STDERR "No change in SEED and ALIGN members.\n";
  }
  else {
    print STDERR "Lost " . scalar(@missing) . ". Found " . scalar(@found);
    if ($path) {
      print STDERR "See the missing and found files for details";
    }
    print STDERR "\n";
  }

  return ( \@found, \@missing );
}

#------------------------------------------------------------------------------

=head2 checkTimestamps

  Title    : checkTimestamps
  Incept   : finnr, Jul 24, 2013 1:31:37 PM
  Usage    : Bio::Rfam::QC::checkTimestamps($famDir, $config)
  Function : Checks that all mandatory files are present in the directory and
           : that have been built in the same way.
  Args     : A path to family directory, a Bio::Rfam::Config object (optional).
  Returns  : 0 on passing, 1 on issue.

=cut

sub checkTimestamps {
  my ( $fam, $config ) = @_;
  if ( !$fam or !-d $fam ) {
    die "Did not get passed in a path to a directory\n";
  }

  if ( !$config ) {
    $config = Bio::Rfam::Config->new;
  }
  if ( !$config->isa('Bio::Rfam::Config') ) {
    die "Expeceted an Bio::Rfam::Config object\n";
  }

  my $error = 0;

  #First check all files are present.
  foreach my $f ( @{ $config->mandatoryFiles } ) {
    if ( !-e "$fam/$f" ) {
      warn "$f is missing from $fam\n";
      $error++;
    }
  }
  return $error if ($error);

  #Now check the timestamps.
	if(Bio::Rfam::Utils::youngerThan("$fam/SEED", "$fam/CM")) {
    warn
        "\nFATAL ERROR: $fam: Your SEED [$fam/SEED] is younger than your CM file [$fam/CM].\n";
    $error = 1;
  }
  if(Bio::Rfam::Utils::youngerThan("$fam/CM", "$fam/TBLOUT")) {
    warn
"\nFATAL ERROR: $fam: Your CM [$fam/CM] is younger than your TBLOUT file [$fam/TBLOUT].\n";
    $error = 1;
  }
  if(Bio::Rfam::Utils::youngerThan("$fam/TBLOUT", "$fam/SCORES")) {
    warn
"\nFATAL ERROR: $fam: Your TBLOUT [$fam/TBLOUT] is younger than your SCORES [$fam/scores].\n";
    $error = 1;
  }
  return $error;
}

#------------------------------------------------------------------------------

=head2 checkSpell

  Title    : checkSpell
  Incept   : finnr, Jul 17, 2013 1:29:27 PM
  Usage    : Bio::Rfam::QC::checkSpell($dir, $dictPath, $familyIOObj)
  Function : This takes the DESC file and grabs out the free text fields, removes
           : our tags and writes a temporary file. It then runs ispell over the
           : contents of the file, interactively with the users. Finally, the
           : data is written back into the file.
  Args     : Path containting the family, Path to dictionary file used by ispell,
           : a familyIO object (optional)
  Returns  : An error flag if encountered.

=cut

sub checkSpell {
  my ( $fam, $dictionary, $familyIO ) = @_;

  my $error = 0;
  #
  unless ($familyIO) {
    $familyIO = Bio::Rfam::FamilyIO->new;
  }

  if ( !$familyIO->isa('Bio::Rfam::FamilyIO') ) {
    die "Did not get passed in a Bio::Rfam::FamilyIO object\n";
  }

  #Make sure that the DESC file is vaild to start off with
  eval { $familyIO->parseDESC("$fam/DESC"); };
  if ($@) {
    print STDERR $@;
    $error = 1;
    return $error;
  }

  my (%line);
  my ($lineNo) = 0;

  open( DESC, "$fam/DESC" )
    || die "Can't open DESC file for family $fam:[$!]\n";

  while (<DESC>) {

    # If a free text line add to %lines
    if (/^RT   (\.*)$/) {
      $line{$lineNo} = $1;
    }
    elsif (/^CC   (.*)$/) {
      $line{$lineNo} = $1;
    }
    elsif (/^RC   (.*)$/) {
      $line{$lineNo} = $1;
    }
    elsif (/^DC   (.*)$/) {
      $line{$lineNo} = $1;
    }
    elsif (/^DE   (.*)$/) {
      $line{$lineNo} = $1;
    }
    $lineNo++;
  }
  close(DESC);

  my @lineNos = sort { $a <=> $b; } keys %line;

  my ( $bit, @line_number_array );

  #Now make temporary file and write free text
  my ( $tfh, $tfilename ) = tempfile();

  foreach (@lineNos) {

    #Print all free text lines.
    print $tfh $line{$_}, "\n";
  }
  close $tfh;

  # Start ispell session on file - replacing ispell with aspell
  # system("aspell -W 0 -w 0123456789 -p$dictionary -c $tfilename");
  # Start aspell
  system("aspell -c $tfilename");

  # Now need to put changes back into DESC file
  my ( %editedline, $line_number );
  open( TMP, '<', $tfilename ) || die "Can't open temp file $tfilename:[$!]\n";

  while (<TMP>) {
    if (/^(.*)$/) {
      $line_number = shift @lineNos;
      $editedline{"$line_number"} = $1;
    }
    else {
      die "unrecognised line [$_]\n Serious error!\n";
    }
  }
  close(TMP);

  # Write out new DESC file
  open( TEMPDESC, ">$fam/DESC.$$" )
    || die "Can't write to temp DESC file for family $fam\n";

  open( DESC, "$fam/DESC" )
    || die "Can't open DESC file for fam $fam\n";

  my ($prefix);
  $lineNo = 0;

  while (<DESC>) {
    if ( $editedline{$lineNo} ) {

      # Find if DE, RT or CC line
      if ( $_ =~ /^(\S+)/ ) {
        $prefix = $1;
      }
      else {
        die "unrecognised line [$_]\n";
      }

      # Write out line
      print TEMPDESC "$prefix   $editedline{$lineNo}\n";
    }
    else {
      print TEMPDESC;
    }
    $lineNo++;
  }
  close(DESC);
  close(TEMPDESC);

  # Move DESC across
  copy( "$fam/DESC.$$", "$fam/DESC" );

  # Clean up
  unlink("$fam/DESC.$$");

  #Now make sure that I have not screwed anyting up!  It is possible that the
  #line lengths could overflow.
  $familyIO->parseDESC("$fam/DESC");
  return ($error);
}

#------------------------------------------------------------------------------

=head2 ssStats

  Title    : ssStats
  Incept   : EPN, Thu Jul 18 15:34:22 2013
  Usage    : Bio::Rfam::QC::ssStats($familyObj, $outputDir)
  Function : Calculates and outputs per-family, per-sequence and per-basepair
           : statistics to 'ss-stats-perfamily', 'ss-stats-persequence' and
           : 'ss-stats-perbasepair' files.
  Args     : A Family object, output directory (optional, default '.').
  Returns  : 1 on error, 0 if no errors were found.

=cut

sub ssStats {
  my ( $famObj, $outdir ) = @_;

  if ( !$famObj or !$famObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  $outdir = '.' if ( !$outdir );
  my $seed = $famObj->SEED;
  eval {
    if ( $seed->any_allgap_columns ) { die "ERROR, SEED has all gap columns"; }
    if ( $seed->nseq < 2 ) { die "ERROR, SEED has less than 2 sequences"; }
    $seed->set_name( $famObj->DESC->ID );
    $seed->set_accession( $famObj->DESC->AC );
    $seed->weight_GSC();
    $seed->rfam_qc_stats(
      "$outdir/ss-stats-perfamily",
      "$outdir/ss-stats-persequence",
      "$outdir/ss-stats-perbasepair"
    );
  };
  if ($@) {
    warn "FATAL: experienced an error generating SS stats.\n $@\n";
    return 1;    #There is an error;
  }
  else {
    return 0;    #No error;
  }
}

#------------------------------------------------------------------------------
=head2 checkSEEDSeqs

  Title    : checkSEEDSeqs
  Incept   : EPN, Fri Mar  1 18:04:58 2019
  Usage    : Bio::Rfam::QC::checkSEEDSeqs($familyObj, $seqDBObj, $be_verbose)
  Function : Checks that all SEED sequencs are valid based on md5
           : To be valid, each SEED sequence must exist and
           : (be identical to) the same (sub)sequence in one
           : or more of:
           : - rfamseq
           : - GenBank
           : - RNAcentral
  Args     : Bio::Rfam::Family object, Bio::Rfam::SeqDB object
           : $be_verbose: if '1' print info to stdout, if '0' print warnings only if nec.
  Returns  : 1 on error, 0 on successully passing check

=cut

sub checkSEEDSeqs {
  my ( $familyObj, $seqDBObj, $be_verbose ) = @_;

  #Check we have the correct family object.
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  if(! defined $be_verbose) { $be_verbose = 0; }

  return checkSEEDSeqs_helper($familyObj->SEED, $seqDBObj, $be_verbose);
}

#------------------------------------------------------------------------------
=head2 checkSEEDSeqs_helper

  Title    : checkSEEDSeqs_helper
  Incept   : EPN, Thu Sep 19 16:09:22 2019
  Usage    : Bio::Rfam::QC::checkSEEDSeqs($familyObj, $seqDBObj)
  Function : Does actual work for checkSEEDSeqs()
           : Checks that all SEED sequencs are valid based on md5
           : To be valid, each SEED sequence must exist and
           : (be identical to) the same (sub)sequence in one
           : or more of:
           : - rfamseq
           : - GenBank
           : - RNAcentral
  Args     : Bio::Easel::MSA object, Bio::Rfam::Family object, Bio::Rfam::SeqDB object
           : $be_verbose: if '1' print info to stdout, if '0' print warnings only if nec.
  Returns  : 1 on error, 0 on successully passing check

=cut
sub checkSEEDSeqs_helper {
  my ( $seed, $seqDBObj, $be_verbose ) = @_;

  # stats collected and only output if $be_verbose is 1
  my $nrfm_pass = 0;
  my $ngbk_pass = 0;
  my $nrnc_pass = 0;
  my $nfail = 0;

  if(! defined $be_verbose) { $be_verbose = 0; }

  my $nseq  = $seed->nseq;
  my @fail_A = ();
  # look-up each SEED sequence
  for ( my $i = 0 ; $i < $nseq; $i++ ) {
    my $nse  = $seed->get_sqname($i);
    my ($is_nse, $name, undef, undef, undef) = Bio::Rfam::Utils::nse_breakdown($nse);

    my $seed_msa_seq = $seed->get_sqstring_unaligned($i);
    my $seed_md5 = Bio::Rfam::Utils::md5_of_sequence_string($seed_msa_seq);

    # lookup in rfamseq
    my ($rfamseq_has_source_seq, $rfamseq_has_exact_seq, $rfamseq_md5) = Bio::Rfam::Utils::rfamseq_nse_lookup_and_md5($seqDBObj, $nse);

    # lookup in GenBank, retry up to 200 times if fetch fails, wait 3 seconds between tries
    my ($genbank_has_source_seq, $genbank_has_exact_seq, $genbank_md5) = Bio::Rfam::Utils::genbank_nse_lookup_and_md5($nse, 200, 3);

    # lookup in RNAcentral
    # first using md5 only and *not* the seq id
    my ($rnacentral_has_seq_by_md5, $rnacentral_seq_md5, undef, undef) = Bio::Rfam::Utils::rnacentral_md5_lookup($seed_md5);
    # second using name/start-end, this will handle if sequence is an RNAcentral subsequence
    my ($rnacentral_has_seq_by_id,  $rnacentral_subseq_md5) = Bio::Rfam::Utils::rnacentral_subseq_lookup($nse);
    #

    my $pass_rfm = 0;
    my $pass_gbk = 0;
    my $pass_rnc = 0;
    my $outstr   = "";     # only used if $be_verbose
    my $passfail = "PASS"; # only used if $be_verbose

    # check if it fails for any of following reasons:
    # 1) name is not in name/start-end format
    # 2) not in any of Rfamseq, GenBank, or RNAcentral
    # 3) source seq exists in Rfamseq, but not subseq (start-end)
    # 4) source seq exists in GenBank, but not subseq (start-end)
    # 5) subseq appears to exist in Rfamseq, but md5 does not match
    # 6) subseq appears to exist in GenBank, but md5 does not match
    # 7) subseq appears to exist in RNAcentral, but md5 does not match
    #    (THIS SHOULD BE IMPOSSIBLE BECAUSE WE LOOK UP IN RNACENTRAL BASED ON md5)
    # 8) subseq appears to exist in RNAcentral by md5, but it is not in URS_taxid/start-end format
    # 9) subseq appears to exist in RNAcentral by id, but md5 does not match
    if(! $is_nse) {
      # 1) name is not in valid name/start-end format
      $passfail = "FAIL";
      if($be_verbose) { $outstr .= "NOT-NAME/START-END"; }
      else            { warn "SEED sequence $nse fails validation; it is not in valid name/start-end format\n"; }
    }
    if((! $rfamseq_has_source_seq) && (! $genbank_has_source_seq) && (! $rnacentral_has_seq_by_md5) && (! $rnacentral_has_seq_by_id)) {
      # 2) not in any of Rfamseq, GenBank, or RNAcentral
      $passfail = "FAIL";
      if($be_verbose) { $outstr .= "NO-MATCHES"; }
      else            { warn "SEED sequence $nse fails validation; it exists in none of: Rfamseq, GenBank, RNAcentral\n"; }
    }
    if(($rfamseq_has_source_seq) && (! $rfamseq_has_exact_seq)) {
      # 3) source seq exists in Rfamseq, but not subseq (start-end)
      $passfail = "FAIL";
      if($be_verbose) { $outstr .= "RFM:found-seq-but-not-subseq;"; }
      else            { warn "SEED sequence $nse fails validation; its source sequence exists in Rfamseq, but specific range subsequence does not\n"; }
    }
    if(($genbank_has_source_seq) && (! $genbank_has_exact_seq)) {
      # 4) source seq exists in GenBank, but not subseq (start-end)
      $passfail = "FAIL";
      if($be_verbose) { $outstr .= "GBK:found-seq-but-not-subseq;"; }
      else            { warn "SEED sequence $nse fails validation; its source sequence exists in GenBank, but specific range subsequence does not\n"; }
    }
    if($rfamseq_has_exact_seq) {
      if($rfamseq_md5 ne $seed_md5) {
        # 5) subseq appears to exist in Rfamseq, but md5 does not match
        $passfail = "FAIL";
        if($be_verbose) { $outstr .= "RFM:md5-fail;"; }
        else            { warn "SEED sequence $nse fails validation; it appears to exist in Rfamseq, but md5 does not match\n"; }
      }
      else {
        $nrfm_pass++;
        $pass_rfm = 1;
        if($be_verbose) { $outstr .= "RFM:md5-pass;"; }
      }
    }
    if($genbank_has_exact_seq) {
      if($genbank_md5 ne $seed_md5) {
        # 6) subseq appears to exist in GenBank, but md5 does not match
        $passfail = "FAIL";
        if($be_verbose) { $outstr .= "GBK:md5-fail;"; }
        else            { warn "SEED sequence $nse fails validation; it appears to exist in GenBank, but md5 does not match\n"; }
      }
      else {
        $ngbk_pass++;
        $pass_gbk = 1;
        if($be_verbose) { $outstr .= "GBK:md5-pass;"; }
      }
    }
    if($rnacentral_has_seq_by_md5) {
      if($rnacentral_seq_md5 ne $seed_md5) {
        # 7) subseq appears to exist in RNAcentral, but md5 does not match
        #    (THIS SHOULD BE IMPOSSIBLE BECAUSE WE LOOK UP IN RNACENTRAL BASED ON md5)
        $passfail = "FAIL";
        if($be_verbose) { $outstr .= "RNC:md5-fail;"; }
        else            { warn "SEED sequence $nse fails validation; it appears to exist in RNAcentral, but md5 does not match (*check code: this should be impossible)\n"; }
      }
      else { # md5 matches (as it should since we looked it up by md5)
        # if the sequence *only* exists in RNAcentral verify that it
        # has the proper name format URS_taxid
        if((! $pass_rfm) && (! $pass_gbk)) {
          my ($is_rnacentral_taxid, undef, undef) = Bio::Rfam::Utils::rnacentral_urs_taxid_breakdown(($is_nse) ? $name : $nse);
          if($is_rnacentral_taxid != 1) {
            # 8) subseq appears to exist in RNAcentral by md5, but it is not in URS_taxid/start-end format
            $passfail = "FAIL";
            if($be_verbose) { $outstr .= "RNC:md5-id-fail;"; }
            else            { warn "SEED sequence $nse fails validation; it is only in RNAcentral, but its name is not in the expected URS_taxid format\n"; }
          }
          else {
            # sequence exists by md5 and it's in proper URS_taxid format
            $nrnc_pass++;
            $pass_rnc = 1;
            if($be_verbose) { $outstr .= "RNC:md5-pass;"; }
          }
        }
      }
    }
    elsif($rnacentral_has_seq_by_id) {
      if($rnacentral_subseq_md5 ne $seed_md5) {
      # 9) subseq appears to exist in RNAcentral by id, but md5 does not match
      $passfail = "FAIL";
      if($be_verbose) { $outstr .= "RNC:md5-subseq-fail;"; }
      else            { warn "SEED sequence $nse fails validation; it appears to exist in RNAcentral based on its id, but md5 of its subsequence does not match md5 of subsequence fetched from RNAcentral\n"; }
      }
      else {
        # if the sequence *only* exists in RNAcentral verify that it
        # has the proper name format URS_taxid
        if((! $pass_rfm) && (! $pass_gbk)) {
          my ($is_rnacentral_taxid, undef, undef) = Bio::Rfam::Utils::rnacentral_urs_taxid_breakdown(($is_nse) ? $name : $nse);
          if($is_rnacentral_taxid != 1) {
            # Another possible case of 8) subseq appears to exist in RNAcentral by id, but md5 does not match
            $passfail = "FAIL";
            if($be_verbose) { $outstr .= "RNC:md5-subseq-id-fail;"; }
            else            { warn "SEED sequence $nse fails validation; it is only in RNAcentral, but its name is not in the expected URS_taxid format\n"; }
          }
          else {
            # sequence exists by id, md5 matches and it's in proper URS_taxid format
            $nrnc_pass++;
            $pass_rnc = 1;
            if($be_verbose) { $outstr .= "RNC:md5-subseq-pass;"; }
          }
        }
      }
    }
    if($be_verbose) { printf("%-30s  $passfail  $outstr\n", $nse); }
    if($passfail eq "FAIL") { $nfail++; }
  }

  if($nfail > 0) {
    warn "script Rfam/Scripts/jiffies/validate_seed_sequences_against_database.pl can provide more information";
  }

  if($be_verbose) {
    print("nseq:      $nseq\n");
    print("nrfm_pass: $nrfm_pass\n");
    print("ngbk_pass: $ngbk_pass\n");
    print("nrnc_pass: $nrnc_pass\n");
    print("nfail:     $nfail\n");
  }

  # return value differs depending on $be_verbose value:
  if($be_verbose) {
    return $nfail;
  }
  return ($nfail > 0) ? 1 : 0; # return 1 if at least 1 seq failed
}

#------------------------------------------------------------------------------
=head2 checkSEEDSeqsNameOnly

  Title    : checkSEEDSeqsNameOnly
  Incept   : EPN, Thu Apr  2 16:52:07 2020
  Usage    : Bio::Rfam::QC::checkSEEDSeqsNameOnly($familyObj, $seqDBObj, $be_verbose)
  Function : Checks each SEED sequencs to see if a sequence of the
           : same name exists in rfamseq. Note, doesn't remove "/<start>-<end>"
           : from the SEED sequence name if it exists, it checks the
           : entire sequence name, possibly including "/<start>-<end>"
           :
  Args     : Bio::Rfam::Family object
           : Bio::Rfam::SeqDB object
  Returns  : List of sequences that fail the name check, "" on successully passing check

=cut

sub checkSEEDSeqsNameOnly {
  my ( $familyObj, $seqDBObj ) = @_;

  #Check we have the correct family object.
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  my $seed = $familyObj->SEED;
  my $nseq  = $seed->nseq;
  my $name_str = "";
  my $ret_str = "";
  # look-up each SEED sequence
  for ( my $i = 0 ; $i < $nseq; $i++ ) {
    my $name = $seed->get_sqname($i);
    my $name_exists_in_db = $seqDBObj->check_seq_exists($name) ? 1 : 0;
    if($name_exists_in_db) {
      $name_str .= "\t$name\n";;
    }
  }
  if($name_str ne "") {
    $ret_str  = "The following sequence names exist in both the SEED and the target db.\n";
    $ret_str .= "Change their names in SEED, preferable to <name>/<start>-<end>\n";
    $ret_str .= $name_str;
  }

  return $ret_str;
}

#------------------------------------------------------------------------------
=head2 checkScoresSeqs

  Title    : checkScoresSeqs
  Incept   : finnr, Jul 31, 2013 2:54:26 PM
  Usage    : Bio::Rfam::QC::checkScoresSeqs($familyObj, $seqDBObj)
  Function :
  Args     :
  Returns  :

=cut

sub checkScoresSeqs {
  my ( $familyObj, $seqDBObj ) = @_;

  #Check we have the correct family object.
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  #Check we have the correct seqDBobj object.
  if ( !$seqDBObj or !$seqDBObj->isa('Bio::Rfam::SeqDB') ) {
    die "Did not get passed in a Bio::Rfam::SeqDB object\n";
  }

  my $error = 0;
  eval { $seqDBObj->fetch_subseqs( $familyObj->SCORES->regions ); };
  if ($@) {
    $error = 1;
    warn "ERROR: $@\n";
  }
  return $error;
}

#------------------------------------------------------------------------------
=head2 checkOverlaps

  Title    : checkOverlaps
  Incept   : finnr, Aug 5, 2013 4:08:00 PM
  Usage    :
  Function :
  Args     :
  Returns  :

=cut

sub checkOverlaps {
  my ( $familyObj, $config, $ignore, $famPath ) = @_;

  #Check we have the correct family object.
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

    my $rfamdb = $config->rfamlive;


#is the family part of a clan?
    if ($familyObj->DESC->CL) {
        my $clan = $familyObj->DESC->CL;
#get clan membership and add members to ignore hash
        my @rs = $rfamdb->resultset('ClanMembership')->search( { clan_acc => $clan });
        foreach my $row (@rs){
            my $rfam_acc = $row->rfam_acc->rfam_acc;
            $ignore->{$rfam_acc}=1;
        }
    }

  open(my $OVERLAP, '>', "$famPath/overlap")
    or die "Could not open $famPath/overlap:[$!]\n";

  my $error = 0;
  my $masterError = 0;
  $error = findExternalOverlaps($familyObj, $rfamdb, $ignore, $config, $OVERLAP);
  $masterError =  1 if($error);
  $error = findInternalOverlaps($familyObj, $OVERLAP);
  $masterError =  1 if($error);

  close($OVERLAP);

  return $masterError;
}

#-----------------------------------------------------------------------------
=head2 findClanOverlaps

  Title		: findClanOverlaps
  Incept    : swb Tues 27 May 2014
  Useage    :
  Function 	:
  Args 	 	: Rfam family object, database, config, OVERLAP and other clan families
  Returns   :

=cut

sub findClanOverlaps {
	my ($familyObj, $rfamdb, $config, $clan_members) = @_;
	if($config->location ne 'EBI'){
    	warn "This overlap test has been written assuming you have a local database.".
        	 "Eventually, there needs to be a Web based overlap method\n.";
  	}

	# Get some basic information: the first family we want to look at, make a map of all the clan families
	#
	my $this_family = $familyObj->DESC->AC;
	my %members = map { $_ => 1 } @$clan_members;
	my $clerror = 0;
	my $currentAcc ='';
	my @not_significant;
	my $strand;
	my @clan_regions;
	#p @$clan_members;
	#Get all regions for all families in the clan:
	#
	for my $family (@$clan_members) {
		my $regions = $rfamdb->resultset('FullRegion')->allRegions($family);

	#For each region, get start and end coordinates and figure out which strand it is on:
	#
		for my $r ( @$regions) {
			my ($s1, $e1, $strand) =
        	$r->[1] <= $r->[2] ? ($r->[1], $r->[2], 1) : ($r->[2], $r->[1], -1);

	# Add hash of each region to the clan_regions array:
	#
		push @clan_regions , {rfamseq_acc => $r->[3],
						start => $s1,
						end => $e1,
						strand => $strand,
						evalue => $r->[5],
						family => $family,
						type => $r->[9]};

		}
	}
 	# Now look for overlaps for every region:
 	#
	for my $region (@clan_regions) {

	# Counter to avoid checking the same sequence twice:
		my %seen;

	# Store the accession of our query :
		my $orig_acc = $region->{rfamseq_acc};
	# Set overlap counter to zero for starters:
	#
		my $ol = 0;
		my @overlaps;

	# Now, compare our query sequence with every other region in the clan:
	#
		for my $poss_overlap( @clan_regions) {
			#Ignore any regions which come from the same family
			#
			if ($region->{family} eq $poss_overlap->{family}) {
				next;
			}


			#Ignore any sequence accessions which we have seen before, as we will already have
			#checked these for overlaps:
			#
			my $acc = $poss_overlap->{rfamseq_acc};
			if ($seen{$acc}) {
				#print "Skipping, already seen $poss_overlap->{rfamseq_acc}\n";
			}
			#Ignore any regions with a different sequence accession:
			#
			next unless ($region->{rfamseq_acc} eq $poss_overlap->{rfamseq_acc});
			#Set start and end coordinates of query and possible overlap:
			#
			my ($s1, $e1) = ($region->{start},$region->{end});
			my ($s2, $e2) = ($poss_overlap->{start}, $poss_overlap->{end});
			my $overlap = 0;
			#Now calculate % overlap:

			#Now check for overlaps:
			$overlap = Bio::Rfam::Utils::overlap_nres_or_full($s1, $e1, $s2, $e2);
			if ($overlap != 0) {
				#p $overlap;
				$overlap = 'fullOL' if ($overlap == -1);
				my $len1 = abs ($s1 - $e1);
				my $len2 = abs ($s2 - $e2);
				my $percent_ol = $len2 / $len1;
				#print "lenth1 = $len1\tlength2 = $len2\t percent = $percent_ol\n";
				if ($percent_ol < 0.5 || $percent_ol > 2) {
					#print "Overlap less than 50%, skipping\n";
					next;
				}

				my $overlap_type = $poss_overlap->{strand} eq $region->{strand} ? 'SS' : 'OS';
				$ol++;
				#Add the overlapping region to @overlaps:
				push (@overlaps, $poss_overlap);
			}
		}
		#Now we know the query sequence has an overlap, add this to @overlaps:
		#
		if ($ol != 0) {
			push @overlaps, $region;
		}

		#Sort the overlaps by e value and then take the highest match as the significant match:
		#
		my @sorted_overlap = sort {$a->{evalue} <=> $b->{evalue}} @overlaps;
		foreach my $hash (@sorted_overlap) {
			if ($hash eq $sorted_overlap[0] ){
				$hash->{'is_significant'} = 1;
			} else {
				$hash->{'is_significant'} = 0;
				my ($start, $end) = $hash->{strand} eq 1 ? ($hash->{start}, $hash->{end}):($hash->{end}, $hash->{start});
				my $resultset = $rfamdb->resultset('FullRegion')->search( {rfam_acc => $hash->{family},
																		rfamseq_acc => $hash->{rfamseq_acc},
																		seq_start => $start,
																		seq_end => $end,
																		evalue_score => $hash->{evalue}
																	})->single;


				$resultset->update({is_significant => '0'});
			}
		#
		#	print $OVERLAP "$hash->{rfamseq_acc}\t$hash->{start}\t$hash->{end}\t$hash->{strand}\t$hash->{evalue}\t$hash->{family}\t$hash->{type}\t$hash->{is_significant}\n";
		}
		#Update counter now we've done this region:
		$seen{$orig_acc}++;
	}



	return $clerror;

}


#------------------------------------------------------------------------------
=head2 findExternalOverlaps

  Title    : findExternalOverlaps()
  Incept   : finnr, Aug 5, 2013 4:08:17 PM
  Usage    :
  Function :
  Args     :
  Returns  :

=cut


sub findExternalOverlaps {
  my ($familyObj, $rfamdb, $ignore, $config, $OVERLAP) = @_;

  _addBlackListToIgnore($ignore, $config);

  if($config->location ne 'EBI'){
    warn "This overlap test has been written assuming you have a local database.".
         "Eventually, there needs to be a Web based overlap method\n.";
  }
  my $error = 0;
  my $currentAcc = '';
  my $regions;
  foreach my $r (sort{$a->[3] cmp $b->[3]} @{$familyObj->SCORES->regions}){
    my ($s1, $e1, $or1) =
        $r->[1] <= $r->[2] ? ($r->[1], $r->[2], 1) : ($r->[2], $r->[1], -1);

    if($currentAcc ne $r->[3]){
      $regions = $rfamdb->resultset('FullRegion')->allRegionInfo($r->[3]);
      $currentAcc=  $r->[3];
    }
    foreach my $dbReg (@$regions){
      #Does it belong to a family we want to ignore?
      next if(exists($ignore->{$dbReg->[1]}));
      my ($s2, $e2) =
        $dbReg->[4] == 1 ? ($dbReg->[2], $dbReg->[3]) : ($dbReg->[3], $dbReg->[2]);
      my $overlap = 0;
      $overlap = Bio::Rfam::Utils::overlap_nres_or_full($s1, $e1, $s2, $e2);
      # Careful, we need to use s1/e1 and s2/e2 (instead of just r->[1], r->[2] and
      # dbReg->[2] and dbReg[3]) b/c we want to detect an overlap ON EITHER STRAND
      if($overlap != 0){
          $overlap = 'fullOL' if ( $overlap == -1 );
          my $overlapType =  $dbReg->[4] eq $or1 ? 'SS' : 'OS';
          #TODO Fix reporting when I have information.
          my $eString = sprintf "External overlap [%s] of %s (%.2f bits) with %s (%.2f bits) by %s\n",
              $overlapType,
              $r->[0],
              $r->[4], 
              $dbReg->[1].":".$dbReg->[0]."/".$dbReg->[2]."-".$dbReg->[3],
              $dbReg->[5],
              $overlap;
          print $OVERLAP $eString;
          print STDERR $eString;
	  $error++;
      }
    }
  }
  return $error;
}

#------------------------------------------------------------------------------
=head2 findInternalOverlaps

  Title    : findInternalOverlaps
  Incept   : finnr, Jul 31, 2013 2:28:40 PM
  Usage    : Bio::Rfam::QC::findInternalOverlaps($familyObj, $OVERLAP)
  Function : Takes a family object and looks for overlaps within the SEED
           : alignment. It will report overlaps to STDERR and to the overlap
           : file.
  Args     : A Bio::Rfam::Family object, overlaps filehandle
  Returns  : 1 on error, 0 if no overlaps are found.

=cut

sub findInternalOverlaps {
  my ($familyObj, $OVERLAP) = @_;

  #Check we have the correct family object.
  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }

  if(!$OVERLAP and ref($OVERLAP) ne 'GLOB'){
    die "Did not get passed a filehandle for reporting\n";
  }

  my $error = 0;
  my @atomizedNSE; #Avoid duplication of effort, once we have looped through once
                   #we should have all NSE.

  for ( my $i = 0 ; $i < $familyObj->SEED->nseq - 1 ; $i++ ) {
     $atomizedNSE[$i]  = [Bio::Rfam::Utils::nse_breakdown($familyObj->SEED->get_sqname($i))]
        if ( !$atomizedNSE[$i] );
    for ( my $j = $i + 1 ; $j < $familyObj->SEED->nseq ; $j++ ) {
      $atomizedNSE[$j]  = [Bio::Rfam::Utils::nse_breakdown($familyObj->SEED->get_sqname($j))]
        if ( !$atomizedNSE[$j] );
      next if($atomizedNSE[$i]->[1] ne $atomizedNSE[$j]->[1]);
      # determine overlap fraction (overlap_nres_or_full() is robust to start < end or start > end)
      my $overlap = Bio::Rfam::Utils::overlap_nres_or_full(
        $atomizedNSE[$i]->[2],
        $atomizedNSE[$i]->[3],
	$atomizedNSE[$j]->[2],
        $atomizedNSE[$j]->[3]);

      if($overlap != 0) {
        $overlap = 'fullOL' if ( $overlap == -1 );
        my $eString = sprintf "Internal overlap of %s with %s by %s\n",
        $familyObj->SEED->get_sqname($i),
        $familyObj->SEED->get_sqname($j),
        $overlap;
        print $OVERLAP $eString;
        print STDERR $eString;
        $error = 1;
      }
    }
  }
  return $error;
}

#------------------------------------------------------------------------------
=head2 codingSeqs

  Title    : codingSeqs
  Incept   : finnr, Jul 29, 2013 3:10:48 PM
  Usage    : Bio::Rfam::QC::codingSeqs($familyObj, $config)
  Function : Takes the seed alignment, reformats it to clustal (with '-' as a
           : gap character). It then runs third party software, RNACode to
           : identify potential coding regions. The p-value threshold for this
           : comes from the config.
  Args     : A Bio::Rfam::Family object, a Bio::Rfam::Config
  Returns  : 0 when no errors, 1 and scalar of RNAcode output on error.

=cut

sub codingSeqs {
  my ($familyObj, $config) = @_;

  my ($fh, $filename) = tempfile();
  close($fh);

  #Write the file out as clustal
  $familyObj->SEED->write_msa($filename, 'clustal');

  #Get the pvalue that we will use for cut-off.
  my $pvalue = $config->rnacode_pvalue; #Get via the config.

  #run RNAcode on clustal file and capture results in STDOUT pipe.
  my @cmd = qw(RNAcode -s -p );
  push(@cmd, $pvalue, $filename);
  my($out, $err, $in);
  run \@cmd, \$in, \$out, \$err, or die "FATAL: Error running RNAcode: $?";
  if($out =~ /No significant coding regions found/ || $err =~ /Skipping alignment\. There must be at least three sequences in the alignment\./){
    #No errors, or alignment too small to check for coding seqs
    return 0;
  }else{
    #Errors...
    my $error = 1;
    my $out = "Found potential coding regions in SEED alignment.\n $out\n";
    return ($error, $out);
  }
}

#------------------------------------------------------------------------------
=head2 essential

  Title    : essential
  Incept   : finnr, Aug 5, 2013 3:55:24 PM
  Usage    : Bio::Rfam::QC::essential($newFamilyObj, $dir, $oldFamily, $config, $override)
  Function : Takes the new family and performs all of the essential QC steps on
           : the family. Due to the repetoire of QC, need file location, old family
           : and config objects.
  Args     : Bio::Rfam::Family object for the new family,
           : path to the family,
           : Bio::Rfam::Family object for the old family or undef if new,
           : A Bio::Rfam::Config object,
           : (optional) hashref of QC steps to skip, e.g. {overlap => 1}
  Returns  : 1 on error, 0 on success.

=cut

sub essential {
  my ($newFamily, $dir, $oldFamily, $config, $override) = @_;
  if(! defined $override) { $override = {}; }

  my $masterError = 0;
  my $error = 0;

  my $seqDBObj = $config->rfamseqObj;

  $error = Bio::Rfam::QC::checkTimestamps($dir, $config);
  if($error){
    warn "Family failed essential format checks.\n";
    $masterError = 1;
  }

  $error = Bio::Rfam::QC::checkFamilyFormat($newFamily, $config);
  if($error){
    warn "Family failed essential format checks.\n";
    $masterError = 1;
  }

  $error = checkSEEDSeqs($newFamily, $seqDBObj);
  if($error){
    warn "Family failed essential check that seed sequences are all valid (from at least one of rfamseq, GenBank or RNAcentral).\n";
    $masterError = 1;
  }

  $error = checkScoresSeqs($newFamily, $seqDBObj);
  if($error){
    warn "Family failed essential threshold check.\n";
    $masterError = 1;
  }

  if(defined($oldFamily)){
    $error = checkFixedFields($newFamily, $oldFamily);
    if($error){
      warn "Family failed, illegal field changes in DESC file.\n";
      $masterError = 1;
    }
  }

  if(!exists($override->{overlap})){
    open( my $OVERLAP, '>>', "$dir/overlap") or die "Could not open $dir/overlap:[$!]";
    $error = findInternalOverlaps($newFamily, $OVERLAP);
    close($OVERLAP);
    if($error){
      warn "Found internal SEED overlaps.\n";
      $masterError = 1;
    }
  }

  $error = checkIdIsNew($newFamily, $config);
  if($error){
    warn "A family with an identical or too similar ID already exists.\n";
    $masterError = 1;
  }

  return( $masterError );
}

#------------------------------------------------------------------------------
=head2

  Title    : optional
  Incept   : finnr, Aug 5, 2013 3:55:47 PM
  Usage    : Bio::Rfam::QC::optional($newFamily, $dir, $oldFamily, $config, $override, $ignore)
  Function : Takes the new family and performs all QC steps except
           : those X for which $override->{X} is true.
  Args     : $newFamily: Bio::Rfam::Family object for the new family
           : $dir:       path to the family
           : $oldFamily: Bio::Rfam::Family object for the old family or undef if new
           : $config:    Bio::Rfam::Config object
           : $override:  hash with keys as names of tests to skip ('seed', 'coding', 'spell', 'missing', 'overlap')
           : $ignore:    hash with keys as families to ignore in overlap test
  Returns  : '0' if all tests pass, '1' if any fail
=cut

sub optional {
  my ($newFamily, $dir, $oldFamily, $config, $override, $ignore) = @_;

  my $error       = 0;
  my $masterError = 0;
  my $msg         = "";

  if(!exists($override->{spell})){
    $error = checkSpell($dir, $config->dictionary);
    if($error){
      warn "Failed running spelling QC.\n";
      $masterError = 1;
    }
  }else{
    warn "Ignoring spell check.\n";
  }

  if(!exists($override->{seed})){
    $error = compareSeedAndSeedScores($newFamily);
    if($error){
      warn "Failed check to ensure all SEED sequences found.\n";
      $masterError =1;
    }
  }else{
    warn "Ignoring check to ensure all SEED sequences found.\n";
  }

  if(!exists($override->{coding})){
    ($error, $msg) = codingSeqs($newFamily, $config);
    if($error){
      warn "Failed check to SEED sequences do not contain coding regions.\nPlease check RNAcode output below:\n\n--------------------\n$msg--------------------\n";
      $masterError =1;
    }
   }else{
    warn "Ignoring check for coding regions in SEED sequences.\n";
  }

  if(!exists($override->{missing})){
    if(defined($oldFamily)){
      my ($found, $missing) = compareOldAndNew($oldFamily, $newFamily);
      if(scalar(@$missing)){
      	print("Do you want to continue regardless? [y/n]  ");
      	my $reply = <STDIN>;
      	chomp $reply;
      	if ( $reply eq "y" ) {
          #Override the error....
          $error = 0;
        }
        else {
          $masterError = 1;
        }
      }
    }
  }

  # check for overlaps between full set of this family and every other family
  # but if this family is in a clan, ignore any other families in the same clan.
  if(!exists($override->{overlap})){
    #is the family part of a clan?
    if ($newFamily->DESC->CL) {
      my $clan = $newFamily->DESC->CL;
      # get clan membership and add members to ignore hash
      my @rs = $config->rfamlive->resultset('ClanMembership')->search( { clan_acc => $clan });
      foreach my $row (@rs){
        my $rfam_acc = $row->rfam_acc->rfam_acc;
        $ignore->{$rfam_acc}=1;
      }
    }
    open( my $OVERLAP, '>>', "$dir/overlap") or die "Could not open $dir/overlap:[$!]";
    $error = findExternalOverlaps($newFamily, $config->rfamlive, $ignore, $config, $OVERLAP);
    close($OVERLAP);
    if($error){
      warn "Found overlaps.\n";
      $masterError =1;
    }
   }else{
    warn "Ignoring overlap check.\n";
  }

  if(!exists($override->{length})){
    $error = checkCMLength($newFamily);
    if($error){
      warn "Failed check on minimum consensus length of model.\n";
      $masterError =1;
    }
  }else{
    warn "Ignoring check on minimum consensus length of model.\n";
  }

  if(!exists($override->{seedrf})){
    # TEMPORARY
    my $capitalizePath = $config->binLocation . "esl-alicapitalize.pl";
    my $seed_diff_file = 
    $error = checkSeedRfConventions($newFamily,
                                    $capitalizePath,
                                    "$dir/qc.SEED.diff"); # this file will be deleted if SEED passes, kept if not
    if($error){
      warn "Found problem with SEED related to RF conventions";
      $masterError =1;
    }
  }else{
    warn "Ignoring check on SEED upper/lowercase and SS_cons agreement with RF annotation.\n";
  }

  return($masterError);
}

#------------------------------------------------------------------------------
=head2 processIgnoreOpt

  Title    : processIgnoreOpt
  Incept   : finnr, Aug 5, 2013 3:34:19 PM
  Usage    : Bio::Rfam::QC::processIgnoreOpt($ignorableOpts, $config, $acc)
  Function : As we need to relax the QC from time-to-time, this takes in the array
           : captures typically by GetOpt::Long and checks to see if the option
           : corresponds to an allowed, overridable option as specified in the
           : config.  If the accession of the family is one of the few blacklisted
           : families, the overlap option will not be run.
  Args     : Array containing options, Bio::Rfam::Config object, accession of family (optional)
  Returns  : hash, keys are allowed options.

=cut

sub processIgnoreOpt {
  my ($ignoreRef, $config, $acc) = @_;

  #See if the family if one of the few blacklisted? If so,
  #do not bother running the overlap check.
  if($acc){
    if(exists $config->allowedOverlaps->{$acc}){
      #$ignoreRef->{overlap} = 1;
	  push (@$ignoreRef, 'overlap');
	}
  }

  my $allowedOpts = $config->ignorableQC;

  #Go through each option passed in and see if it is allowed.
  foreach my $i (@{$ignoreRef}){
    if(! exists($allowedOpts->{$i})){
      die "$i is an unknown QC 'ignore' option.\n";
    }
  }
  #Now, convert it to a hash.
  my %passback = map {$_ => 1 } @{$ignoreRef};
  return \%passback;
}

sub essentialClan {
  my ($newClan, $oldClan, $config) = @_;

  my $masterError = 0;
  my $error = 0;

  $error = Bio::Rfam::QC::checkClanFormat($newClan);

  if($error){
    warn "Family failed essential clan format checks.\n";
    $masterError = 1;
  }


  if(defined($oldClan)){
    $error = checkClanFixedFields( $newClan, $oldClan );
    if($error){
      warn "Clan failed, illegal field changes in DESC file.\n";
      $masterError = 1;
    }
  }

  return $masterError;
}


sub checkClanFormat {
  my ($clanObj) = @_;

  my $error = 0;
   #Make sure none of the default values set in writeEmptyDESC still exist
  foreach my $key ( keys %{ $clanObj->DESC->defaultButIllegalFields } ) {
    if ( !defined( $clanObj->DESC->$key ) ) { #make sure it's defined first
      warn "Required CLANDESC field $key not defined.\n";
      $error++;
    }
    elsif( $clanObj->DESC->$key eq $clanObj->DESC->defaultButIllegalFields->{$key} ) {
      warn "CLANDESC field $key illegal value (appears unchanged from default).\n";
      $error++;
    }
  }
  return $error;
}

#TODO
sub optionalClan{
  my ($newFamily, $dir, $oldFamily, $config, $override, $ignore) = @_;

  my $error       = 0;
  my $masterError = 0;
  my $msg         = "";

  if(!exists($override->{spell})){
    $error = checkSpell($dir, $config->dictionary);
    if($error){
      warn "Failed running spelling QC.\n";
      $masterError = 1;
    }
  }else{
    warn "Ignoring spell check.\n";
  }
}
#------------------------------------------------------------------------------
=head2 _addBlackListToIgnore

  Title    : _addBlackListToIgnore
  Incept   : finnr, Aug 5, 2013 3:51:09 PM
  Usage    : _addBlackListToIgnore($ignore, $config);
  Function : Added the accessions of blacklisted families to the hash of ignored
           : families.
  Args     : hash reference, Bio::Rfam::Config object.
  Returns  : Nothing - hash reference is manipulated.

=cut

sub _addBlackListToIgnore {
  my ($ignore, $config) = @_;

  foreach my $k (keys( %{ $config->allowedOverlaps })){
    $ignore->{$k} = 1;
  }

  return;
}

#------------------------------------------------------------------------------
=head2 nameFormatIsOK

  Title    : nameFormatIsOK
  Incept   : swb, Apr 9, 2014 4:42:09 PM
  Usage    : nameFormatIsOK($ignore, $config);
  Function : Checks ID line conforms to required format
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on success, 0 on error

=cut

sub nameFormatIsOK {
	my ($newName) = @_;

	#if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    #	die "Did not get passed in a Bio::Rfam::Family object\n";
  	#}
  	my $error = 0;

	#my $IDline = $familyObj->DESC->ID;
	if ($newName =~ /[\w-]{1,15}/) {
		#warn "The new ID line does not match the correct format!\n";
		$error = 0;
		return $error;
	}

}

#------------------------------------------------------------------------------
=head2 checkIdIsNew

  Title    : checkIdIsNew()
  Incept   : EPN, Fri Jun  4 19:50:20 2021
  Usage    : Bio::Rfam::QC::checkIdIsNew()
  Function : Checks that the provided ID for a new family does not already exist
           : for another family
  Args     : $familyObj: Bio::Rfam::FamilyIO object, used to access ID
           : $config:    Bio::Rfam::Config object, used to access rfamdb
  Returns  : 0 if no other family in rfamdb has same ID as familyObj
           : 1 if >=1 other families in rfamdb have same ID as familyObj
=cut


sub checkIdIsNew {
  my ($familyObj, $config) = @_;

  if($config->location ne 'EBI'){
    warn "This overlap test has been written assuming you have a local database.";
  }
  my $error = 0;

  my $cur_acc = $familyObj->DESC->AC || '';
  my $cur_id  = $familyObj->DESC->ID;
  my $cur_lc_all_alphanumeric_id   = $cur_id; # $cur_id, all lowercase, with non-alphanumeric characters removed
  $cur_lc_all_alphanumeric_id =~ tr/A-Z/a-z/;
  $cur_lc_all_alphanumeric_id =~ s/[^\d\w]//g;

  my $rfamdb  = $config->rfamlive;
  my %acc2id_H = ();  # key is accession, value is id
  $rfamdb->resultset('Family')->allIds(\%acc2id_H);

  foreach my $acc (sort keys (%acc2id_H)) {
    if($acc ne $cur_acc) {
      my $lc_all_alphanumeric_id = $acc2id_H{$acc};
      $lc_all_alphanumeric_id =~ tr/A-Z/a-z/;
      $lc_all_alphanumeric_id =~ s/[^\d\w]//g;
      if($lc_all_alphanumeric_id eq $cur_lc_all_alphanumeric_id) {
        warn "Failed checkIdIsNew() the proposed new ID $cur_id is too similar to " . $acc2id_H{$acc} . ", the ID for existing accession $acc";
        $error = 1;
      }
    }
  }

  return $error;
}

#------------------------------------------------------------------------------

=head2 checkCMLength

  Title    : checkCMLength
  Incept   : EPN, Tue Jun  8 12:00:56 2021
  Usage    : Bio::Rfam::QC::checkCMLength($familyObj)
  Function : Checks that CM length is above minimum length
           : <$act_min> and returns 1 if not. Prints a warning if below
           : warning length <$warn_min>.
  Args     : A Bio::Rfam::Family object
  Returns  : 1 on error, 0 on passing checks.

=cut

sub checkCMLength {
  my ($familyObj, $act_min, $warn_min) = @_;

  if(! defined $act_min)  { $act_min  = 50; }
  if(! defined $warn_min) { $warn_min = 60; }

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    die "Did not get passed in a Bio::Rfam::Family object\n";
  }
  my $error = 0;

  if ( $familyObj->CM->cmHeader->{clen} < $act_min) {
    $error = 1;
    warn "FATAL: CM consensus length of " . $familyObj->CM->cmHeader->{clen} . " is below minimum ($act_min)";
    return $error;
  }
  elsif ( $familyObj->CM->cmHeader->{clen} < $warn_min) {
    warn "WARNING: CM consensus length of " . $familyObj->CM->cmHeader->{clen} . " is low but above minimum of $act_min (not FATAL)";
  }

  return $error;
}

#------------------------------------------------------------------------------

=head2 checkSeedRfConventions

  Title    : checkSeedRfConventions
  Incept   : EPN, Thu Dec  8 19:16:40 2022
  Usage    : Bio::Rfam::QC::checkSeedRfConventions($familyObj)
  Function : Checks that SEED MSA follows RF annotation conventions
           : using Bio-Easel's esl-alicapitalize.pl script.
           : These are the conventions followed by Infernal programs.
           : For aligned sequences:
           : - All nucleotides in    gap RF positions should be lowercase
           : - All nucleotides in nongap RF positions should be uppercase
           : - All gaps in    gap RF positions should be '.'
           : - All gaps in nongap RF positions should be '-'
           : For SS_cons:
           : - SS_cons should be in full WUSS format (see Infernal user guide)
           : - SS_cons characters in gap RF positions should be '.'
           :
  Args     : $familyObj:  Bio::Rfam::Family object
           : $scriptPath: path to 'esl-alicapitalize.pl' executable
           : $outDiffFile: path for output of 'esl-alicapitalize.pl --checkonly'
           : 
  Returns  : 1 if SEED does not follow these conventions, 0 if it does
           : If '0' $outDiffFile will be deleted 
           : If '1' $outDiffFile will exist on the filesystem upon return
=cut

sub checkSeedRfConventions {
  my ($familyObj, $scriptPath, $outDiffFile) = @_;

  my $sub_name = "checkSeedRfConventions";

  if ( !$familyObj or !$familyObj->isa('Bio::Rfam::Family') ) {
    warn "\nFATAL ERROR in $sub_name, did not get passed in a Bio::Rfam::Family object\n";
    return 1;
  }
  if (! defined $scriptPath) {
    warn "FATAL ERROR in $sub_name, did not get passed in a script path\n";
    return 1;
  }
  if (! defined $outDiffFile) {
    warn "FATAL ERROR in $sub_name, did not get passed in an output diff file name\n";
    return 1;
  }
  my $error = 0;

  # Use the Bio-Easel esl-alicapitalize.pl script to actually do the work here
  my $seed_file = $familyObj->SEED->path;
  Bio::Rfam::Utils::run_local_command("perl $scriptPath --checkonly --perposn $seed_file > $outDiffFile");
  
  # 1st line of $outDiffFile will be '0' if SEED currently follows all conventions
  # and '1' if SEED does not, in which case detailed list of changes will follow
  open(DIFF, $outDiffFile) || die "ERROR unable to open $outDiffFile for reading";
  my $result = <DIFF>;
  chomp $result;
  if($result eq "PASS" | $result eq "0") {
    # SEED passes, remove temporary file
    unlink $outDiffFile;
  }
  else {
    print STDERR ("FATAL: SEED doesn't follow expected conventions, description saved in file: $outDiffFile\nRun rewrite_seed_with_rf.pl jiffy script to update SEED to follow conventions.\n");
    $error = 1;
  }

  return $error;
}

#------------------------------------------------------------------------------
1;
