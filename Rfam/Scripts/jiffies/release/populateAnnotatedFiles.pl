#!/usr/bin/env perl

use warnings;
use strict;
use IO::Compress::Gzip qw(gzip $GzipError);
use Bio::Rfam::FamilyIO;
use Bio::Rfam::Family::CM;
use Bio::Rfam::Config;
use Bio::Rfam::SVN::Client;
use RfamLive;

#
my $config = Bio::Rfam::Config->new;
my $client = Bio::Rfam::SVN::Client->new({config => $config});
my $family = $ARGV[0];
my $cm_dir = $ARGV[1];
my $seed_dir = $ARGV[2];
my $CMFILE = "$family.cm";
my $seedFile = "$family.seed";

# Create a new connection to RfamLive

my $rfam_db = $config->rfamlive;

my $cm_file_path = $cm_dir.'/'.$CMFILE;
my $seed_file_path = $seed_dir.'/'.$seedFile;

my $cmGzipped;
my $seedGzipped;

# gzip files
gzip $cm_file_path => \$cmGzipped;
gzip $seed_file_path => \$seedGzipped;

#my $db_handle = $rfam_db->resultset('AnnotatedFile')->find({rfam_acc=> $family});
	
#delete if in DB
#if($db_handle){
#	$db_handle->delete;
#}
#create a new entry
#else{
$rfam_db->resultset('AnnotatedFile')->update_or_create({  rfam_acc => $family,
                                			  seed => $seedGzipped,
                           				  cm => $cmGzipped, 
                           			     });
#}
                           
exit;
        
