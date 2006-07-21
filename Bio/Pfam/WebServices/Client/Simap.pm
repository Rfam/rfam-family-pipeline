
=head1 NAME

Bio::Pfam::::WebServices::Client::Simap

=head1 SYNOPSIS

    use Bio::Pfam::Webservices::Client::Simap;

    $simap = new Bio::Pfam::Webservices:Client::Simap( 
                                           '-' => $annotationRef);


=head1 DESCRIPTION

Some description goes in here.


=head1 CONTACT

Mail pfam@sanger.ac.uk with any queries

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::Pfam::WebServices::Client::Simap;
use vars qw($AUTOLOAD @ISA);

use strict;
use warnings;
use SOAP::Lite (outputxml => 1); # We need to return XML in the response as SOAP::SOM screws the response!
use SOAP::Data::Builder;
use XML::LibXML;
use Bio::Pfam::Root;

@ISA = qw(Bio::Pfam::Root);

sub new {
  my ($class, %params) = @_;
  
  my $self = bless {}, ref($class) || $class;
  
  my $md5        = $params{'-md5'};
  my $maxHits    = $params{'-maxHits'};
  my $minSWscore = $params{'-minSWscore'};
  my $maxEvalue  = $params{'-maxEvalues'};
  my $databases  = $params{'-databases'};
  my $showSeq    = $params{'-showSeq'};
  my $showAli    = $params{'-showAli'};
  
 #Quick assess, miss out get/sets
  eval{
    $self->{'md5'}        = $md5;
    $self->{'maxHits'}    = $maxHits;
    $self->{'minSWscore'} = $minSWscore;
    $self->{'maxEvalue'}  = $maxEvalue;
    $self->{'databases'}  = $databases;
    $self->{'showSeq'}    = $showSeq;
    $self->{'showAli'}    = $showSeq;
  };
  return $self;
}

sub queryMd5 {
  my ($self, $md5) =@_;
  if($md5){
    $self->{'md5'} = $md5;
  }
  return $self->{'md5'} if ($self->{'md5'});
}


sub maxNumberHits{
  my ($self,$maxHits) = @_;
  #Set the max hits if defined
  if($maxHits){
    $self->{'maxHits'} = $maxHits;
  }
  #Set the max hits to 50 unless it is defined
  $self->{'maxHits'} = 50 unless ($self->{'maxHits'});
  return $self->{'maxHits'};
}

sub minSWscore{
  my($self, $minSWscore) = @_;
  #Set the min S/W score if defined
  if($minSWscore){
    $self->{'minSWscore'} = $minSWscore;
  }
  #Set the minSWscore to 1 unless it is defined
  $self->{'minSWscore'} = 1 unless ($self->{'minSWscore'});
  return $self->{'minSWscore'};
}

sub maxEvalue{
  my ($self,$maxEvalue) = @_;
  #Set the max Evalue if defined
  if($maxEvalue){
    $self->{'maxEvalue'} = $maxEvalue;
  }
  #Set the max hits to 0.001 unless it is defined
  $self->{'maxEvalue'} = 0.001 unless ($self->{'maxEvalue'});
  return $self->{'maxEvalue'};
}


sub databaseList{
  my ($self, $databases) = @_;
  if(ref($databases) eq "ARRAY"){
    $self->{'databases'} = $databases;
  }elsif($databases){
    push(@{$self->{'databases'}}, $databases);
  }

  $self->{'databases'} = [qw/313 314/] unless ($self->{'databases'});
  return $self->{'databases'};
}

sub showSequence{
  my($self, $show) = @_;
  if(defined ($show)){
    $self->{'showSeq'} = ($show ? 1:0);
  }
  if(!defined $self->{'showSeq'}){
    $self->{'showSeq'} = 0;
  }
  return $self->{'showSeq'};
}

sub showAlignment{
  my($self, $show) = @_;
  if(defined ($show)){
    $self->{'showAli'} = ($show ? 1:0);
  }
  if(!defined $self->{'showAli'}){
    $self->{'showAli'} = 0;
  }
  return $self->{'showAli'};
}

sub buildSoapMessage {
  my $self = shift;

  if($self->queryMd5){
    my $soapMessage = SOAP::Data::Builder->new(autotype=>0);
    #Now add the parameters to the soapMessage object
    $soapMessage->add_elem( name => "md5", value => $self->queryMd5, type =>"string");
    $soapMessage->add_elem( name => "maxNumberHits", value =>$self->maxNumberHits, type =>"int");
    $soapMessage->add_elem( name => "minSWScore", value =>$self->minSWscore, type =>"int");
    $soapMessage->add_elem( name => "maxEvalue", value =>$self->maxEvalue, type => "double");
    $soapMessage->add_elem( name => "TaxonsInclude");
    $soapMessage->add_elem( name => "TaxonsExclude");

    my $db = $soapMessage->add_elem( name => "DatabaseList");
    
  # This restricts the search to just Trembl and SwissProt
    foreach my $db_id (@{$self->databaseList}){
      $soapMessage->add_elem(name   => 'database',
			     parent => $db,
			     value  => $db_id,
				 type   => "int");
    }
    
    #Blank parameter
    $soapMessage->add_elem( name => "sourceList");
    # Get the sequences sent over
    $soapMessage->add_elem( name => "showSequence", value =>$self->showSequence, type => "boolean");
    #This is a pairwise alignment which can be variable in query sequence length, so not much use for making multiple sequence alignments
    $soapMessage->add_elem( name => "showAlignment", value =>$self->showAlignment, type => "boolean");
    $self->soapMessage($soapMessage);
  }else{
    $self->throw("Tried to build a soap message without the md5 set!");
  }
}

