#! /software/bin/perl -w

# A program to take sequences from either a fasta file or a list of ids (n/s-e) and build a SEED.new file using cmalign

use strict;
use Getopt::Long;
use SeqFetch;
use Rfam::RfamAlign;
use Bio::SimpleAlign;
use Rfam::SS;

my ($seqfile, $idfile, $iter, $help);

&GetOptions("f|s|seqfile=s"         => \$seqfile,
            "id|idfile=s"           => \$idfile,
	    "i|iter|iterate"        => \$iter,
	    "h|help"                => \$help
    );

if( $help || (defined($idfile) && defined($seqfile)) || (!defined($idfile) && !defined($seqfile) && !defined($iter)) || !(-e "SEED") ) {
    &help();
    exit(1);
}

if (defined($idfile)){
    
    print "reading: $idfile\n";
    open( ID, "< $idfile" ) or die "$idfile exists but can't be opened\n[$!]";
    
    my $seqCount=0;
    my (%forward, %reverse);
    while( my $line = <ID> ) {
	my ($valid, $name, $start, $end);
	next if $line =~ /^\#/;
	chomp($line);
	print "read: [$line]\n";
	if ($line =~ /(\S+)\/(\d+)\-(\d+)/){
	    $name = $1;
	    $start = $2;
	    $end = $3;
	    $valid=1;
	}
	elsif  ($line =~ /(\S+)\s+(\d+)\s+(\d+)/){
	    $name = $1;
	    $start = $2;
	    $end = $3;
	    $valid=1;
	}
# 	elsif  ($line =~ /(\S+)\t(\d+)\t(\d+)/){
# 	    $name = $1;
# 	    $start = $2;
# 	    $end = $3;
# 	    $valid=1;
#	}
	
	if (defined($valid) && $start < $end ){
	    print "adding: $name/$start\-$end:+1\n";
	    push( @{ $forward{$name} }, { 'start'  => $start,
					  'end'    => $end} );
	    $seqCount++;
	}
	elsif (defined($valid) && $start > $end ){
	    print "adding: $name/$start\-$end:-1\n";
	    push( @{ $reverse{$name} }, { 'start'  => $end,
					  'end'    => $start} );
	    $seqCount++;
	}
	
    }
    
    die "FATAL: failed to find any valid regions in [$idfile]!" if $seqCount==0;
    $seqfile = $idfile . "\.fa";
    open( FA, ">$seqfile" ) or die;
    SeqFetch::fetchSeqs(\%forward, $Rfam::rfamseq, 0, \*FA);
    SeqFetch::fetchSeqs(\%reverse, $Rfam::rfamseq, 1, \*FA);
    close(FA) || die "Could not close fasta file:[$!]\n";
    
}

if (-e "SEED\.new"){
    print "WARNING: SEED.new exists, moving it sideways to SEED.new_moved_sideways\n";
    system("mv SEED.new SEED.new_moved_sideways");
}


system("/software/rfam/share/infernal-1.0/bin/cmbuild -F CM.10 SEED > cmbuild.out") and die("FATAL: Error in: [/software/rfam/share/infernal-1.0/bin/cmbuild -F CM.10 SEED > cmbuild.out].\n");

