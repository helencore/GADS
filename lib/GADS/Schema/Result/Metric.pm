use utf8;
package GADS::Schema::Result::Metric;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

GADS::Schema::Result::Metric

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<metric>

=cut

__PACKAGE__->table("metric");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 metric_group

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 x_axis_value

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 target

  data_type: 'integer'
  is_nullable: 1

=head2 y_axis_grouping_value

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "metric_group",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "x_axis_value",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "target",
  { data_type => "integer", is_nullable => 1 },
  "y_axis_grouping_value",
  { data_type => "varchar", is_nullable => 1, size => 256 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 metric_group

Type: belongs_to

Related object: L<GADS::Schema::Result::MetricGroup>

=cut

__PACKAGE__->belongs_to(
  "metric_group",
  "GADS::Schema::Result::MetricGroup",
  { id => "metric_group" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2015-05-28 08:58:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ws41kqioQXDr2RJUmS6QYQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
