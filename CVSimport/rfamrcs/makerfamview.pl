#!/usr/local/bin/perl -w

BEGIN {
    $rfam_mod_dir = 
        (defined $ENV{'RFAM_MODULES_DIR'})
            ?$ENV{'RFAM_MODULES_DIR'}:"/pfam/db/Rfam/scripts/Modules";
    $bioperl_dir =
        (defined $ENV{'BIOPERL_DIR'})
            ?$ENV{'BIOPERL_DIR'}:"/pfam/db/bioperl";
}

use lib $bioperl_dir;
use lib $rfam_mod_dir;

use strict;
use Rfam;
use Rfam::RfamAlign;

my $acc = shift;
chdir "$Rfam::current_dir/$acc" or die;

my @ann;
open( DESC, "DESC" ) or die;
while( <DESC> ) {
    unless( /^\*\*\s+/ ) {
	push( @ann, "#=GF $_" );
    }
}
close DESC;

foreach my $file ( @Rfam::align_file_set ) {
    my $aln = new Rfam::RfamAlign;
    open( ALN, $file ) or die;
    $aln -> read_stockholm( \*ALN );
    close ALN;
    my $numseq = scalar ( $aln -> eachSeq() );

    open( ALNOUT, ">$file.ann" ) or die;

    my $seen;
    open( REF, "sreformat --mingap stockholm $file |" ) or die;
    while( <REF> ) {
	next if( /^\#=GF AU / );
	if( /^\#=G/ and not $seen ) {
	    print ALNOUT @ann;
	    print ALNOUT "#=GF SQ   $numseq\n";
	    $seen = 1;
	}
	elsif( /^\S+\/\d+-\d+/ and not $seen ) {
	    print ALNOUT @ann;
	    print ALNOUT "#=GF SQ   $numseq\n\n";
	    $seen = 1;
	}
	print ALNOUT;
    }
    close REF or die;
    close ALNOUT;
}


# copy web based stuff around

system("cp -f $Rfam::current_dir/$acc/ALIGN /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/full/$acc.full");
system("gzip -f /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/full/$acc.full");

system("/pfam/db/Rfam/scripts/wwwrelease/new_parse_rfam.pl --input_dir /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data --output_dir  /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/markup_align --file_type full --ss_cons_only --family $acc ");

system("cp -f $Rfam::current_dir/$acc/SEED /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/seed/$acc.full");
system("gzip  -f /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/seed/$acc.full");

system("/pfam/db/Rfam/scripts/wwwrelease/new_parse_rfam.pl --input_dir /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data --output_dir /nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/markup_align --file_type seed --family $acc");


if( ! -e "$Rfam::current_dir/$acc/todo.view" ) {
    warn("For $acc, there is no todo.view file. Cannot remove");
} else {
    unlink("$Rfam::current_dir/$acc/todo.view");
}

system("pfabort -u VIEW $acc");
