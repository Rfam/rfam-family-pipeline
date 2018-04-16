package RfamLive::ResultSet::Rfamseq;

use strict;
use warnings;
use Carp;
use utf8;

use base 'DBIx::Class::ResultSet';

sub seqaccToTaxon {
  my ($self, $acc) = @_;
  
  my $row = $self->find({ rfamseq_acc => $acc},
                        { join => 'ncbi',
                          '+select' => ['ncbi.ncbi_id', 'ncbi.species'],
                          '+as'     => ['taxid', 'species'] });
                          
  return (defined($row) ? $row : undef);
}


# to be used 
sub get_sequence_length {
	my ($self, $rfamseq_acc) = @_;

	my $rfamseq_row = $self->find({rfamseq_acc => $rfamseq_acc});
	my $seq_length = $rfamseq_row->get_column('length');

	return $seq_length;
}

1;
