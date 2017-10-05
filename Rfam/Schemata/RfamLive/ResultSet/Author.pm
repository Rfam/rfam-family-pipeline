use utf8;
package RfamLive::Result::Author;

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

  if(defined($familyObj->DESC->AU)){
    foreach my $author (@{$familyObj->DESC->AU}){ 
    # check both author name and synonyms to search for existing author
    # search for an author by name
    my $author_entry = $self->find({name => $author->{name}},{key => 'author_id'});
    if(!defined $author_entry){
      # search for an author by synonym
      my $author_entry = $self->search_like({synonyms => '%$author->{name}%'},{key => 'author_id'});
      if(!defined $author_entry){
        # create a new entry
        my $new_entry = $self->create({name => $author->{name}, orcid => $author->{orcid}},{key => 'author_id'});
      }
      else{
        # update if an orcid is found in the DESC file and not in DB
        if(($author->{orcid} ne '') && $check_author->{orcid} ne ''){
          $check_author->update({orcid => $author->{orcid}},{key => 'author_id'});
        }
      }
    }
    # found author name
    else{
      # check if we need to add orcid
        if(($author->{orcid} ne '') && $check_author->orcid ne ''){
          $check_author->update({orcid => $author->{orcid}},{key => 'author_id'});
        }
    }
  }
}
1;
