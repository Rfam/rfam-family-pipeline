use utf8;
package RfamLive::Result::RnacentralMatch;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::RnacentralMatch

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<rnacentral_matches>

=cut

__PACKAGE__->table("rnacentral_matches");

=head1 ACCESSORS

=head2 rfamseq_acc

  data_type: 'varchar'
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
  is_nullable: 0
  size: 32

=head2 rnacentral_id

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 type

  data_type: 'enum'
  default_value: 'full'
  extra: {list => ["seed","full"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "rfamseq_acc",
  { data_type => "varchar", is_nullable => 0, size => 25 },
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
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "rnacentral_id",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "type",
  {
    data_type => "enum",
    default_value => "full",
    extra => { list => ["seed", "full"] },
    is_nullable => 1,
  },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2019-05-09 16:21:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8/Mbe1P78BsjQlAPJNaLIw

__PACKAGE__->add_unique_constraint(
    acc_start_end_id => ["rfamseq_acc", "seq_start", "seq_end", "rnacentral_id"]
);

#__PACKAGE__->set_primary_key(__PACKAGE__->columns);
__PACKAGE__->set_primary_key('rfamseq_acc', 'seq_start', 'seq_end', 'rnacentral_id');

1;
