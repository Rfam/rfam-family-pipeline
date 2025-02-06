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

sub get_sequence_length {
	my ($self, $rfamseq_acc) = @_;

  my $seq_length=0;
	my $rfamseq_row = $self->find({rfamseq_acc => $rfamseq_acc});
	$seq_length = $rfamseq_row->get_column('length');

	return $seq_length;
}

# Updates rfamseq table when a family is committed to SVN 
# for SEED sequences which are not yet in rfamseq
sub updateRfamseqFromFamilyObj {
  my ($self, $familyObj, $seed_info_HHR) = @_;
  my $sub_name = "updateRfamseqFromFamilyObj()";
  
  if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }

  # info we need to add to the table is in %{$seed_info_HHR}
  # 1D key is seed sequence name
  # 2D keys are names of most of the fields in rfamseq table (see code below)
  # values are what to add to table

  my $i;
  my $seedmsa = $familyObj->SEED;
  my $nseq = $seedmsa->nseq;
  my @row_AH = (); # array of hashes with info to add to rfamseq table
  my %seed_names; # hash of seed_names to avoid creating duplicate rfamseq entries
  for($i = 0; $i < $nseq; $i++) { 
    my $seed_nse = $seedmsa->get_sqname($i);
    my ($is_nse, $seed_name, undef, undef, undef) = Bio::Rfam::Utils::nse_breakdown($seed_nse);
    if(! $is_nse) { 
      croak "ERROR in $sub_name, seed sequence name not in name/start-end format ($seed_nse)"; 
    }

    if (! exists $seed_names{$seed_name}) {
        $seed_names{$seed_name} = 1;
    } else {
        next;
    }

    # check if sequence is already in the Rfamseq table, if it is we do nothing:
    my $rfamseq_entry = $self->find( { rfamseq_acc => $seed_name},
                                     { key => 'primary' });
    if(! defined $rfamseq_entry) { 
      # sequence is not yet in rfamseq, add it

      my $ncbi_id     = $seed_info_HHR->{$seed_nse}{"ncbi_id"};
      my $description = $seed_info_HHR->{$seed_nse}{"description"};
      my $length      = $seed_info_HHR->{$seed_nse}{"length"};
      my $mol_type    = $seed_info_HHR->{$seed_nse}{"mol_type"};
      my $source      = $seed_info_HHR->{$seed_nse}{"source"};

      if((! defined $ncbi_id) || ($ncbi_id eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty ncbi_id value"; 
      }
      if((! defined $description) || ($description eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty description value"; 
      }
      if((! defined $length) || ($length eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty length value"; 
      }
      if((! defined $mol_type) || ($mol_type eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty mol_type value"; 
      }
      if((! defined $source) || ($source eq "-")) { 
        croak "ERROR in $sub_name, seed sequence $seed_nse has undefined or empty source value"; 
      }
      
      # determine if we fetched this data from GenBank or RNAcentral
      my $accession = undef;
      my $version   = undef;
      if($source eq "SEED:GenBank") { 
        (undef, $accession, $version) = Bio::Rfam::Utils::accession_version_breakdown($seed_name);
        if(! defined $accession) { 
          croak "ERROR in $sub_name, unable to determine accession and version from seed sequence $seed_nse"; 
        }
      }
      elsif($source eq "SEED:RNAcentral") { 
        (undef, $accession, undef) = Bio::Rfam::Utils::rnacentral_urs_taxid_breakdown($seed_name);
        if(! defined $accession) { 
          croak "ERROR in $sub_name, unable to determine accession version from seed sequence $seed_nse"; 
        }
        $version = "000000";
      }
      else { 
        croak "ERROR in $sub_name, invalid source read from seed info hash, valid values are \"SEED:GenBank\" and \"SEED:RNAcentral\" but read $source"; 
      }

      # enforce maximum number of characters for each value,
      # for overflows in description we just truncate, overflow in others are fatal
      if(length($seed_name)   > 25)  { croak "ERROR in $sub_name, rfamseq_acc $seed_name exceeds 25 characters"; }
      if(length($accession)   > 25)  { croak "ERROR in $sub_name, accession $accession exceeds 25 characters"; }
      if(length($version)     > 6)   { croak "ERROR in $sub_name, version $version exceeds 6 characters"; }
      if(length($ncbi_id)     > 10)  { croak "ERROR in $sub_name, ncbi_id $ncbi_id exceeds 10 characters"; }
      if(length($length)      > 10)  { croak "ERROR in $sub_name, length $length exceeds 10 characters"; }
      if(length($source)      > 20)  { croak "ERROR in $sub_name, source $source exceeds 20 characters"; }
      if(length($description) > 250) { $description = substr($description, 0, 250); }

      push(@row_AH, { rfamseq_acc => $seed_name, 
                      accession   => $accession,
                      version     => $version,
                      ncbi_id     => $ncbi_id,
                      mol_type    => $mol_type,
                      length      => $length,
                      description => $description, 
                      source      => $source} );
      if(scalar(@row_AH) >= 1000) { 
        $self->populate(\@row_AH);
        @row_AH = ();
      }
    } # end of 'if(! defined $rfamseq_entry)'
  }

  $self->populate(\@row_AH);

  return;
}

1;
