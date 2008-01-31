#!/software/bin/perl -w

use strict;
use Getopt::Long;
use Bio::SeqFetcher::xdget; #BIOPERL IS EVIL! REPLACE WITH SeqFetch ASAP!
use CMResults;
use Rfam;
use DBI;


my( $thr, 
    $inxfile,
    $list,
    $help, 
    $cove,
#    $fasta,
    $trim,
    $overlaps,
    $file,
    @extrafamily,
    $output);

&GetOptions( "t=s"      => \$thr,
	     "d=s"      => \$inxfile,
	     "l"        => \$list,
	     "overlaps" => \$overlaps,
	     "cove"     => \$cove,
#	     "fa=s"     => \$fasta,
	     "trim=s"   => \$trim,
	     "file=s"         => \$file,
	     "extrafamily=s@" => \@extrafamily,
	     "o|output=s"     => \$output,
	     "h|help"         => \$help );

sub help {
    print STDERR <<EOF;
    rfmake.pl  
    Usage:      rfmake.pl -t <bits> 
                rfmake.pl -l
                          -file <infernal output file> (uses OUTPUT file in current dir by default)
    	                  -l                           option lists hits but does not build ALIGN
			  -d <blastdb>                 use a different blast database for sesquence fetching
			  -overlaps                    do something with overlapping hits
			  -cove                        Sean says 'COVE SUX!', so dont be silly, use Infernal.
			  -trim <?>                    dunno, seems to run filter_on_cutoff() function? 
			  -extrafamily <str>           add an extra family term for making the histograms
			  -o|-output <str>             Output file for the \'-l\' option [Default: out.list]
EOF
}

if( $help ) {
    &help();
    exit(1);
}

not $inxfile and $inxfile = $Rfam::rfamseq;
my $seqinx = Bio::SeqFetcher::xdget->new( '-db' => [$inxfile] );

if (!defined($file)){
    $file = "OUTPUT";
}

if (!defined($output)){
    $output = "out.list";
}

if (!defined($thr)){
    $thr = 5;
}
my $thrcurr = 5;

my ($local, @family_terms, %family_terms);
if( not $overlaps ) {
    open( DESC, "DESC" ) or warn "Can't open DESC to determine global/local requirement\n";
    while( <DESC> ) {
	/^GA\s+(\S+)/ and do {
	    $thrcurr = $1;
	    $thr = $1 if not defined $thr;
	};
	
	/^ID/ || /^DE/ || /^PI/ and do {
	    substr($_,0,3) = "";
	    $_ =~ tr/a-z/A-Z/;
	    my @terms = split(/[\_\s+\/\;\(\)]/,$_);
	    push(@family_terms,@terms);
	};
	
	/^BM\s+cmsearch.*-local.*/ and do {
	    $local = 1;
	};
    }
    close DESC;
}

my %forbidden_family_terms = (
    ARCH => 1,
    ARCHAEA => 1,
    ARCHAEAL => 1,
    BACT => 1,
    BACTERIA => 1,
    BACTERIAL => 1,
    BODY => 1,
    DNA => 1,
    ELEMENT => 1,
    EUK => 1,
    EUKARYOTE => 1,
    EUKARYOTIC => 1,
    EXON => 1,
    FAMILY  => 1,
    GENE => 1,
    GENOME => 1,
    INTRON => 1,
    NUCLEAR => 1,
    PHAGE => 1,
    PLANT => 1,
    PRIMER => 1,
    PROMOTER => 1,
    PROTEIN => 1,
    RNA => 1,
    SEQUENCE => 1,
    SMALL   => 1,
    SUBUNIT => 1,
    TYPE => 1,
    UTR => 1,
    VIRUS => 1
);

foreach my $t (@family_terms) {
    if ($t =~ /\S+/ && (length($t)>1) && $t =~ /[A-Z]/ && !$forbidden_family_terms{$t} && !$family_terms{$t}){
	$family_terms{$t}=1;
    }
}

@family_terms = keys %family_terms;

