use strict;
use warnings;
use Test::More tests => 25;
use FindBin;

BEGIN {
  use_ok( 'Bio::Rfam::FamilyIO' )   || print "Failed to load Bio::Rfam::FamilyIO!\n";
  use_ok( 'Bio::Rfam::Family::CM' ) || print "Failed to load Bio::Rfam::Family::CM!\n";
  use_ok( 'Bio::Rfam::Infernal' )   || print "Failed to load Bio::Rfam::QC!\n";
}

my $dir = $FindBin::Bin;
my $test_data= $dir . '/data/';

my $familyIO = Bio::Rfam::FamilyIO->new( );
isa_ok($familyIO, 'Bio::Rfam::FamilyIO');

# CM with 0 basepairs
my $cm_zero = $familyIO->parseCM( $test_data.'/RF00476/CM' );
isa_ok($cm_zero, 'Bio::Rfam::Family::CM');
is($cm_zero->is_calibrated, 1, 'Correctly set calibration');

# CM with >0 basepairs
my $cm = $familyIO->parseCM( $test_data.'/RF00006/CM' );
isa_ok($cm, 'Bio::Rfam::Family::CM');
is($cm->is_calibrated, 1, 'Correctly set calibration');

# Checks on the CM body.
is(defined($cm->cmBody), 1, 'has a cmBody defined');
my $body = $cm->cmBody;
is($body->[0],  "CM\n", 'Body started  with CM');
is($body->[$#$body],  "//\n", 'Body finished with//');

# did we identify match_pair nodes correctly? 
is($cm->match_pair_node, 1, 'Correctly set match pair node (zero basepairs)');
is($cm_zero->match_pair_node, 0, 'Correctly not set match pair node (zero basepairs)');

# check the cm_evalue2bitsc and cm_bitsc2evalue functions
my $bitsc  = 40;
my $evalue = 1E-5;
my $Z = 10;
my $opts1 = "";
my $opts2 = "--nohmmonly";
my $opts3 = "--hmmonly";

##### cm_evalue2bitsc
# the RF00006 CM (>0 basepairs) with all 3 option strings:
my $ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm, $evalue, $Z, $opts1);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 36, 'cm_evalue2bitsc correctly calculates >0 bp bit score 1');

$ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm, $evalue, $Z, $opts2);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 36, 'cm_evalue2bitsc correctly calculates >0 bp bit score 2');

$ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm, $evalue, $Z, $opts3);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 27, 'cm_evalue2bitsc correctly calculates >0 bp bit score 3');

# the RF00476 CM (0 basepairs) with all 3 option strings:
$ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm_zero, $evalue, $Z, $opts1);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 28, 'cm_evalue2bitsc correctly calculates 0 bp bit score 1');

$ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm_zero, $evalue, $Z, $opts2);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 48, 'cm_evalue2bitsc correctly calculates 0bp bit score 2');

$ret_bitsc = Bio::Rfam::Infernal::cm_evalue2bitsc($cm_zero, $evalue, $Z, $opts3);
$ret_bitsc = int($ret_bitsc + 0.5); # round bit score:
is($ret_bitsc, 28, 'cm_evalue2bitsc correctly calculates 0bp bit score 2');

########## cm_bitsc2evalue
my $bitsc1_cm  = 36;
my $bitsc1_hmm = 27;
my $bitsc2_cm  = 48;
my $bitsc2_hmm = 28;

# the RF00006 CM (>0 basepairs) with all 3 option strings:
my $ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm, $bitsc1_cm, $Z, $opts1);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 90, 'cm_bitsc2evalue correctly calculates >0bp E-value 1');

$ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm, $bitsc1_cm, $Z, $opts2);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 90, 'cm_bitsc2evalue correctly calculates >0bp E-value 2');

$ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm, $bitsc1_hmm, $Z, $opts3);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 72, 'cm_bitsc2evalue correctly calculates >0bp E-value 3');

# the RF00476 CM (0 basepairs) with all 3 option strings:
$ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm_zero, $bitsc2_hmm, $Z, $opts1);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 76, 'cm_bitsc2evalue correctly calculates 0bp E-value 1');

$ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm_zero, $bitsc2_cm, $Z, $opts2);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 124, 'cm_bitsc2evalue correctly calculates 0bp E-value 2');

$ret_evalue = Bio::Rfam::Infernal::cm_bitsc2evalue($cm_zero, $bitsc2_hmm, $Z, $opts3);
$ret_evalue = int(($ret_evalue * 10000000) + 0.5); # round E-value so we can compare it
is($ret_evalue, 76, 'cm_bitsc2evalue correctly calculates 0bp E-value 3');
