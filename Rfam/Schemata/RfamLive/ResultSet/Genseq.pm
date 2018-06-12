
package RfamLive::ResultSet::Genseq;

use strict;
use warnings;
use Carp;
use utf8;

use base 'DBIx::Class::ResultSet';

# TO DO: need to simplify the code and add more checks

sub get_chromosome_label_for_genome_browser_hub {
  my ($self, $upid, $rfamseq_acc, $rel_version) = @_;

  my $chromosome_label='';

  # check if the rfamseq_acc exists in Genseq table
  my $rfamseq_acc_entry = $self->find({rfamseq_acc => $rfamseq_acc,
                                          upid => $upid,
					  version => $rel_version});
  # if no entry found, return empty string
  if(!defined($rfamseq_acc_entry)){
      #croak("No entry found in Genseq for rfamseq_acc: $rfamseq_acc");
      return $chromosome_label;
  }

  else{

    # fetch column values
    my $chromosome_name = $rfamseq_acc_entry->get_column('chromosome_name');
    my $chromosome_type = $rfamseq_acc_entry->get_column('chromosome_type');

    # 1. check if chromosome name and chromosome type are null and return an empty string
    if ($chromosome_name eq '' or $chromosome_type eq ''){
      #croak("No chromosome label could be created for rfamseq_acc $rfamseq_acc");
      return $chromosome_label;
    }
    
    # construct chromosome label
    else{
      $chromosome_label = "chr" . $chromosome_name;
    }
  }

  return $chromosome_label;
 }

1;
