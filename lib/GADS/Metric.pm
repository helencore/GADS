=pod
GADS - Globally Accessible Data Store
Copyright (C) 2015 Ctrl O Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package GADS::Metric;

use Log::Report;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;

# Only needed when manipulating the object
has schema => (
    is => 'ro',
);

has id => (
    is  => 'rwp',
    isa => Maybe[Int],
);

has metric_group_id => (
    is      => 'rw',
    isa     => Int,
    lazy    => 1,
    builder => sub { $_[0]->_rset->get_column('metric_group') },
);

has x_axis_value => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    builder => sub { $_[0]->_rset->x_axis_value },
);

has target => (
    is      => 'rw',
    isa     => Int,
    lazy    => 1,
    builder => sub { $_[0]->_rset->target },
);

has y_axis_grouping_value => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    builder => sub { $_[0]->_rset->y_axis_grouping_value },
);

has _rset => (
    is => 'lazy',
);

sub _build__rset
{   my $self = shift;
    my $rset;
    if ($self->id)
    {
        $rset = $self->schema->resultset('Metric')->find($self->id);
    }
    else {
        $rset = $self->schema->resultset('Metric')->create({
            metric_group => $self->metric_group_id,
        });
    }
    $rset;
}

sub write
{   my $self = shift;
    $self->_rset->update({
        metric_group          => $self->metric_group_id,
        x_axis_value          => $self->x_axis_value,
        y_axis_grouping_value => $self->y_axis_grouping_value,
        target                => $self->target,
    });
}

1;


