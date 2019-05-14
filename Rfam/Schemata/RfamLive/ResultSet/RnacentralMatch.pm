package RfamLive::ResultSet::RnacentralMatch;

use strict;
use warnings;
use Carp;

use base 'DBIx::Class::ResultSet';

use Bio::Rfam::Utils;

# Updates rnacentral_matches table when a family is committed to SVN
# for SEED sequences which may be in rnacentral
sub updateRnacentralMatchesFromFamilyObj {
  my ($self, $familyObj) = @_;
  my $sub_name = "updateRnacentralMatchesFromFamilyObj";
  
  if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }
  
  my $i;
  my $seedmsa = $familyObj->SEED;
  my $nseq = $seedmsa->nseq;
  for($i = 0; $i < $nseq; $i++) { 
    my $seed_nse = $seedmsa->get_sqname($i);
    my ($is_nse, $seed_name, $seed_start, $seed_end, undef) = Bio::Rfam::Utils::nse_breakdown($seed_nse);
    if(! $is_nse) { 
      croak "ERROR in $sub_name, seed sequence name not in name/start-end format ($seed_nse)"; 
    }

    my $seed_msa_seq = $seedmsa->get_sqstring_unaligned($i);
    my $seed_md5 = Bio::Rfam::Utils::md5_of_sequence_string($seed_msa_seq);
    
    # lookup in RNAcentral
    my ($rnacentral_has_exact_seq, $rnacentral_md5, $rnacentral_id, undef) = Bio::Rfam::Utils::rnacentral_md5_lookup($seed_md5);

    if($rnacentral_has_exact_seq) { 
      # update table if this entry already exists, else, create a new one
      $self->update_or_create(
        { rfamseq_acc        => $seed_name,
          seq_start          => $seed_start,
          seq_end            => $seed_end,
          md5                => $seed_md5,
          rnacentral_id      => $rnacentral_id,
          type               => "seed"},
        { key => 'acc_start_end_id' });
    }
  }

  return;
}

1;
