use utf8;
package RfamLive::Result::Genseq;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::Genseq

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<genseq>

=cut

__PACKAGE__->table("genseq");

=head1 ACCESSORS

=head2 upid

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 20

This should be 

=head2 rfamseq_acc

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 20

This should be 

=head2 chromosome_name

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 chromosome_type

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=cut

__PACKAGE__->add_columns(
  "upid",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
  "rfamseq_acc",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
  "chromosome_name",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "chromosome_type",
  { data_type => "varchar", is_nullable => 1, size => 20 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-03-19 17:50:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gd80WBqj46sN8E1f757ZeQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
