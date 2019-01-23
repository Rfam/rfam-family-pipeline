package Bio::Rfam::View::Plugin::Pseudoknots;

use Data::Dumper;
use Moose;
with 'MooseX::Role::Pluggable::Plugin';
use IO::Compress::Gzip qw(gzip $GzipError);
use Bio::Easel::MSA;
use File::Slurp;
use File::Path;
use SVG;
use SVG::Parser;
use File::Temp qw( tempdir );

use Bio::Rfam::FamilyIO;
use Bio::Rfam::Utils;
use Data::Dumper;

has foo => (
  is  => 'rw',
  isa => 'Int'
);

sub process {
  my $self = shift;
  $self->populatePseudoknots;
}


sub populatePseudoknots{

    my ($self) = @_;

	my $config = $self->_mxrp_parent->config;
  	my $rfamdb = $config->rfamlive;
  	my $rfam_acc = $self->_mxrp_parent->family->DESC->AC;
 	my $location = tempdir( CLEANUP => 1 );
	my $outdir = "$location";
	my $seed_loc = "$outdir/SEED";
	my $new_seed_loc = "$outdir/SEED_clean";
	my $msa = $self->_mxrp_parent->family->SEED;
  	my $rfam_id = $self->_mxrp_parent->family->DESC->ID;

	$msa->write_msa($seed_loc);

	my $grep_cmd = "grep -v \"^#=GF\" $seed_loc > $new_seed_loc";
	system ($grep_cmd);
	system ("mv $new_seed_loc $seed_loc");
	
	#look for a family entry in the database
	my $famRow = $rfamdb->resultset('Family')->find( { rfam_acc => $rfam_acc } );
	if (!defined($famRow)) {
		croak ("Failed to find entry in the Family table for $rfam_acc.");
	}
		                                	
	my $rscape_exec = $config->config->{binLocation} . '/R-scape';
	my $rscape_cmd = "$rscape_exec --outdir $outdir -s --cyk $seed_loc";
	print "Making rscape image for $rfam_acc\n";
	system ($rscape_cmd);
	
	if ($? == -1) {
		croak ("Failed to generate rscape images for $rfam_acc!\n");
	 }
		                                					        		                            	
	my $rscape_sto = "$outdir/$rfam_id.R2R.sto";               
        if (not -e $rscape_sto){
		$rscape_sto = "$outdir/SEED_1.R2R.sto";
       	}
	my $rscape_cyk_sto = "$outdir/$rfam_id.cyk.R2R.sto";	
	if (not -e $rscape_cyk_sto){	
		$rscape_cyk_sto = "$outdir/SEED_1.cyk.R2R.sto";	
	}

	# Find any SEED pseudoknots first
    	my %pseudoknots = $self->extract_pseudoknots_from_file($rscape_sto);
	if (%pseudoknots){
		foreach my $pseudoknot_id (keys %pseudoknots){
			my $resultset = $rfamdb->resultset('Pseudoknot')->find_or_create(
				{rfam_acc => $rfam_acc,
				pseudoknot_id => $pseudoknot_id,
 				source => 'seed'},
				{key => 'acc_id_source'});
		
			$resultset->update({covariation => $pseudoknots{$pseudoknot_id},
				   pseudoknot_id => $pseudoknot_id,
				   source => 'seed'},
				   {key => 'acc_id_source'});

		} 
	}	

	# Now work on R-scape supported pseudoknots
	my %pseudoknots_cyk = $self->extract_pseudoknots_from_file($rscape_cyk_sto);
	if (%pseudoknots){
		foreach my $pseudoknot_id (keys %pseudoknots_cyk){
                        my $resultset = $rfamdb->resultset('Pseudoknot')->find_or_create(
                                {rfam_acc => $rfam_acc,
                                pseudoknot_id => $pseudoknot_id,
                                source => 'rscape'},
                                {key => 'acc_id_source'});
                
                        $resultset->update({covariation => $pseudoknots_cyk{$pseudoknot_id},
                                   pseudoknot_id => $pseudoknot_id,
                                   source => 'rscape'},
                                   {key => 'acc_id_source'});		
		}
	}
}




sub extract_pseudoknots_from_file{

	my ($self, $input_stk) = @_;
	
	my %pseudoknots = ();
	my %cov_ss_cons_strs = ();
	my %ss_cons_strs = ();
	
	open(my $fh_in, '<:encoding(UTF-8)', $input_stk)
	or die "Could not open file '$input_stk' $!";

	my $pseudoknot_number = 0;
	my $ss_cons_str;
	my $cov_ss_cons_str;
	

	while (my $row = <$fh_in>) {
		chomp $row;
		# look for a pseudoknot
		if ($row =~ /^(#=GC\s{1}SS_cons_)\d+/) {
			# get pseudoknot number
			my @line_chunks=split(" ", $row);
			$ss_cons_str = $line_chunks[1];
			$ss_cons_strs{$ss_cons_str} = '';

		}

		# store pseudoknots with covariation temporarily
		elsif($row =~ /^(#=GC\s{1}cov_SS_cons_)\d+/){
			my @line_chunks=split(" ", $row);
			$cov_ss_cons_str = $line_chunks[1];
			$cov_ss_cons_strs{$cov_ss_cons_str} = '';
		}
	}

	close($fh_in);

	#now assign covariation to psuedoknots
	foreach my $pseudoknot (keys %ss_cons_strs){
		my @chunks = split("_", $pseudoknot);
		$pseudoknot_number = $chunks[2];
		$pseudoknots{"pk".$pseudoknot_number} = 0;

		if (exists $cov_ss_cons_strs{"cov_".$pseudoknot}){
			$pseudoknots{"pk".$pseudoknot_number} = 1;

		}

	}

	return %pseudoknots;

}


-1;
