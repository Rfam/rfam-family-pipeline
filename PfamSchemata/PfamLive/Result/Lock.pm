use utf8;
package PfamLive::Result::Lock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamLive::Result::Lock

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<_lock>

=cut

__PACKAGE__->table("_lock");

=head1 ACCESSORS

=head2 locked

  data_type: 'tinyint'
  is_nullable: 0

=head2 locker

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 allowcommits

  data_type: 'tinyint'
  is_nullable: 0

=head2 alsoallow

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "locked",
  { data_type => "tinyint", is_nullable => 0 },
  "locker",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "allowcommits",
  { data_type => "tinyint", is_nullable => 0 },
  "alsoallow",
  { data_type => "text", is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-05-19 08:45:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:V4/+7th/dp04faOPYaUz6A

__PACKAGE__->set_primary_key(
    "locked"
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
