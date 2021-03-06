use strict;
use warnings;
use Test::More tests => 4;
use FindBin;

BEGIN {
  use_ok( 'Bio::Rfam::SeqDB' ) || print "Failed to load Bio::Rfam::SeqDB!\n";
}

my $dir = $FindBin::Bin;
my $test_file = $dir . '/data/seqdb/seqdb.test.fa';

my $seqDBObj = Bio::Rfam::SeqDB->new( { fileLocation => $test_file,
                                        dbname       => 'rfamseq' });

isa_ok($seqDBObj, 'Bio::Rfam::SeqDB');
$seqDBObj->create_ssi_index;
is($seqDBObj->dbname, 'rfamseq', 'Expecting rfamseq as dbname');
my $seqs = [qw(AAAA02006309.1)];

my $seqDBSeqs = $seqDBObj->fetch_seqs_given_names( $seqs, -1 );

my $expect =">AAAA02006309.1 Oryza sativa Indica Group chromosome 2 Ctg006309, whole genome shotgun sequence.
ATGGTGAACGGGAGGGATTACCATACCTACCGCGAACTGGCGGAGGCCTTCGAGCTTGATATACACGACTTTAGCGTGTCTGAAGCCAATCGATAGCGCGAAAAAAATCCCGGTCATGGGGATGGCCGGGATCAAAACTTGCTTATGCAAGAAGCACTTGAAAATTCGTTACACCAGGAAATCTGATGTACAAACCACACTATCCCCAACGATTTTGTCTGACAAGCATATATTCTTACGGCGAATATAATATTTTTAACATAATCATTTTTGTTATGAGCAATAACGCACGGTGAATGCGGCTTTGGCTGAATCGCGTCTTATAAAGACGGTTTTCCCTTCAGTATTTTTTTAAGAATATTCTTAGGTAGAGGCGCGTGCGCTTTCAGGAGTCATCATGCTTTCACTTCAGGGTCCCCTGCTGGTTTTTTCCGATCTGGATGGATCGCTTCTGGACTTTCATACCTACGAGTGGCAACCCGCGATGCCATGGCTGGACAAACTGCAGGATTATCAGGTGCCGGTGATTCTGTGCAGCAGCAAGAGTGCCGCAGAGATGCTGGATATCCAACAGGATCTGGGCCTGGAGGGGTTACCTTTTATTGCTGAGAACGGCGCGGTCATTCAGCCTGATGTGCGCTGGGAGATGGGGCAGAGCCAGATCACAGGGATGACGCATCGGGAAATTCATCCGCTTATTGAGCAAATCCGCCAGCAGGCAGGCTTTAAATTCGTCACGTTTGATGACGTGAACGAACGCGTCATCAGCGAATGGACCGGGCTGACGCGCTACCGTGCGGCGCTCGCACGCAAACACGACGCCTCTGTCACGCTCATCTGGCGTGATACCGACGACGCAATGGTCCGCTTTGAAGAGGCGCTGGCGCAAAGGGGTCTGAAATGTCTACAGGGGGCTCGTTTCTGGCACATTCTG
";

is($seqDBSeqs, $expect, "Did not get expected fasta");
END {
  unlink($test_file.'.ssi');
}
