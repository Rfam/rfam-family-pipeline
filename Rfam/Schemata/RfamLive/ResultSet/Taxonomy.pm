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
  my $seen_taxid_H = (); # set to 1 for taxids we've updated so far, 
                         # this is a small optimization, no need to update twice for same taxid 
                         # (we assume all other data is equivalent for equal taxids but we don't check)
  for($i = 0; $i < $nseq; $i++) { 
    my $seed_nse = $seedmsa->get_sqname($i);
    my ($is_nse, undef, undef, undef, undef) = Bio::Rfam::Utils::nse_breakdown($seed_nse);
    if(! $is_nse) { 
      croak "ERROR in $sub_name, seed sequence name not in name/start-end format ($seed_nse)"; 
    }

    my $ncbi_id = $seed_info_HH{$seed_nse}{"ncbi_id"};
    if((! defined $ncbi_id) || ($ncbi_id eq "-")) { 
      croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty ncbi_id value"; 
    }
    if(! defined $seen_taxid_H{$ncbi_id}) { 
      $seen_taxid_H{$ncbi_id} = 1; # we'll skip this taxid if we see it again

      my $species            = $seed_info_HH{$seed_nse}{"species"};
      my $tax_string         = $seed_info_HH{$seed_nse}{"tax_string"};
      my $tree_display_name  = $seed_info_HH{$seed_nse}{"tree_display_name"};
      my $align_display_name = $seed_info_HH{$seed_nse}{"align_display_name"};

      if((! defined $species) || ($species eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty species value"; 
      }
      if((! defined $tax_string) || ($tax_string eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty tax_string value"; 
      }
      if((! defined $tree_display_name) || ($tree_display_name eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty tree_display_name value"; 
      }
      if((! defined $align_display_name) || ($align_display_name eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty align_display_name value"; 
      }
      
      # update table, if an entry already exists with ncbi_id this will update the row, else it will create a new row
      $self->update_or_create({ ncbi_id            => $ncbi_id,
                                species            => $species, 
                                tree_display_name  => $tree_display_name,
                                align_display_name => $align_display_name,
                                tax_string         => $tax_string} );
      
    } # end of 'if(! defined $seen_taxid_H{$ncbi_id})'
  }

  return;
}

1;
