#!/usr/bin/env perl

use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::QC;
use Bio::Rfam::SVN::Client;
use Bio::Rfam::Utils;

my $accn = shift;

unless(defined($accn)){
  die "Please provide a GenBank accession\n";
}
print "$accn\n";


my @name_A = ("$accn");

my %info_HH = ();

Bio::Rfam::Utils::genbank_fetch_seq_info(\@name_A, \%info_HH);

exit 0;