if (@extrafamily){ #Perl gives a warning if I try using defined(@array)
    push(@family_terms,@extrafamily);
}
my $family_terms = join(", ",@family_terms);
print STDERR "family terms: $family_terms\n";

my @forbidden_terms = qw(repeat repetitive pseudogene transpos);

my (%seedseqs_start,%seedseqs_end);
if( $list ) {
    open( SEED, "SEED" ) or warn "Can't open SEED to determine overlapping hits\n";
    while( <SEED> ) {
	/^(\S+)\/(\d+)\-(\d+)\s+\S+/ and do {
	    my $a = $2;
	    my $b = $3;
	    
	    if ($b<$a){
		my $temp=$a;
		$a = $b;
		$b = $temp;
	    }
	    
	    if( int($a) == $a && $a>0 && int($b) == $b && $b>0 ){
		push(@{$seedseqs_start{$1}},$a);
		push(@{$seedseqs_end{$1}},$b);
	    }
	};
    }
}

my $already;
open( F, $file ) or die;
if( <F> =~ /^\# Rfam/ ) {
    $already = 1;
}
close F;
open( F, $file ) or die;

my $allres = new CMResults;

printf STDERR "Parsing infernal OUTPUT\n";
if( $cove ) {
    $allres -> parse_cove( \*F );
}
else {
    $allres -> parse_infernal( \*F );
}
close F;

if( $trim ) {
    $allres = $allres->filter_on_cutoff( $trim );
}

if( !$already or $trim ) {
    # write a rearranged and slimmed output file
    open( F, ">$file" ) or die;
    $allres -> write_output( \*F );
    close F;
}

my $res = $allres -> remove_overlaps();

