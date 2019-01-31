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
   
	my %pseudoknot_hashes = $self->extract_pseudoknots_from_rscape_sto($rscape_sto);
	my %cov_pseudoknots = $self->search_for_pseudoknot_covariation($pseudoknot_hashes{'ss_cons'}, $pseudoknot_hashes{'cov_ss_cons'});
	
	my $pseudoknot_number = 0;

	if (%cov_pseudoknots){
		foreach my $pseudoknot_id (keys %cov_pseudoknots){
			my @chunks = split("_", $pseudoknot_id);
			my $pk_id = 'pk'.$chunks[2];

			my $resultset = $rfamdb->resultset('Pseudoknot')->find_or_create(
				{rfam_acc => $rfam_acc,
				pseudoknot_id => $pk_id,
 				source => 'seed'},
				{key => 'acc_id_source'});
		
			$resultset->update({covariation => $cov_pseudoknots{$pseudoknot_id},
				   pseudoknot_id => $pk_id,
				   source => 'seed'},
				   {key => 'acc_id_source'});

		} 
	}	

	# Now work on R-scape supported pseudoknots
	my %pseudoknot_hashes_cyk = $self->extract_pseudoknots_from_rscape_sto($rscape_cyk_sto);
	my %cov_pseudoknots_cyk = $self->search_for_pseudoknot_covariation($pseudoknot_hashes_cyk{'ss_cons'}, $pseudoknot_hashes_cyk{'cov_ss_cons'});

	if (%cov_pseudoknots_cyk){
		foreach my $pseudoknot_id (keys %cov_pseudoknots_cyk){
			my @chunks = split("_", $pseudoknot_id);
                        my $pk_id = 'pk'.$chunks[2];

                        my $resultset = $rfamdb->resultset('Pseudoknot')->find_or_create(
                                {rfam_acc => $rfam_acc,
                                pseudoknot_id => $pk_id,
                                source => 'rscape'},
                                {key => 'acc_id_source'});
                
                        $resultset->update({covariation => $cov_pseudoknots_cyk{$pseudoknot_id},
                                   pseudoknot_id => $pk_id,
                                   source => 'rscape'},
                                   {key => 'acc_id_source'});		
		}
	}
}


# -------------------------------------------------------------------


sub extract_pseudoknots_from_rscape_sto {
	my ($self, $input_stk) = @_;

	my %ss_strs = ();
	my %cov_ss_strs = ();

	my %pseudoknot_hashes = ();
	
	open(my $fh_in, '<:encoding(UTF-8)', $input_stk)
        or die "Could not open file '$input_stk' $!";

	my $label;
	
	while (my $row = <$fh_in>) {
		chomp $row;
		if ($row =~ /^(#=GC\s{1}SS_cons_)\d+/) {
			# split line in label and SS string
			my @line_chunks=split(" ", $row);

			$label = $line_chunks[1];

			if (!exists $ss_strs{$label}){
                                $ss_strs{$label} = $line_chunks[2];
                        }

			# append psudoknot ss line to existing chunk
			else {
				$ss_strs{$label}.$line_chunks[2];
			}
		}
		elsif ($row =~ /^(#=GC\s{1}cov_SS_cons_)\d+/) {
			my @line_chunks=split(" ", $row);

			$label = $line_chunks[1];

			if (!exists $cov_ss_strs{$label}){
				$cov_ss_strs{$label} = $line_chunks[2];
			}
			else{
				$cov_ss_strs{$label}.$line_chunks[2];
			}
			
		}
		
	}

	close($fh_in);
	
	$pseudoknot_hashes{'ss_cons'} = \%ss_strs;
	$pseudoknot_hashes{'cov_ss_cons'} = \%cov_ss_strs;
	
	return %pseudoknot_hashes;
}

# -------------------------------------------------------------------

sub search_for_pseudoknot_covariation {
	my ($self, $ss_strs, $cov_ss_strs) = @_;

	# covariation hash
	my %pseudoknot_cov = ();
	
	my $idx = -1;
	my $cov_str;

	foreach my $pseudoknot_label (keys %{$ss_strs}){
		# find first pseudoknot bracket
		$idx = index($ss_strs->{$pseudoknot_label},'<');	
		my @pseudoknot_str = split(//, $ss_strs->{$pseudoknot_label});
		$cov_str = $cov_ss_strs->{"cov_".$pseudoknot_label};
		my @cov_array = split(//, $cov_str);

		# initialize to 0
		$pseudoknot_cov{$pseudoknot_label} = 0;
		
		if ($cov_array[$idx] eq '2'){
			$pseudoknot_cov{$pseudoknot_label} = 1;	
			next;
		}	 
		else{
			my $str_len = length($ss_strs->{$pseudoknot_label});
			while ($idx < $str_len){
				 if (($pseudoknot_str[$idx] eq '<') && ($cov_array[$idx] eq '2')){
					$pseudoknot_cov{$pseudoknot_label} = 1;
					
					# terminate inner loop if covariation found
					last if (($pseudoknot_str[$idx] eq '<') && ($cov_array[$idx] eq '2'));
				}
				$idx+=1;
				
			}
		}	

	}

	return %pseudoknot_cov;

}

-1;
