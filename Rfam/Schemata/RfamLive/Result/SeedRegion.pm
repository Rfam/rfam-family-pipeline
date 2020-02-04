use utf8;
package RfamLive::Result::SeedRegion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::SeedRegion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<seed_region>

=cut

__PACKAGE__->table("seed_region");

=head1 ACCESSORS

=head2 rfam_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 rfamseq_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 25

=head2 seq_start

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 seq_end

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 md5

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "rfam_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "rfamseq_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 25 },
  "seq_start",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "seq_end",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "md5",
  { data_type => "varchar", is_nullable => 1, size => 32 },
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

=head2 rfamseq_acc

Type: belongs_to

Related object: L<RfamLive::Result::Rfamseq>

=cut

__PACKAGE__->belongs_to(
  "rfamseq_acc",
  "RfamLive::Result::Rfamseq",
  { rfamseq_acc => "rfamseq_acc" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2019-02-28 14:17:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RXjwKp7l/sBMlPGmH/+LSA
# These lines were loaded from '/hps/nobackup/production/xfam/ikalvari/code/rfam-family-pipeline/Rfam/Schemata/RfamLive/Result/SeedRegion.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

use utf8;
package RfamLive::Result::SeedRegion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::SeedRegion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<seed_region>

=cut

__PACKAGE__->table("seed_region");

=head1 ACCESSORS

=head2 rfam_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 rfamseq_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 20

=head2 seq_start

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 seq_end

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "rfam_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "rfamseq_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 20 },
  "seq_start",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "seq_end",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
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

=head2 rfamseq_acc

Type: belongs_to

Related object: L<RfamLive::Result::Rfamseq>

=cut

__PACKAGE__->belongs_to(
  "rfamseq_acc",
  "RfamLive::Result::Rfamseq",
  { rfamseq_acc => "rfamseq_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-01-30 15:46:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7RkXNfiIgEpIABHy2lm7pw


__PACKAGE__->set_primary_key('rfam_acc', 'rfamseq_acc');

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;