sub soapMessage{
  my ($self, $message) = @_;
  if($message){
    $self->{'message'} = $message;
  }
  return($self->{'message'});
}


sub queryService {
  my ($self, $soapMessage) = @_;
  # If not message is provided,see if the object has one
  $soapMessage = $self->soapMessage unless($soapMessage);
  #If we still do not have a messge, lets try and build one
  if(!$soapMessage){
    $self->buildSoapMessage;
    $soapMessage = $self->soapMessage;
  }

  $self->throw("No soapMessage") unless($soapMessage);

  #Now make the request to the SIMAP service.
  my $results  = SOAP::Lite
    -> uri('http://mips.gsf.de/webservices/services/SimapService')
      -> proxy('http://mips.gsf.de/webservices/services/SimapService')
	-> getHitsByMD5( $soapMessage->to_soap_data ); # This changes the soap message object to xml
  

  #Should test for a fault here!
  if ($results) {
    my $parser = XML::LibXML->new();
    # Now get the results as SOAP::Lite can not handle the response properly
    $self->_response($parser->parse_string($results));
  } else {
    $self->throw("Got no results");
  }
}
sub _response {
  my ($self, $responseDom) = @_;
  # Hand back the LibXML dom.
  if($responseDom){
    $self->{'_response'} = $responseDom;
  }
  return $self->{'_response'} unless(!$self->{'_response'});
}

sub processResponse4Website {
  my ($self, $drawingXML, $seqObj) = @_;
  my $imageNode = $drawingXML->documentElement;
  foreach my $hitNode ($self->_response->findnodes("/soapenv:Envelope/soapenv:Body/result/simapResult/SequenceSimilaritySearchResult/hits/hit")){
    
    #get the evalue
    my $evalue        = $hitNode->findvalue("alignments/alignment/expectation");
    my $identity      = $hitNode->findvalue("alignments/alignment/identity");
    my $querySeqStart = $hitNode->findvalue("alignments/alignment/querySeq/\@start");
    my $querySeqEnd   = $hitNode->findvalue("alignments/alignment/querySeq/\@end");
    my $matchSeqStart = $hitNode->findvalue("alignments/alignment/matchSeq/\@start");
    my $matchSeqEnd   = $hitNode->findvalue("alignments/alignment/matchSeq/\@end");
    my $sequence      = $hitNode->findvalue("matchSequence/sequence/sequence");
    foreach my $proteinNode ($hitNode->findnodes("matchSequence/protein")){
      my $protein       = $proteinNode->find("\@name");
      my $species       = $proteinNode->find("taxonomyNode/\@name");
      
      my $seqElement = $drawingXML->createElement( "sequence" );
      $imageNode->appendChild($seqElement);
      $seqElement->setAttribute( "length", $seqObj->length );
      $seqElement->setAttribute( "name", $protein);
      $seqElement->setAttribute( "hidden", 1);
      my $region = $drawingXML->createElement("region");
      $region->setAttribute( "label" , "$protein/$matchSeqStart-$matchSeqEnd : $querySeqStart-$querySeqEnd ($identity%)" );
      $region->setAttribute( "start" ,$querySeqStart  );
      $region->setAttribute( "end", $querySeqEnd );
      $region->setAttribute( "solid", 1);
      my $shape = $drawingXML->createElement("smlShape");
      $region->appendChild($shape);
      my $colour1  = $drawingXML->createElement("colour1");
      my $colour  = $drawingXML->createElement("colour");
      my $hex  = $drawingXML->createElement("hex");
      if($identity <= 100 && $identity > 90){
	$hex->setAttribute("hexcode", "FF0000")
      }elsif($identity <= 90 && $identity > 80){
	$hex->setAttribute("hexcode", "FF3300")
      }elsif($identity <= 80 && $identity > 70){
	$hex->setAttribute("hexcode", "FF6600")
      }elsif($identity <= 70 && $identity > 60){
	$hex->setAttribute("hexcode", "FF8000")
      }elsif($identity <= 60 && $identity > 50){
	$hex->setAttribute("hexcode", "FF9900")
      }elsif($identity <= 50 && $identity > 40){
	$hex->setAttribute("hexcode", "FFB200")
      }elsif($identity <= 40 && $identity > 30){
	$hex->setAttribute("hexcode", "FFCC00")
      }elsif($identity <= 30 && $identity > 20){
	$hex->setAttribute("hexcode", "FFE500")
      }elsif($identity <= 20 && $identity > 10){
	$hex->setAttribute("hexcode", "FFFF00")
      }else{
	$hex->setAttribute("hexcode", "FFFFFF")
      }
      
      #$hex->setAttribute("hexcode", "CC6666"); #John,you are going to complain about this......
      $colour->appendChild($hex);
      $colour1->appendChild($colour);
      $region->appendChild($colour1);
      $seqElement->appendChild($region);
    }
  }
}


1;