if (defined($iter)){
    $seqfile = "seed.fa";
    system("sreformat fasta SEED > $seqfile");
    open( SD, "SEED" ) or die ("FATAL: Couldn't open SEED [$!]\n $!\n");
    my $seed = new Rfam::RfamAlign;
    $seed -> read_stockholm( \*SD );
    close(SD);
    my @list = $seed->each_seq();
    my $self  = new Rfam::RfamAlign;

    foreach my $seqobj ( @list ) {
	
	my $seq = new Bio::LocatableSeq( '-seq'   => $seqobj->seq,
				     '-id'    => "DELME" . $$ . "." . $seqobj->id,
				     '-start' => $seqobj->start,
				     '-end'   => $seqobj->end, 
				     '-type'  => 'aligned'
	    );
        $self -> add_seq($seq);
    }
    my $ss_cons = $seed->ss_cons->getInfernalString();
    my $ss = new Rfam::SS;
    $ss -> parseInfernalString( $ss_cons );
    
    $self -> ss_cons( $ss );
    my $len = length($list[0]->seq); 
    my $tmpseed = "/tmp/$$.SEED";
    open(SDOUT, ">$tmpseed" ) or die ("FATAL: Couldn't open $tmpseed\n[$!]");
    Rfam::RfamAlign::write_stockholm($self, \*SDOUT, $len);
    close(SDOUT);
    system("/software/rfam/share/infernal-1.0/bin/cmalign --withpknots --withali $tmpseed -o /tmp/$$.SEED.new CM.10 $seqfile > SEED.new.scores") and die( "FATAL: Error in [/software/rfam/share/infernal-1.0/bin/cmalign --withpknots --withali $tmpseed -o /tmp/$$.SEED.new CM.10 $seqfile > SEED.new.scores].\n[$!]");
    system("sreformat --pfam stockholm /tmp/$$.SEED.new | grep -v ^DELME$$\. > /tmp/$$.SEED.new2" ) and die( "FATAL: Error in [sreformat --pfam stockholm /tmp/$$.SEED.new | grep -v ^DELME$$\. > /tmp/$$.SEED.new2]\n[$!]");
    system("sreformat --pfam stockholm /tmp/$$.SEED.new2 > SEED.new") and die( "FATAL: Error in [sreformat --pfam stockholm /tmp/$$.SEED.new2 > SEED.new]\n[$!]");
    printf "Updated alignment and scores: SEED.new & SEED.new.scores\n";
#    system("/software/rfam/extras/infernal-0.81/src/cmalign -o SEED.new CM.81 $seqfile") and die( "FATAL: Error in [/software/rfam/extras/infernal-0.81/src/cmalign -o SEED.new CM.81 $seqfile].\n");
}
elsif (defined($seqfile)) {
    system("/software/rfam/share/infernal-1.0/bin/cmalign --withpknots --withali SEED -o /tmp/$$.SEED.new.tmp CM.10 $seqfile") and die( "FATAL: Error in [/software/rfam/share/infernal-1.0/bin/cmalign --withpknots --withali SEED -o /tmp/$$.SEED.new.tmp CM.10 $seqfile].\n[$!]");
    open(SR, "sreformat --pfam stockholm /tmp/$$.SEED.new.tmp |") or die "FATAL: failed to open pipe [sreformat --pfam stockholm /tmp/$$.SEED.tmp]\n[$!]";
    open(SD, "> SEED.new") or die "FATAL: failed to open SEED.new\n[$!]";
    while (<SR>){
	chomp;
	if(/(\S+):1(\s+\S+)/){
	    print SD "$1  $2\n";
	}
	elsif(/(\S+\/)(\d+)-(\d+):-1(\s+\S+)/){
	    print SD "$1$3-$2   $4\n";
	}
	else {
	    print SD "$_\n";
	}
	
    }
    close(SD);
    close(SR);
    
}
else {
    help();
}

exit();

######################################################################
sub help {
    
    print STDERR <<EOF;

addseqs2seed.pl - reads in either a fasta sequence file or a file of sequence ids and coordinates 
                - this can be either tab-delimited or in n/s-e format, one entry per line. 
		The sequences are aligned to the SEED file in the current directory using cmalign.
		Alternatively, \47--iterate\47 will strip sequences from the SEED and realign each 
		to the CM.

Usage:   addseqs2seed.pl -s  seqfile.fa
         addseqs2seed.pl -id  idfile
	 addseqs2seed.pl -iterate
Options:       
-h or -help                    show this help
  -f|-s|-seqfile  <seqfile>    add sequences in seqfile to SEED
  -id|-idfile     <idfile>     add sequences corresponding to n/s-e\47s to SEED
  -i|-iter|-iterate            iteratively realign SEED sequences to the CM. \47Someone\47 needs to implement 
                               a metric comparing the original and resulting alignments/structures! For now use
			       rqc-ss-cons.pl
EOF
}







