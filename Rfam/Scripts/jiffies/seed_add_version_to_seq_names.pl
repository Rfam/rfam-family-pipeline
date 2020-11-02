#!/usr/bin/env perl
#
# seed_add_version_to_seq_names.pl
use strict;
use warnings;

use Bio::Rfam::Config;
use Bio::Rfam::FamilyIO;
use Bio::Rfam::QC;
use Bio::Rfam::SVN::Client;
use Bio::Rfam::Utils;

use Sys::Hostname;
use File::stat;
use File::Spec;
use Carp;

use Digest::MD5 qw(md5_hex);
use LWP::Simple;
use JSON qw( decode_json );
use XML::LibXML;
use Time::HiRes qw(usleep);

use Cwd;
use Data::Dumper;
use Mail::Mailer;
use File::Copy;
use vars qw( @ISA
             @EXPORT
);

use Getopt::Long;

my $usage  = "Usage:\nperl seed_add_version_to_seq_names.pl <alifile>\n";

my $alifile = undef; # single command line arg

#my $options_okay = &GetOptions("a" => \$a_opt);

my $exit_early = 0;
#if(! $options_okay) { 
#  printf("ERROR, unrecognized option;\n\n"); 
#  $exit_early = 1;
#}
if(scalar(@ARGV) != 1) { 
  $exit_early = 1;
}

if($exit_early) { 
  printf $usage;
  exit 0;
}

$alifile = ($ARGV[0]);

#print "$alifile\n";

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

my $seed = Bio::Easel::MSA->new({
  fileLocation => $alifile,
  isDna => 1});  

for(my $i = 0; $i < $seed->nseq; $i++) { 
  my $seed_name = $seed->get_sqname($i);
  my ($is_nse, $name, $start, $end, $str) = Bio::Rfam::Utils::nse_breakdown($seed_name);
  if(! $is_nse) { 
    die "ERROR seed sequence $seed_name is not in name/start-end format";
  }

  my ($have_source_seq, $fetched_seqname) = genbank_nse_get_accession_version($seed_name, 10, undef);
  if(! $have_source_seq) { 
    die "ERROR seed sequence $seed_name was not found in GenBank";
  }

  my ($is_accver, $acc, $ver) = Bio::Rfam::Utils::accession_version_breakdown($name); # not $seed_name, that includes '/start-end'
  if(! $is_accver) { 
    # $name is not in accession.version format, so it MUST just be a GenBank accession, else the
    # genbank_nse_get_accession_version() call above would have failed
    # rename the seq
    my $new_nse = $fetched_seqname . "/" . $start . "-" . $end;
    $seed->set_sqname($i, $new_nse);
  }
}

$seed->write_msa("STDOUT", "stockholm", 0);

exit 0;


#-------------------------------------------------------------------------------
=head2 genbank_nse_get_accession_version
  Title    : genbank_nse_get_accession_version
             derived from Bio::Rfam::Utils::genbank_nse_lookup_and_md5
  Incept   : EPN, Wed Aug 26 15:33:34 2020
  Function : Looks up a sequence in GenBank and returns its accession.version
  Args     : $nse:       sequence name in name/start-end format
           : $nattempts: number of attempts to make to fetch the sequence
           :             (if this is being run in parallel it can cause failure
           :              due (presumably) to overloading NCBI in some way.)
           :             can be undef, in which case set to '1'
           : $nseconds:  number of seconds to wait between attempts
           :             can be undef, in which case set to '3'
  Returns  : 3 values:
           : $have_source_seq: '1' if source sequence is in GenBank, else '0'
           : $fetched_name:    name of fetched seq from GenBank, should be accession.version
  Dies     : if $nse is not in valid name/start-end format
=cut

sub genbank_nse_get_accession_version { 
  my ( $nse, $nattempts, $nseconds ) = @_;
  
  my ( $is_nse, $name, $start, $end, $strand ) = Bio::Rfam::Utils::nse_breakdown($nse);
  if(! $is_nse) {
    die "ERROR, in genbank_nse_lookup_and_md5() $nse not in name/start-end format.\n";
  }
  if(! defined $nattempts) { $nattempts = 1; }
  if(! defined $nseconds)  { $nseconds  = 3; }
  
  # $nse will have end < start if it is negative strand, but we can't fetch from ENA
  # with an end coord less than start, so if we are negative strand, we need to fetch
  # the positive strand, and then revcomp it later.
  my $qstart = ($strand == 1) ? $start : $end;
  my $qend   = ($strand == 1) ? $end   : $start;
  my $qlen   = abs($start - $end) + 1;

  # initialize default values, which will change below if we have a valid subseq
  my $successful_fetch = 0; # possibly changed to '1' below
  my $have_source_seq  = 0; # possibly changed to '1' below
  my $fetched_seqname  = undef; # updated to fetched_seqname below

  my $url = sprintf("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=%s&rettype=fasta&retmode=text&from=%d&to=%d", $name, $qstart, $qend);
  my $got_url = get($url);

  if(! defined $got_url) {
    # if NCBI is being hit by a bunch of requests, the get() command
    # may fail in that $got_url may be undefined. If that happens we
    # wait a few seconds ($nseconds) and try again (up to
    # $nattempts) times
    my $attempt_ctr = 1;
    while((! defined $got_url) && ($attempt_ctr < $nattempts)) {
      sleep($nseconds);
      $got_url = get($url);
      $attempt_ctr++;
    }
    if(($attempt_ctr >= $nattempts) && (! defined $got_url)) {
      croak "ERROR trying to fetch sequence info for $name from genbank, reached maximum allowed number of attempts ($nattempts)";
    }
  }
  elsif($got_url !~ m/^>/) {
    # this shouldn't happen, if the sequence doesn't exist then $got_url should be undefined
    die "ERROR in genbank_nse_lookup_and_md5() get() returned a value that is not a sequence";
  }
  else {
    # if we get here: we know that $got_url is defined and starts with a ">",
    # so we know that a sequence named $name exists in GenBank
    $have_source_seq = 1;

    # the fetched sequence should have a header line with a name in this format:
    # >$name:$qstart-$qend
    # if this is not the case, then either the sequence start or end were out of bounds
    # (longer than the sequence length of the fetched sequence)
    my @got_url_A = split(/\n/, $got_url);
    foreach my $got_url_line (@got_url_A) {
      if($got_url_line =~ /^>(\S+)\:(\d+)\-(\d+)/) {
        $fetched_seqname = ($1);
      }
    }
  }

  return ($have_source_seq, $fetched_seqname);
}
