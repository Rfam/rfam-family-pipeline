use utf8;
package RfamLive::Result::Pseudoknot;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::Pseudoknot

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pseudoknot>

=cut

__PACKAGE__->table("pseudoknot");

=head1 ACCESSORS

=head2 rfam_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 pseudoknot_id

  data_type: 'varchar'
  is_nullable: 0
  size: 5

=head2 source

  data_type: 'enum'
  extra: {list => ["seed","rscape"]}
  is_nullable: 1

=head2 covariation

  data_type: 'tinyint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "rfam_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "pseudoknot_id",
  { data_type => "varchar", is_nullable => 0, size => 5 },
  "source",
  {
    data_type => "enum",
    extra => { list => ["seed", "rscape"] },
    is_nullable => 1,
  },
  "covariation",
  { data_type => "tinyint", is_nullable => 1 },
);

=head1 RELATIONS

=head2 rfam_acc

Type: belongs_to

Related object: L<RfamLive::Result::Family>

=cut

__PACKAGE__->belongs_to(
  "rfam_acc",
  "RfamLive::Result::Family",
  { rfam_acc => "rfam_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2019-01-16 16:38:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4VC6U39HfazdGi68KsPzRg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
