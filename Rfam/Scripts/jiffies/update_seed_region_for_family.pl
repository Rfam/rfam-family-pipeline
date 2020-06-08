#!/usr/bin/env perl

use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::SVN::Client;
use Data::Printer;

my $family = shift;

unless(defined($family)){
  die "Please provide a family\n";
}
print "$family\n";

my $config = Bio::Rfam::Config->new;
my $familyIO = Bio::Rfam::FamilyIO->new;
my $rfamdb = $config->rfamlive;
my $client = Bio::Rfam::SVN::Client->new({config => $config});

#Need to put a transaction around this block
my $guard = $rfamdb->txn_scope_guard;

#my $familyObj = $familyIO->loadRfamFromSVN($family, $client);
my $familyObj = $familyIO->loadRfamFromSVN_preSEED($family, $client);
print STDERR "Successfully loaded SVN copy of $family through middleware\n";

# call subroutine that we modified to additionally calculate md5s
$rfamdb->resultset('SeedRegion')->updateSeedRegionsFromFamilyObj( $familyObj );

$guard->commit;

exit 0;
