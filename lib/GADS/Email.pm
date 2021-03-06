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

package GADS::Email;

use Log::Report;
use Mail::Message;
use Mail::Transport::Sendmail;
use Text::Autoformat qw(autoformat break_wrap);

use Moo;

has message_prefix => (
    is      => 'rw',
    coerce  => sub { ($_[0]||"")."\n" },
);

has text => (
    is => 'rw',
);

has subject => (
    is => 'rw',
);

has email_from => (
    is => 'rw',
);

sub send
{   my ($self, $args) = @_;

    my $emails   = $args->{emails} or error __"Please specify some recipients to send an email to";
    my $subject  = $args->{subject} or error __"Please enter some text for the email";
    my $reply_to = $args->{reply_to};
    my $body     = autoformat $args->{text}, {all => 1, break=>break_wrap};

    my $msg = Mail::Message->build(
        Subject => $subject,
        data    => $body,
        From    => $self->email_from,
    );
    $msg->head->add('Reply-to' => $reply_to) if $reply_to;

    # Start a mailer
    my $mailer = Mail::Transport::Sendmail->new;

    my %done;
    foreach my $email (@$emails)
    {
        next if $done{$email}; # Stop duplicate emails
        $done{$email} = 1;
        $msg->head->set(to => $email);
        $mailer->send($msg);
    }
}

sub message
{   my ($self, $records, $col_id, $user) = @_;

    my @emails;
    foreach my $record (@{$records->results})
    {
        my $email = $record->fields->{$col_id}->email;
        push @emails, $email if $email;
    }

    (my $text = $self->text) =~ s/\s+$//;
    $text = $self->message_prefix.$text
             ."\n\nMessage sent by: ".($user->{value}||"")." ($user->{email})\n";

    my $email = {
        subject  => $self->subject,
        emails   => \@emails,
        text     => $text,
        reply_to => $user->{email},
    };
    $self->send($email);
}

1;

