# DESC.pm
#
# Author:        finnr
# Maintainer:    $Id: DESC.pm,v 1.1 2009-10-08 12:27:28 jt6 Exp $
# Version:       $Revision: 1.1 $
# Created:       Apr 24, 2009
# Last Modified: $Date: 2009-10-08 12:27:28 $
=head1 NAME

Bio::Pfam::Family::DESC - An object to represent a DESC file

=cut

package Bio::Pfam::Clan::DESC;

=head1 DESCRIPTION

A more detailed description of what this class does and how it does it.

$Id: DESC.pm,v 1.1 2009-10-08 12:27:28 jt6 Exp $

=head1 COPYRIGHT

File: DESC.pm

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk)

 This is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 or see the on-line version at http://www.gnu.org/copyleft/gpl.txt
 
=cut

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;
use Bio::Pfam::Family::DESC;
#-------------------------------------------------------------------------------

=head1 METHODS

=cut


subtype 'ClanAcc'
  => as Str
  => where { $_ =~ m/^CL\d{4}$/ or $_ =~ /^CL\d{4}\.\d+$/ }
  => message { "\n\n*** $_ is not a valid clan accession. Expected CLXXXX ***\n\n" };

subtype 'ClanId'
  => as Str
  => where { $_ =~ m/^[\w_-]{1,15}$/ }
  => message { "\n\n***$_ is not a valid Clan Id" };
  
has 'AC' => (
  is        => 'rw',
  isa       => 'ClanAcc',
  required  => 0
);

has 'ID' => (
  is        => 'rw',
  isa       => 'ClanId',
  required  => 1
  
);  

has 'PI' => (
  is        => 'rw',
  isa       => 'Str',
);

has 'DE' => (
  is        => 'ro',
  isa       => 'PfamDesc',
  required  => 1
);


has 'AU' => (
  is        => 'ro',
  isa       => 'PfamAuthor',
  required  => 1
);

has 'WIKI' => (
  is        => 'ro',
  isa       => 'HashRef'
);

has 'REFS' => (
  is        => 'ro',
  isa       => 'PfamRef'
);

has 'CC' => (
  is        => 'ro',
  isa       => 'Str',
);

has 'DBREFS' => (
  is     => 'ro',
  isa    => 'ArrayRef[ HashRef ]'
);


has 'MEMB' => (
  is     => 'rw',
  isa    => 'ArrayRef'
);

has 'order' => (
  is    => 'ro',
  isa   => 'ArrayRef',
  default => sub {[ qw(ID AC PI DE AU WIKI REFS DBREFS CC MEMB) ] }
);

1;
