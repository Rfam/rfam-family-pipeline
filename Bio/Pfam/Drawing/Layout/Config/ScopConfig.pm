
# $Author: jt6 $


package Bio::Pfam::Drawing::Layout::Config::ScopConfig;

use vars qw($AUTOLOAD @ISA $VERSION);
use strict;
use warnings;


use Bio::Pfam::Drawing::Layout::Region;
use Bio::Pfam::Drawing::Layout::Config::GenericRegionConfig;

@ISA = qw(Bio::Pfam::Drawing::Layout::Config::GenericRegionConfig);


sub configure_Region {
  my ($self, $region) = @_;
  # set up the shape type
  $region->type("bigShape");

  #Now set the image ends
  $self->_leftStyle($region);
  $self->_rightStyle($region);

  #Now construct the URL
  $self->_construct_URL($region);

  #Now contruct the label
  $self->_construct_label($region);

  #Now set the colours
  $self->_set_colours($region);
  
}

sub _leftStyle {
  my ($self, $region) = @_;
  
  if($region->BioAnnotatedRegion->from != $region->start){
    #Check that the region has not moved due to overlaps
    $region->leftstyle("jagged");
  }elsif($region->BioAnnotatedRegion->start_frag){
    $region->leftstyle("jagged");
  }else{
    $region->leftstyle("curved");
  }
}

sub _rightStyle {
  my ($self, $region) = @_;

  if($region->BioAnnotatedRegion->to != $region->end){
    #Check that the region has not moved due to overlaps
    $region->rightstyle("jagged");
  }elsif($region->BioAnnotatedRegion->end_frag){
    $region->rightstyle("jagged");
  }else{
    $region->rightstyle("curved");
  }
}

sub _construct_URL {
  my ($self, $region) = @_;
  #This should be dened by some
  #This needs to be defined elsewhere
  $region->url("http://scop.mrc-lmb.cam.ac.uk/scop/search.cgi?sunid=".$region->BioAnnotatedRegion->id);
}

sub _construct_label{
  my ($self, $region) = @_;
  $region->label($region->BioAnnotatedRegion->name);
  
}

sub _set_colours {
  my ($self, $region) = @_;
  my $colour1 = Bio::Pfam::Drawing::Colour::hexColour->new('-colour' => "52B8B8");
  $region->colour1($colour1);
  my $colour2 = Bio::Pfam::Drawing::Colour::hexColour->new('-colour' => "8EF4F4");
  $region->colour2($colour2);
}
