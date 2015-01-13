use utf8;
package PfamLive::Result::AlignmentAndTree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamLive::Result::AlignmentAndTree

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<alignment_and_tree>

=cut

__PACKAGE__->table("alignment_and_tree");

=head1 ACCESSORS

=head2 pfama_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 alignment

  data_type: 'longblob'
  is_nullable: 1

=head2 tree

  data_type: 'longblob'
  is_nullable: 1

=head2 jtml

  data_type: 'longblob'
  is_nullable: 1

=head2 post

  data_type: 'longblob'
  is_nullable: 1

=head2 type

  data_type: 'enum'
  extra: {list => ["full","rp15","rp35","rp55","rp75","seed","meta","ncbi"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pfama_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "alignment",
  { data_type => "longblob", is_nullable => 1 },
  "tree",
  { data_type => "longblob", is_nullable => 1 },
  "jtml",
  { data_type => "longblob", is_nullable => 1 },
  "post",
  { data_type => "longblob", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => ["full", "rp15", "rp35", "rp55", "rp75", "seed", "meta", "ncbi"],
    },
    is_nullable => 0,
  },
);

=head1 RELATIONS

=head2 pfama_acc

Type: belongs_to

Related object: L<PfamLive::Result::PfamA>

=cut

__PACKAGE__->belongs_to(
  "pfama_acc",
  "PfamLive::Result::PfamA",
  { pfama_acc => "pfama_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-13 08:53:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZYgMuDidPuaBH/T4bB4PBA
# These lines were loaded from '/nfs/production/xfam/pfam/software/Modules/PfamSchemata/PfamLive/Result/AlignmentAndTree.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

use utf8;
package PfamLive::Result::AlignmentAndTree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamLive::Result::AlignmentAndTree

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<alignment_and_tree>

=cut

__PACKAGE__->table("alignment_and_tree");

=head1 ACCESSORS

=head2 pfama_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 alignment

  data_type: 'longblob'
  is_nullable: 1

=head2 tree

  data_type: 'longblob'
  is_nullable: 1

=head2 jtml

  data_type: 'longblob'
  is_nullable: 1

=head2 post

  data_type: 'longblob'
  is_nullable: 1

=head2 type

  data_type: 'enum'
  extra: {list => ["full","rp15","rp35","rp55","rp75","seed","meta","ncbi"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pfama_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "alignment",
  { data_type => "longblob", is_nullable => 1 },
  "tree",
  { data_type => "longblob", is_nullable => 1 },
  "jtml",
  { data_type => "longblob", is_nullable => 1 },
  "post",
  { data_type => "longblob", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => ["full", "rp15", "rp35", "rp55", "rp75", "seed", "meta", "ncbi"],
    },
    is_nullable => 0,
  },
);

=head1 RELATIONS

=head2 pfama_acc

Type: belongs_to

Related object: L<PfamLive::Result::PfamA>

=cut

__PACKAGE__->belongs_to(
  "pfama_acc",
  "PfamLive::Result::PfamA",
  { pfama_acc => "pfama_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-05 16:35:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xnRAfn/J5OrS10JzBdIfgw

__PACKAGE__->add_unique_constraint("UQ_alignments_and_trees_1", ["pfama_acc", "type"]);

__PACKAGE__->set_primary_key('pfama_acc', 'type');

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
# End of lines loaded from '/nfs/production/xfam/pfam/software/Modules/PfamSchemata/PfamLive/Result/AlignmentAndTree.pm' 


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
