use utf8;
package RfamLive::ResultSet::Author;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::Author

=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub create_or_updateAuthorFromFamilyObj {
  my ($self, $familyObj) = @_;
  
  if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }

  if(defined($familyObj->{DESC}->{AU})){
    foreach my $author (@{$familyObj->DESC->AU}){ 
    # check both author name and synonyms to search for existing author
    # search for an author by name
    my $author_entry = $self->find({name => $author->{name}});
    if(!defined $author_entry){
      # author not found by name, search by synonym
      my $author_entry = $self->find({synonyms => '%$author->{name}%'});
      # author not found by synonym
      if(!defined $author_entry){
        # create a new entry
        my $new_entry = $self->create({name => $author->{name}, orcid => $author->{orcid}});
      }
      # author found by synonym, update orcid if available
      else{
        if(defined($author->{orcid})){
          $author_entry->update({orcid => $author->{orcid}});
        }
      }
    }
    # found author name
    else{
        # author found by name, update orcid if availablr
        if(defined($author->{orcid})){
          $author_entry->update({orcid => $author->{orcid}});
        }
      }
    }
  }
}


sub get_author_ids{

  my ($self, $familyObj) = @_;

  if(!$familyObj or !$familyObj->isa('Bio::Rfam::Family')){
    croak('Either the Bio::Rfam::Family object was undefined or not an object of that type.');
  }

  my %author_ids = ();

  if(defined($familyObj->{DESC}->{AU})){
    foreach my $author (@{$familyObj->DESC->AU}){ 
      
      # search author table by author name
      my $author_entry = $self->find({name => $author->{name}});
      
      # if not found search by synonym
      if(!defined $author_entry){
        my $author_entry = $self->find({synonyms => { 'like' => '%$author->{name}%'}});
       
        if(!defined $author_entry){
          croak('Aurhor $author->{name} does not exist in the database.');
        }
        
      }else{
        # update hash
      $author_ids{$author->{name}}=$author_entry->get_column('author_id');
      }
    }
  }

  return \%author_ids;
} # sub

1;
