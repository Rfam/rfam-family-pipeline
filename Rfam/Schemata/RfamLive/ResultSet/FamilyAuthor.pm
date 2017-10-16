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
  my $author_tbl= $schema->resultset('Author');

  # delete family records if any
  my $family_records = $self->search({rfam_acc => $familyObj->{DESC}->{AC}});
  	if(defined($family_records)){
	$family_records->delete();
  }

  if(defined($familyObj->DESC->AU)){
    foreach my $author (@{$familyObj->DESC->AU}){
		# my $author_name = defined($author->{name}) ? $db->{comment} : '';
		my $orcid = defined($author->{orcid}) ? $author->{orcid} : '';
	
    # now search for author_id
    my $author_id;
    # first search by name. 
    # This one should do the trick as author creation precedes this update
    my $author_entry = $author_tbl->find({name => $author->{name}});
    if (defined($author_entry)){
      $author_id=$author_entry->{'author_id'};
    }
    # search in synonyms
    else{
      my $author_entry = $author_tbl->search_like({synonyms => '%$author->{name}%'});
      if (defined($author_entry)){
        $author_id=$author_entry->{'author_id'};
      }
    }
    


	  # search for author id 
    my $new_author = $self->find_or_create( { rfam_acc => $familyObj->{DESC}->{AC},
                                          	  author_id  => $author_id,
                                              order => $author->{order}});
      	
	if(!defined($new_author)){	
		croak("Error updating family authors for $familyObj->{DESC}->{AC}");
    }
	else{
  		$new_author->update({orcid => $orcid});
	}
	}
}
}

1;	
