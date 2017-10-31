package RfamLive::ResultSet::FamilyAuthor;

use strict;
use warnings;
use Carp;

use base 'DBIx::Class::ResultSet';

sub find_or_create_authorsFromFamilyObj {
	my ($self, $familyObj) = @_;
  
  	if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }

  # create an instance of the author table
  my $schema = $self->result_source->schema;
  my $author_tbl= $schema->resultset('Author');

  # delete family records if any
  my $family_records = $self->search({rfam_acc => $familyObj->{DESC}->{AC}});
  	if(defined($family_records)){
	$family_records->delete();
  }

  if(defined($familyObj->DESC->AU)){
  
    my $author_ids = $author_tbl->get_author_ids($familyObj);

    foreach my $author (@{$familyObj->DESC->AU}){
		
      # populate family author_table
      my $new_author = $self->find_or_create( { rfam_acc => $familyObj->{DESC}->{AC},
                                              author_id  => $author_ids->{$author->{name}},
                                              desc_order => $author->{order}});

       if(!defined($new_author)){
                croak("Error updating family authors for $familyObj->{DESC}->{AC}");
        }

	  } 
  }
}


1;	
