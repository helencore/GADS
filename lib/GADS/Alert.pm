=pod
GADS - Globally Accessible Data Store
Copyright (C) 2014 Ctrl O Ltd

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

package GADS::Alert;

use GADS::Email;
use GADS::Util qw(:all);
use List::MoreUtils qw/ uniq /;
use Log::Report;
use Scalar::Util qw(looks_like_number);

use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use namespace::clean;

has layout => (
    is       => 'rw',
    required => 1,
);

has schema => (
    is       => 'rw',
    required => 1,
);

has user => (
    is       => 'rw',
    required => 1,
);

has frequency => (
    is  => 'rw',
    isa => sub {
        my $frequency = shift;
        if (looks_like_number $frequency)
        {
            error __x "Frequency value of {frequency} is invalid", frequency => $frequency
                unless $frequency == 0 || $frequency == 24;
        }
        else {
            # Will be empty string from form submission
            error __x "Frequency value of {frequency} is invalid", frequency => $frequency
                if $frequency;
        }
    },
    coerce => sub {
        # Will be empty string from form submission
        $_[0] || $_[0] =~ /0/ ? $_[0] : undef;
    },
);

has view_id => (
    is      => 'rw',
    isa     => Int,
    trigger => sub {
        my ($self, $view_id) = @_;
        # Check that user has access to this view (borks on no access)
        # XXX Check it does bork
        my $view    = GADS::View->new(
            user   => $self->user,
            id     => $view_id,
            schema => $self->schema,
            layout => $self->layout,
        );
    },
);

has all => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        my $self = shift;

        my @alerts_rs = $self->schema->resultset('Alert')->search({
            user_id => $self->user->{id},
        })->all;

        my $alerts;
        foreach my $alert (@alerts_rs)
        {
            $alerts->{$alert->view_id} = {
                id        => $alert->id,
                view_id   => $alert->view_id,
                frequency => $alert->frequency,
            };
        };
        $alerts;
    },
);

sub _create_cache
{   my $self = shift;

    my $views   = GADS::Views->new(
        user   => $self->user,
        schema => $self->schema,
        layout => $self->layout,
    );
    my $records = GADS::Records->new(
        user   => $self->user,
        layout => $self->layout,
        schema => $self->schema,
    );
    my $view    = $views->view($self->view_id);
    $records->search(
        view    => $view,
    );

    my @caches;
    foreach my $result (@{$records->results})
    {
        foreach my $column (@{$view->columns})
        {
            push @caches, {
                layout_id  => $column,
                view_id    => $self->view_id,
                current_id => $result->current_id,
            };
        }
    }
    $self->schema->resultset('AlertCache')->populate(\@caches);
}

sub write
{
    my $self = shift;

    my ($alert) = $self->schema->resultset('Alert')->search({
        view_id => $self->view_id,
        user_id => $self->user->{id},
    });

    if ($alert)
    {
        if (defined $self->frequency)
        {
            $alert->update({ frequency => $self->frequency });
        }
        else {
            # Any other alerts using the same view?
            unless ($self->schema->resultset('Alert')->search({ view_id => $alert->view_id })->count > 1)
            {
                # Delete cache if not
                $self->schema->resultset('AlertSend')->search({ alert_id => $alert->id })->delete;
                $self->schema->resultset('AlertCache')->search({ view_id => $alert->view_id })->delete;
            }
            $alert->delete;
        }
    }
    elsif(defined $self->frequency) {
        # Check whether this view already has alerts. No need for another
        # cache if so.
        my $exists = $self->schema->resultset('Alert')->search({ view_id => $self->view_id })->count;

        my $alert = $self->schema->resultset('Alert')->create({
            view_id   => $self->view_id,
            user_id   => $self->user->{id},
            frequency => $self->frequency,
        });
        $self->_create_cache($alert) unless $exists;
    }
}

sub update_cache
{   my $self = shift;

    $self->schema->resultset('AlertCache')->search({
        view_id => $self->view_id,
    })->delete;

    my ($alert) = $self->schema->resultset('Alert')->search({
        view_id => $self->view_id,
        user_id => $self->user->{id},
    });
    $self->_create_cache($alert);
}

1;

