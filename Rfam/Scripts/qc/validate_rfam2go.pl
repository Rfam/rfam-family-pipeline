#!/usr/bin/env perl
#
# check rfam2go for obsolete/secondary/unknown GO terms
BEGIN {
	use lib "../common/";
}
use strict;
use warnings;
use Bio::Rfam::GOA::GOTermChecker;

($#ARGV == 2) or die "Usage: perl ",__FILE__," user pass external2go\n";
my ($dbUser, $dbPassword, $external2go) = @ARGV;

open EXT2GO, "<$external2go" or die "Unable to open $external2go for reading\n";

Bio::Rfam::GOA::GOTermChecker::prologue($dbUser, $dbPassword);

while (<EXT2GO>) {
	if (/^(Rfam:RF[0-9]{5}).* > GO:(.*) ;.*(GO:[0-9]{7})$/) {
		Bio::Rfam::GOA::GOTermChecker::check_term($1, $3, $2);
	}
}

close EXT2GO;

Bio::Rfam::GOA::GOTermChecker::epilogue();
