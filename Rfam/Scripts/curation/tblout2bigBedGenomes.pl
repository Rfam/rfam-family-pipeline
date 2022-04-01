#!/usr/bin/env perl

#parses tblout files produced by cmsearch into bigBed files for genome browser hub
#use: tblout2bigBed.pl infile db
#infile is name of input tblout file, db is assembly name (from UCSC)

use strict;
use warnings;
use Data::Dumper;
use DDP;
use File::Basename;
use Bio::Rfam::Config;


my $infile = $ARGV[0];
my $rel_version = $ARGV[1];


my $config = Bio::Rfam::Config->new;
my $rfamdb = $config->rfamlive;

my $upid = substr basename($infile), 0, 11;
my $dirname = dirname($infile);
my $bedfile = $dirname . '/' . $upid . ".bed";
my $chrom_sizes_file = $dirname . '/' . "chrom.sizes";
my %chrom_sizes_hash = ();

#create BED format file
#open bed file and write header
open (BED, ">$bedfile") or die "Cannot open file $bedfile $!\n";

#open infile and parse
open (IN, "$infile") or die "Cannot open file $infile $!\n";

while (<IN>){

#skip lines beginning #
	unless ($_ =~ /^#/){
		my @data = (split/\s+/,$_);
		#need to ignore those where chrom is non-standard
		
		# working with the rfamseq_acc here. Split target and use third item in the table. 
		my $accession = $data[0];
		my $rfamseq_acc = '';

		# check if accession needs trimming 
		if (index($accession, '|') != -1) {
			my @target = (split/\|/, $accession);
			$rfamseq_acc = $target[2];
		}
		
		else{
			$rfamseq_acc = $accession;
		}

		# fetch chromosome label from Genseq table based on the sequence accession
		my $chromosome_label;
		$chromosome_label = $rfamdb->resultset('Genseq')->get_chromosome_label_for_genome_browser_hub($upid, $rfamseq_acc, $rel_version);

		# jump to next hit if chromosome label is empty or does not comply with the expected format
		if ($chromosome_label eq '' or $chromosome_label =~ /chr\w{1,2}_\S+/){
			next;
		}

		# Write region to bed file
		#start must be lower than end - so the two need reversing if strand = '-'
		my @value_array = (split/\./, $data[14]);
		my $bit_score = $value_array[0];

		# maximum score allowed in bed file
		if ($bit_score > 1000){
			$bit_score = 1000;
		}
		if ($data[9] eq '+'){
	   	  	print BED "$chromosome_label\t$data[7]\t$data[8]\t$data[2]\t$bit_score\t$data[9]\n";
		
		} elsif ($data[9] eq '-'){
	   		print BED "$chromosome_label\t$data[8]\t$data[7]\t$data[2]\t$bit_score\t$data[9]\n";

			
		} else {
	    		print "Strand character unrecognised in line: $_";
		}

		# update chromosome sizes hash directly from rfamseq table using sequence length
		if (!exists($chrom_sizes_hash{$chromosome_label})){
			my $chrom_size = $rfamdb->resultset('Rfamseq')->get_sequence_length($rfamseq_acc);
			$chrom_sizes_hash{$chromosome_label} = $chrom_size;
		}
	}

} #end of loop through infile
 
close (IN);
close (BED);

#sort BED file chrom then chromStart: sort -k1,1 -k2,2n unsorted.bed > input.bed
my $sortedfile = $dirname . '/' . $upid . "_sorted.bed";
system("sort -k1,1 -k2,2n $bedfile > $sortedfile");

# DO this later - need a script to replace UCSC's fetchChromSizes
#use fetchChromSizes to create chrom.sizes file
#system("/nfs/production/xfam/rfam/software/fetchChromSizes $db > chrom.sizes") and die "Could not create chrom.sizes for $db $!\n";

# generate chrom.sizes file using the chromosome sizes hash generated in the previous step
open (CHRSIZES, ">$chrom_sizes_file") or die "Cannot open file $chrom_sizes_file $!\n";

foreach my $chrom_label (keys %chrom_sizes_hash){
	print CHRSIZES "$chrom_label\t$chrom_sizes_hash{$chrom_label}\n";
}
close (CHRSIZES);

#use bedToBigBed to convert BED to bigBed
my $bigbedfile = $dirname . '/' . $upid . ".bigBed";
system ("/hps/software/users/agb/rfam/bin/bedToBigBed $sortedfile $chrom_sizes_file $bigbedfile") and die "Could not convert BED to bigBed $!\n";

