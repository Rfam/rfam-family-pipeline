use utf8;
package PfamLive::Result::Pfamseq;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamLive::Result::Pfamseq

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pfamseq>

=cut

__PACKAGE__->table("pfamseq");

=head1 ACCESSORS

=head2 pfamseq_acc

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 pfamseq_id

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 seq_version

  data_type: 'tinyint'
  is_nullable: 0

=head2 crc64

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 md5

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 description

  data_type: 'text'
  is_nullable: 0

=head2 evidence

  data_type: 'tinyint'
  is_foreign_key: 1
  is_nullable: 0

=head2 length

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 species

  data_type: 'text'
  is_nullable: 0

=head2 taxonomy

  data_type: 'mediumtext'
  is_nullable: 1

=head2 is_fragment

  data_type: 'tinyint'
  is_nullable: 1

=head2 sequence

  accessor: undef
  data_type: 'blob'
  is_nullable: 0

=head2 updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 created

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 ncbi_taxid

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 auto_architecture

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 treefam_acc

  data_type: 'varchar'
  is_nullable: 1
  size: 8

=head2 swissprot

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "pfamseq_acc",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "pfamseq_id",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "seq_version",
  { data_type => "tinyint", is_nullable => 0 },
  "crc64",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "md5",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "evidence",
  { data_type => "tinyint", is_foreign_key => 1, is_nullable => 0 },
  "length",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "species",
  { data_type => "text", is_nullable => 0 },
  "taxonomy",
  { data_type => "mediumtext", is_nullable => 1 },
  "is_fragment",
  { data_type => "tinyint", is_nullable => 1 },
  "sequence",
  { accessor => undef, data_type => "blob", is_nullable => 0 },
  "updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "ncbi_taxid",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "auto_architecture",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "treefam_acc",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "swissprot",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</pfamseq_acc>

=back

=cut

__PACKAGE__->set_primary_key("pfamseq_acc");

=head1 RELATIONS

=head2 edits

Type: has_many

Related object: L<PfamLive::Result::Edit>

=cut

__PACKAGE__->has_many(
  "edits",
  "PfamLive::Result::Edit",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 evidence

Type: belongs_to

Related object: L<PfamLive::Result::Evidence>

=cut

__PACKAGE__->belongs_to(
  "evidence",
  "PfamLive::Result::Evidence",
  { evidence => "evidence" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 ncbi_taxid

Type: belongs_to

Related object: L<PfamLive::Result::NcbiTaxonomy>

=cut

__PACKAGE__->belongs_to(
  "ncbi_taxid",
  "PfamLive::Result::NcbiTaxonomy",
  { ncbi_taxid => "ncbi_taxid" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 nested_locations

Type: has_many

Related object: L<PfamLive::Result::NestedLocation>

=cut

__PACKAGE__->has_many(
  "nested_locations",
  "PfamLive::Result::NestedLocation",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 other_regs

Type: has_many

Related object: L<PfamLive::Result::OtherReg>

=cut

__PACKAGE__->has_many(
  "other_regs",
  "PfamLive::Result::OtherReg",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfam_a_reg_full_insignificants

Type: has_many

Related object: L<PfamLive::Result::PfamARegFullInsignificant>

=cut

__PACKAGE__->has_many(
  "pfam_a_reg_full_insignificants",
  "PfamLive::Result::PfamARegFullInsignificant",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfam_a_reg_full_significants

Type: has_many

Related object: L<PfamLive::Result::PfamARegFullSignificant>

=cut

__PACKAGE__->has_many(
  "pfam_a_reg_full_significants",
  "PfamLive::Result::PfamARegFullSignificant",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfam_annseqs

Type: has_many

Related object: L<PfamLive::Result::PfamAnnseq>

=cut

__PACKAGE__->has_many(
  "pfam_annseqs",
  "PfamLive::Result::PfamAnnseq",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfamseq_disulphides

Type: has_many

Related object: L<PfamLive::Result::PfamseqDisulphide>

=cut

__PACKAGE__->has_many(
  "pfamseq_disulphides",
  "PfamLive::Result::PfamseqDisulphide",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfamseq_markups

Type: has_many

Related object: L<PfamLive::Result::PfamseqMarkup>

=cut

__PACKAGE__->has_many(
  "pfamseq_markups",
  "PfamLive::Result::PfamseqMarkup",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 secondary_pfamseq_accs

Type: has_many

Related object: L<PfamLive::Result::SecondaryPfamseqAcc>

=cut

__PACKAGE__->has_many(
  "secondary_pfamseq_accs",
  "PfamLive::Result::SecondaryPfamseqAcc",
  { "foreign.pfamseq_acc" => "self.pfamseq_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2016-07-06 13:42:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AVLEZDF2f2ycWuNIy19Bng

__PACKAGE__->load_components(qw/ Result::ColumnData /);
__PACKAGE__->register_relationships_column_data();

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
