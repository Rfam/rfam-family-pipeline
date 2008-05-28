
# $Id: Metaseq.pm,v 1.1 2008-05-28 10:21:29 rdf Exp $
#
# $Author: rdf $

package PfamLive::Metaseq;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( qw( Core ) );

# set up the table
__PACKAGE__->table( 'metaseq' );

# get the columns that we want to keep
__PACKAGE__->add_columns( qw( auto_metaseq 
                              metaseq_id 
                              metaseq_acc 
                              description 
                              length 
                              sequence
                              source ) );

# set the the keys
__PACKAGE__->set_primary_key( qw( auto_metaseq ) );

# set up the relationships
__PACKAGE__->has_many( meta_pfama_reg => 'PfamLive::Meta_pfama_reg',
                       { 'foreign.auto_metaseq' => 'self.auto_metaseq' } );

# TODO this is actually wrong; there can be multiple rows for each source (multiple refs)
__PACKAGE__->has_one( meta_ref => 'PfamLive::Metagenomics_refs',
                       { 'foreign.source' => 'self.source' },
                      { proxy => [ qw( long_source pmid ) ] } );


__PACKAGE__->might_have( meta_map => 'PfamLive::Metaseq_ncbi_map',
                         { 'foreign.auto_metaseq' => 'self.auto_metaseq' });
=head1 COPYRIGHT

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

1;