if( $list ) {

    my %desc;
    $thr = 0 if( not defined $thr );

    my @goodhits = grep{ $_->bits >= $thr } $res->eachHMMUnit();
    my @allnames = map{ $_->seqname } @goodhits;
    
    # MySQL connection details.
    my $database = $Rfam::embl;
    my $host     = "cbi3";
    my $user     = "genero";
#    my $accession = "AJ489952.1";
    
    # Create a connection to the database.
    my $dbh = DBI->connect(
	"dbi:mysql:$database;$host", $user, "",
	);
    
    # Query to search for the accession and description of uniprot entries with the gene name offered.
    my $query = qq(
           select entry.accession_version, description.description
           from entry, description
           where entry.accession_version=?
           and entry.entry_id=description.entry_id;
   );
    
# Prepare the query for execution.
    my $sth = $dbh->prepare($query);
    
    foreach my $seqid (@allnames) {
	
	# Run the query 
	$sth->execute($seqid);
	
	my $res = $sth->fetchall_arrayref;
	foreach my $row (@$res){
	    $desc{$row->[0]} .= $row->[1];
	}
   }
    $dbh->disconnect;
    
    #OPEN files for R:
    my %filehandles = (
	seed   => \*OUTSEED,
	align  => \*OUTALIGN,
	family => \*OUTFAM,
	forbid => \*OUTFORBID,
	thresh => \*OUTTHRESH
    );
    my %counts;
    
    foreach my $ty (keys %filehandles){
	open( $filehandles{$ty}, ">out.list_$ty\.dat" ) or die("Problem opening out.list_$ty\.dat\n[$!]");
	$counts{$ty}=0;
    }
    
    if ($thrcurr){
	printf OUTTHRESH "$thrcurr\n";
	$counts{'thresh'}++;
    }
    
    open(OUTFILE, ">$output") or die "Could not open $output\n[$!]\n";   
    my $prev_bits = 999999;
    foreach my $unit ( sort { $b->bits <=> $a->bits } $res->eachHMMUnit() ) {
	
	if( not exists $desc{$unit->seqname} ) {
	    $desc{$unit->seqname} = "no description available";
	}
	
	if ( ($unit->bits)<$thrcurr && $thrcurr<=$prev_bits ){
	    printf OUTFILE "***********CURRENT THRESHOLD: $thrcurr bits***********\n";
	}
	
	my $seqlabel = "ALIGN";
	if ( defined($seedseqs_start{$unit->seqname}) ){
	    my $n=$unit->seqname;
	    for (my $i=0; $i<scalar(@{$seedseqs_start{$n}}); $i++){
		my $a = $seedseqs_start{$n}[$i];
		my $b = $seedseqs_end{$n}[$i];
		#print "overlap($a,$b,$unit->start_seq, $unit->end_seq)\n";
		if (overlap($a,$b,$unit->start_seq, $unit->end_seq)){
		    $seqlabel = "SEED";
		    printf OUTSEED "%0.2f\n", $unit->bits;
		    $counts{'seed'}++;
		    last;
		}
	    }
	}
	
	if ($seqlabel =~ /ALIGN/){
	    printf OUTALIGN "%0.2f\n", $unit->bits;
	    $counts{'align'}++;
	}
	
	my $fammatch=0;
	foreach my $ft (@family_terms) {
	    if ($desc{$unit->seqname} =~ m/$ft/i){
		$fammatch=1;
	    }
	}
	
	if ($fammatch){
	    printf OUTFAM "%0.2f\n", $unit->bits;
	    $counts{'family'}++;
	}
	
	my $forbidmatch=0;
	foreach my $ft (@forbidden_terms) {
	    if ($desc{$unit->seqname} =~ m/$ft/i){
		$forbidmatch=1;
	    }
	}
	
	if ($forbidmatch){
	    printf OUTFORBID "%0.2f\n", $unit->bits;
	    $counts{'forbid'}++;
	}
	
	printf OUTFILE "%0.2f\t$seqlabel\t%s\t%d\t%d\t%d\t%d\t%s\n", $unit->bits, $unit->seqname, $unit->start_seq, $unit->end_seq, $unit->start_hmm, $unit->end_hmm, substr($desc{$unit->seqname},0,70);
	$prev_bits = $unit->bits;
    }
    
    #R fails on empty files:
    foreach my $ty (keys %filehandles){
	if ($counts{$ty}==0){
	    my $fh = $filehandles{$ty};
	    printf $fh "0\n";
	    #printf "$filehandles{$ty} $ty counts=$counts{$ty}\n";
	}
    }
    #Run R script, making the out.list.pdf figure:
    system("/software/R-2.6.0/bin/R CMD BATCH --no-save /software/rfam/bin/plot_outlist.R") and die "system call for /software/R-2.6.0/bin/R failed. Check binary exists and is executable.\n";
    close( OUTSEED);
    close( OUTALIGN);
    close( OUTFAM);
    close( OUTFORBID);
    close( OUTFILE);
    
    #Cleanup R files:
    foreach my $ty (keys %filehandles){
	system( "rm out.list_$ty\.dat" ) and die "File cleanup failed [rm out.list_$ty\.dat]\n"; 
    }
    
    exit(0);
}
elsif( $overlaps ) {
    my @ols;
    foreach my $seq ( $res->eachHMMSequence() ) {
	foreach my $unit1 ( $seq->eachHMMUnit() ) {
	    foreach my $unit2 ( $seq->eachHMMUnit() ) {
#		    print "$unit1 $unit2\n";
		next if( $unit1->start_seq == $unit2->start_seq and 
			 $unit1->end_seq   == $unit2->end_seq and
			 $unit1->bits      == $unit2->bits );
		if( ( $unit1->start_seq >= $unit2->start_seq and $unit1->start_seq <= $unit2->end_seq ) or
		    ( $unit1->end_seq   >= $unit2->start_seq and $unit1->end_seq   <= $unit2->end_seq ) ) {
		    my( $score ) = sort { $a<=>$b } ( $unit1->bits, $unit2->bits );
		    push( @ols, { 'score' => $score, 'unit1' => $unit1, 'unit2' => $unit2 } );
		}
	    }
	}
    }
    
    foreach my $ol ( sort { $b->{'score'} <=> $a->{'score'} } @ols ) {
	my $unit1 = $ol->{'unit1'};
	my $unit2 = $ol->{'unit2'};
	
	printf( "%-15s%8d%8d%8d%8d%10s\n", $unit1->seqname, $unit1->start_seq, $unit1->end_seq, $unit1->start_hmm, $unit1->end_hmm, $unit1->bits );
	printf( "%-15s%8d%8d%8d%8d%10s\n\n", "", $unit2->start_seq, $unit2->end_seq, $unit2->start_hmm, $unit2->end_hmm, $unit2->bits );
    }
    exit(0);
}

