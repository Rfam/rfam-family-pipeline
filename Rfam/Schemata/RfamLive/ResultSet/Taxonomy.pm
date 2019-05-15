package RfamLive::ResultSet::Taxonomy;

use strict;
use warnings;
use Carp;

use base 'DBIx::Class::ResultSet';

use Bio::Rfam::Utils;

# Updates taxonomy table when a family is committed to SVN
# for SEED sequences which have taxids not yet in taxonomy
sub updateTaxonomyFromFamilyObj {
  my ($self, $familyObj, $seed_info_HHR) = @_;
  my $sub_name = "updateTaxonomyFromFamilyObj()";
  
  if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }

  # info we need to do the update is in %{$seed_info_HHR}
  # 1D key is seed sequence name 
  # 2D keys are names of fields in taxonomy table (and rfamseq table)
  # values are what to add to table

  my $i;
  my $seedmsa = $familyObj->SEED;
  my $nseq = $seedmsa->nseq;
  my %added_taxid_H = (); # set to 1 for taxids we've updated so far, 
                          # this is a small optimization, no need to update twice for same taxid 
                          # (we assume all other data is equivalent for equal taxids but we don't check)
  my @row_AH = (); # array of hashes with info to add to taxonomy table
  for($i = 0; $i < $nseq; $i++) { 
    my $seed_nse = $seedmsa->get_sqname($i);
    my ($is_nse, undef, undef, undef, undef) = Bio::Rfam::Utils::nse_breakdown($seed_nse);
    if(! $is_nse) { 
      croak "ERROR in $sub_name, seed sequence name not in name/start-end format ($seed_nse)"; 
    }

    my $ncbi_id = $seed_info_HHR->{$seed_nse}{"ncbi_id"};
    if((! defined $ncbi_id) || ($ncbi_id eq "-")) { 
      croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty ncbi_id value"; 
    }

    # check if ncbi_id is already in the Taxonomy table, if it is we do nothing:
    my $taxonomy_entry = $self->find( { ncbi_id => $ncbi_id},
                                      { key => 'primary' });
    
    if((! defined $taxonomy_entry) && 
       (! defined $added_taxid_H{$ncbi_id})) { 
      $added_taxid_H{$ncbi_id} = 1; # we'll skip this taxid if we see it again
      
      my $species            = $seed_info_HHR->{$seed_nse}{"species"};
      my $tax_string         = $seed_info_HHR->{$seed_nse}{"tax_string"};
      my $tree_display_name  = $seed_info_HHR->{$seed_nse}{"tree_display_name"};
      my $align_display_name = $seed_info_HHR->{$seed_nse}{"align_display_name"};
      
      if((! defined $species) || ($species eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse (ncbi_id: $ncbi_id) has undefined or empty species value"; 
      }
      if((! defined $tax_string) || ($tax_string eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse (ncbi_id: $ncbi_id) has undefined or empty tax_string value"; 
      }
      if((! defined $tree_display_name) || ($tree_display_name eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse (ncbi_id: $ncbi_id) has undefined or empty tree_display_name value"; 
      }
      if((! defined $align_display_name) || ($align_display_name eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse (ncbi_id: $ncbi_id) has undefined or empty align_display_name value"; 
      }
      
      printf("calling update_or_create:\n\tncbi_id: $ncbi_id\n\ttax_string: $tax_string\n\tspecies: $species\n\ttree: $tree_display_name\n\talign: $align_display_name\n\n");
      push(@row_AH, {  ncbi_id            => $ncbi_id,
                       species            => $species, 
                       tree_display_name  => $tree_display_name,
                       align_display_name => $align_display_name,
                       tax_string         => $tax_string } );
      if(scalar(@row_AH) >= 1000) { 
        $self->populate(\@row_AH);
        @row_AH = ();
      } 
    } 
  }
    
  $self->populate(\@row_AH);

  return;
}

1;
