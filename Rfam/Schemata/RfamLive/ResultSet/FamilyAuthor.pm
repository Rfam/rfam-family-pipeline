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

  # delete family records if any
  my $family_records = $self->search({rfam_acc => $familyObj->{DESC}->{AC}});
  	if(defined($family_records)){
	$family_records->delete();
  }

  if(defined($familyObj->DESC->AU)){
    foreach my $author (@{$familyObj->DESC->AU}){
		# my $author_name = defined($author->{name}) ? $db->{comment} : '';
		my $orcid = defined($author->{orcid}) ? $author->{orcid} : '';
	
	my $new_author = $self->find_or_create( { rfam_acc => $familyObj->{DESC}->{AC},
                                          	  name  => $author->{name},
                                              orcid => $author->{orcid},
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
