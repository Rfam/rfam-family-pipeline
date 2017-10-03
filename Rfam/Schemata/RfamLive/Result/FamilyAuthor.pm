use utf8;
package RfamLive::Result::FamilyAuthor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::FamilyAuthor

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<family_author>

=cut

__PACKAGE__->table("family_author");

=head1 ACCESSORS

=head2 rfam_acc

  data_type: 'varchar'
  is_nullable: 0
  size: 7

=head2 author_id

  data_type: 'integer'
  is_nullable: 0

=head2 desc_order

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "rfam_acc",
  { data_type => "varchar", is_nullable => 0, size => 7 },
  "author_id",
  { data_type => "integer", is_nullable => 0 },
  "desc_order",
  { data_type => "integer", is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-10-03 11:31:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CX9F5DUiBbvoBtkbtLfYiA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
