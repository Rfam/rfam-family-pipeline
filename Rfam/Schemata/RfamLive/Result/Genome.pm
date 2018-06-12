use utf8;
package RfamLive::Result::Genome;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::Genome

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<genome>

=cut

__PACKAGE__->table("genome");

=head1 ACCESSORS

=head2 upid

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 20

This should be 

=head2 assembly_acc

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 assembly_version

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 wgs_acc

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 wgs_version

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 assembly_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 assembly_level

  data_type: 'enum'
  extra: {list => ["contig","chromosome","scaffold","complete-genome"]}
  is_nullable: 1

=head2 study_ref

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 description

  data_type: 'mediumtext'
  is_nullable: 1

=head2 total_length

  data_type: 'bigint'
  is_nullable: 1

=head2 ungapped_length

  data_type: 'bigint'
  is_nullable: 1

=head2 circular

  data_type: 'tinyint'
  is_nullable: 1

=head2 ncbi_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 scientific_name

  data_type: 'varchar'
  is_nullable: 1
  size: 300

=head2 common_name

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 kingdom

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 num_rfam_regions

  data_type: 'integer'
  is_nullable: 1

=head2 num_families

  data_type: 'integer'
  is_nullable: 1

=head2 is_reference

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 is_representative

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 created

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "upid",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
  "assembly_acc",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "assembly_version",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "wgs_acc",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "wgs_version",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "assembly_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "assembly_level",
  {
    data_type => "enum",
    extra => { list => ["contig", "chromosome", "scaffold", "complete-genome"] },
    is_nullable => 1,
  },
  "study_ref",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "description",
  { data_type => "mediumtext", is_nullable => 1 },
  "total_length",
  { data_type => "bigint", is_nullable => 1 },
  "ungapped_length",
  { data_type => "bigint", is_nullable => 1 },
  "circular",
  { data_type => "tinyint", is_nullable => 1 },
  "ncbi_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "scientific_name",
  { data_type => "varchar", is_nullable => 1, size => 300 },
  "common_name",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "kingdom",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "num_rfam_regions",
  { data_type => "integer", is_nullable => 1 },
  "num_families",
  { data_type => "integer", is_nullable => 1 },
  "is_reference",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "is_representative",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</upid>

=back

=cut

__PACKAGE__->set_primary_key("upid");


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-03-19 17:50:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:H7UGLFjK+yDOgHsjSPrp0Q
# These lines were loaded from '/nfs/production/xfam/rfam/rfam_rh7/production_software/rfam_production/rfam-family-pipeline/Rfam/Schemata/RfamLive/Result/Genome.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

use utf8;
package RfamLive::Result::Genome;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::Genome

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<genome>

=cut

__PACKAGE__->table("genome");

=head1 ACCESSORS

=head2 genome_acc

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 ensembl_id

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 description

  data_type: 'mediumtext'
  is_nullable: 1

=head2 length

  data_type: 'bigint'
  is_nullable: 1

=head2 circular

  data_type: 'tinyint'
  is_nullable: 1

=head2 ncbi_id

  data_type: 'integer'
  is_nullable: 1

=head2 taxonomy

  data_type: 'mediumtext'
  is_nullable: 1

=head2 species

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 kingdom

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 regions

  data_type: 'integer'
  is_nullable: 1

=head2 families

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genome_acc",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "ensembl_id",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "description",
  { data_type => "mediumtext", is_nullable => 1 },
  "length",
  { data_type => "bigint", is_nullable => 1 },
  "circular",
  { data_type => "tinyint", is_nullable => 1 },
  "ncbi_id",
  { data_type => "integer", is_nullable => 1 },
  "taxonomy",
  { data_type => "mediumtext", is_nullable => 1 },
  "species",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "kingdom",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "regions",
  { data_type => "integer", is_nullable => 1 },
  "families",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genome_acc>

=back

=cut

__PACKAGE__->set_primary_key("genome_acc");

=head1 RELATIONS

=head2 genome_full_regions

Type: has_many

Related object: L<RfamLive::Result::GenomeFullRegion>

=cut

__PACKAGE__->has_many(
  "genome_full_regions",
  "RfamLive::Result::GenomeFullRegion",
  { "foreign.genome_acc" => "self.genome_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genome_gffs

Type: has_many

Related object: L<RfamLive::Result::GenomeGff>

=cut

__PACKAGE__->has_many(
  "genome_gffs",
  "RfamLive::Result::GenomeGff",
  { "foreign.genome_acc" => "self.genome_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genome_seqs

Type: has_many

Related object: L<RfamLive::Result::GenomeSeq>

=cut

__PACKAGE__->has_many(
  "genome_seqs",
  "RfamLive::Result::GenomeSeq",
  { "foreign.genome_acc" => "self.genome_acc" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-01-29 23:35:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hguVGqCiAREYBOhw8NeISw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
# End of lines loaded from '/nfs/production/xfam/rfam/rfam_rh7/production_software/rfam_production/rfam-family-pipeline/Rfam/Schemata/RfamLive/Result/Genome.pm'


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
