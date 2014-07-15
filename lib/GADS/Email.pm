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

use Dancer2 ':script';
use Dancer2::Plugin::Emailesque;
use Dancer2::Plugin::DBIC qw(schema resultset rset);
schema->storage->debug(1);
use Text::Autoformat qw(autoformat break_wrap);
use Ouch;

sub send($)
{   my ($class, $args) = @_;

    my $emails  = $args->{emails} or ouch 'badparam', "Please specify some recipients to send an email to";
    my $subject = $args->{subject} or ouch 'badparam', "Please enter some text for the email";
    my $message = autoformat $args->{text}, {all => 1, break=>break_wrap};

    my %done;
    foreach my $email (@$emails)
    {
        next if $done{$email}; # Stop duplicate emails
        $done{$email} = 1;
        email {
            to      => $email,
            subject => $subject,
            message => $message,
        };
    }
}

1;