my $atleastonehit;
open( FA, ">$$.fa" ) or die;
open( SC, ">scores" ) or die;
foreach my $cmseq ( $res->eachHMMSequence() ) {
    foreach my $cmunit ( $cmseq->eachHMMUnit ) {
	next unless $cmunit->bits >= $thr;
	
	my $id    = $cmunit->seqname;
	my $start = $cmunit->start_seq;
	my $end   = $cmunit->end_seq;
	
	my $seq = &get_seq( $id, $start, $end );
	next unless $seq;
	my $seqstr = $seq->seq();
	$seqstr =~ tr/Tt/Uu/;                 # It's RNA dammit! (SRE)
	$seqstr =~ s/(.{1,60})/$1\n/g;
	print FA ">", $seq->id(), "\n$seqstr";
	print SC $cmunit->bits, " $id/$start-$end\n";
	$atleastonehit = 1;
    }
}
close FA;
close SC;

if( !$atleastonehit ) {
    warn "no hits\n";
    exit(0);
}

my $options = "-o ALIGN";
if( $local ) {
    $options = "-l ".$options." --qdb";
}
else {
    $options .= " --hbanded";
}
printf STDERR "Running: cmalign $options CM $$.fa\n";
system "cmalign $options CM $$.fa" and die "failed to run cmalign";

my $tc_bits = $res -> lowest_true( $thr );
my $nc_bits = $res -> highest_noise( $thr );
$nc_bits = "undefined" if( $nc_bits == -100000 );    # hack!

printf STDERR "Updating DESC file\n";
if( -s "DESC" ) {
    open( DNEW, ">DESC.new" ) or die;
    open( DESC, "DESC" ) or die;
    while(<DESC>) {
	if( /^GA\s+/ ) {
	    printf DNEW ( "GA   %.2f\n", $thr );
	    next;
	}
	if( /^TC\s+/ ) {
	    printf DNEW ( "TC   %.2f\n", $tc_bits );
	    next;
	}
	if( /^NC\s+/ ) {
	    if( $nc_bits eq "undefined" ) {
		printf DNEW ( "NC   %s\n", $nc_bits );		
	    }
	    else {
		printf DNEW ( "NC   %.2f\n", $nc_bits );
	    }
	    next;
	}
	print DNEW $_;
    }
    close DESC;
    close DNEW;

    rename( "DESC", "DESC.old" ) or die;
    rename( "DESC.new", "DESC" ) or die;

}

#######################################



sub get_seq {
    my $id    = shift;
    my $start = shift;
    my $end   = shift;
    my $reverse;

    $reverse = 1 if( $end and $end < $start );
    $seqinx->options( '' );    #reset this

    if( $end ) {
	my $options = "";
        my( $getstart, $getend ) = ( $start, $end );
        if( $reverse ) {
            ( $getstart, $getend ) = ( $end, $start );
	    $options .= "-r ";
        }
	$options .= "-a $getstart -b $getend ";
	$seqinx->options( $options );
    }

    my $seq = new Bio::Seq;
    eval {
        $seq = $seqinx -> get_Seq_by_acc( $id );
    };
    if( $@ or not $seq ) {
        warn "$id not found in your seq db\n";
        return 0;       # failure
    }

    if( $end ) {
	$seq->id( $seq->id."/$start-$end" );
    }

    return $seq;
}


######################################################################
sub overlap {
    my($x1, $y1, $x2, $y2) = @_;
    
    if ( ($x1<=$x2 && $x2<=$y1) || ($x1<=$y2 && $y2<=$y1) || ($x2<=$x1 && $x1<=$y2) || ($x2<=$y1 && $y1<=$y2)  ){
        return 1;
    }
    else {
        return 0;
    }
}
