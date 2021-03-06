package GADS;

use DateTime;
use File::Temp qw/ tempfile /;
use GADS::Alert;
use GADS::Approval;
use GADS::Audit;
use GADS::Column;
use GADS::Column::Calc;
use GADS::Column::Date;
use GADS::Column::Daterange;
use GADS::Column::Enum;
use GADS::Column::File;
use GADS::Column::Intgr;
use GADS::Column::Person;
use GADS::Column::Rag;
use GADS::Column::String;
use GADS::Column::Tree;
use GADS::Config;
use GADS::DB;
use GADS::DBICProfiler;
use GADS::Email;
use GADS::Graph;
use GADS::Graph::Data;
use GADS::Graphs;
use GADS::Group;
use GADS::Groups;
use GADS::Layout;
use GADS::MetricGroup;
use GADS::MetricGroups;
use GADS::Record;
use GADS::Records;
use GADS::Type::Permissions;
use GADS::User;
use GADS::Util         qw(:all);
use GADS::View;
use GADS::Views;
use Email::Valid;
use HTML::Entities;
use JSON qw(decode_json encode_json);
use Log::Report mode => 'DEBUG';
use String::CamelCase qw(camelize);
use String::Random;
use Text::CSV;
use WWW::Mechanize::PhantomJS;

use Dancer2; # Last to stop Moo generating conflicting namespace
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Dancer2::Plugin::Auth::Extensible;

schema->storage->debugobj(new GADS::DBICProfiler);
schema->storage->debug(1);
schema->exception_action(sub { panic @_ }); # There should never be exceptions from DBIC

our $VERSION = '0.1';

# set serializer => 'JSON';
set behind_proxy => config->{behind_proxy}; # XXX Why doesn't this work in config file

# Callback dispatcher to send error messages to the web browser
dispatcher CALLBACK => 'error_handler'
   , callback => \&error_handler
   , mode => 'DEBUG';

# And a syslog dispatcher
dispatcher SYSLOG => 'gads'
  , identity => 'gads'
  , facility => 'local0'
  , flags    => "pid ndelay nowait"
  , mode     => 'DEBUG';

hook init_error => sub {
    my $error = shift;
    # Catch other exceptions. This is hook is called for all errors
    # not just exceptions (including for example 404s), so check first.
    # If it's an exception then panic it to get Log::Report
    # to handle it nicely. If it's another error such as a 404
    # then exception will not be set.
    panic $error->{exception} if $error->{exception};
};

hook before => sub {

    return if request->uri =~ m!^/(error|js|css|login|images|fonts|resetpw|ping)!;
    return if param 'error';

    # Dynamically generate "virtual" columns for each row of data, based on the
    # configured layout
    my $user = logged_in_user;
    GADS::DB->setup(schema);

    if (config->{gads}->{aup} && $user)
    {
        # Redirect if AUP not signed
        my $aup_accepted;
        if (my $aup_date = logged_in_user->{aup_accepted})
        {
            my $db_parser   = schema->storage->datetime_parser;
            my $aup_date_dt = $db_parser->parse_datetime($aup_date);
            $aup_accepted   = $aup_date_dt && DateTime->compare( $aup_date_dt, DateTime->now->subtract(months => 12) ) > 0;
        }
        redirect '/aup' unless $aup_accepted || request->uri =~ m!^/aup!;
    }

    if (logged_in_user && config->{gads}->{user_status} && !session('status_accepted'))
    {
        # Redirect to user status page if required and not seen this session
        redirect '/user_status' unless request->uri =~ m!^/(user_status|aup)!;
    }
    elsif (logged_in_user_password_expired)
    {
        # Redirect to user details page if password expired
        forwardHome({ danger => "Your password has expired. Please use the Change password button
            below to set a new password." }, 'account/detail') unless request->uri eq '/account/detail';
    }
};

hook before_template => sub {
    my $tokens = shift;

    # Log to audit
    my $user = logged_in_user;
    my $method = request->method;
    my $path   = request->path;
    my $audit  = GADS::Audit->new(schema => schema, user => $user);
    $audit->user_action(qq(User $user->{username} made $method request to $path))
        if $user;

    my $base = $tokens->{base} || request->base;
    $tokens->{url}->{css}  = "${base}css";
    $tokens->{url}->{js}   = "${base}js";
    $tokens->{url}->{page} = $base;
    $tokens->{url}->{page} =~ s!.*/!!; # Remove trailing slash
    $tokens->{scheme}    ||= request->scheme; # May already be set for phantomjs requests
    $tokens->{hostlocal}   = config->{gads}->{hostlocal};

    $tokens->{header} = config->{gads}->{header};

    my $layout = GADS::Layout->new(user => $user, schema => schema);
    if ($user && ($layout->user_can('approve_new') || $layout->user_can('approve_existing')))
    {
        my $approval = GADS::Approval->new(
            schema => schema,
            user   => $user,
            layout => $layout
        );
        $tokens->{user_can_approve} = 1;
        $tokens->{approve_waiting} = $approval->count;
    }
    $tokens->{messages} = session('messages');
    $tokens->{user}     = $user;
    $tokens->{config}   = config;
    session 'messages' => [];

};

get '/' => require_login sub {

    my $config = GADS::Config->new(schema => schema);
    template 'index' => {
        instance => $config,
        page     => 'index'
    };
};

get '/ping' => sub {
    content_type 'text/plain';
    'alive';
};

any '/aup' => require_login sub {

    if (param 'accepted')
    {
        update_current_user aup_accepted => DateTime->now;
        redirect '/';
    }

    template aup => {
        page => 'aup',
    };
};

get '/aup_text' => require_login sub {
    template 'aup_text', {}, { layout => undef };
};

# Shows last login time etc
any '/user_status' => require_login sub {

    if (param 'accepted')
    {
        session 'status_accepted' => 1;
        redirect '/';
    }

    template user_status => {
        lastlogin => logged_in_user_lastlogin,
        message   => config->{gads}->{user_status_message},
        page      => 'user_status',
    };
};

get '/data_calendar/:time' => require_login sub {

    # Time variable is used to prevent caching by browser

    my $fromdt  = DateTime->from_epoch( epoch => ( param('from') / 1000 ) );
    my $todt    = DateTime->from_epoch( epoch => ( param('to') / 1000 ) ); 

    # Attempt to find period requested. Sometimes the duration is
    # slightly less than expected, hence the multiple tests
    my $diff     = $todt->subtract_datetime($fromdt);
    my $dt_view  = ($diff->months >= 11 || $diff->years)
                 ? 'year'
                 : ($diff->weeks > 1 || $diff->months)
                 ? 'month'
                 : ($diff->days >= 6 || $diff->weeks)
                 ? 'week'
                 : 'day'; # Default to month

    # Attempt to remember day viewed. This is difficult, due to the
    # timezone issues described below. XXX How to fix?
    session 'calendar' => {
        day  => $todt->clone->subtract(days => 1),
        view => $dt_view,
    };

    # Epochs received from the calendar module are based on the timezone of the local
    # browser. So in BST, 24th August is requested as 23rd August 23:00. Rather than
    # trying to convert timezones, we keep things simple and round down any "from"
    # times and round up any "to" times.
    $fromdt->truncate( to => 'day'); 
    if ($todt->hms('') ne '000000')
    {
        # If time is after midnight, round down to midnight and add day
        $todt->set(hour => 0, minute => 0, second => 0);
        $todt->add(days => 1);
    }

    if ($fromdt->hms('') ne '000000')
    {
        # If time is after midnight, round down to midnight
        $fromdt->set(hour => 0, minute => 0, second => 0);
    }

    my $user    = logged_in_user;
    my $layout  = GADS::Layout->new(user => $user, schema => schema);
    my $view    = current_view($user, $layout);

    my $records = GADS::Records->new(user => $user, layout => $layout, schema => schema);
    $records->search(
        view    => $view,
        from    => $fromdt,
        to      => $todt,
    );

    header "Cache-Control" => "max-age=0, must-revalidate, private";
    content_type 'application/json';
    encode_json({
        "success" => 1,
        "result"  => $records->data_calendar,
    });
};

sub _data_graph
{   my $id = shift;
    my $user    = logged_in_user;
    my $layout  = GADS::Layout->new(user => $user, schema => schema);
    my $view    = current_view($user, $layout);
    my $graph   = GADS::Graph->new(id => $id, schema => schema);
    my $records = GADS::Records->new(user => $user, layout => $layout, schema => schema);
    # Columns is either the x-axis, or if not defined, all the columns in the view
    my @columns = ($graph->y_axis, $graph->group_by);
    push @columns,
        $graph->x_axis || @{$view->columns};
    $records->search(
        view    => $view,
        columns => \@columns,
    );
    GADS::Graph::Data->new(id => $id, records => $records, schema => schema);
}

get '/data_graph/:id/:time' => require_login sub {

    my $id      = param 'id';
    my $gdata = _data_graph($id);

    header "Cache-Control" => "max-age=0, must-revalidate, private";
    content_type 'application/json';
    encode_json({
        points  => $gdata->points,
        labels  => $gdata->labels_encoded,
        xlabels => $gdata->xlabels,
    });
};

get '/search' => require_login sub {

    my $search = param 'search';
    my $user = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);
    my $records = GADS::Records->new(schema => schema, user => $user, layout => $layout);
    my @results = $records->search_all_fields($search);

    # Redirect to record if only one result
    redirect "/record/$results[0]->{current_id}"
        if @results == 1;
    template 'search' => {
        results => \@results,
        search  => $search,
        page    => 'search',
    };
};

any '/data' => require_login sub {

    my $user   = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);

    # Deal with any alert requests
    if (my $alert_view = param 'alert')
    {
        my $alert = GADS::Alert->new(
            user      => $user,
            layout    => $layout,
            schema    => schema,
            frequency => param('frequency'),
            view_id   => $alert_view,
        );
        if (process(sub { $alert->write }))
        {
            return forwardHome(
                { success => "The alert has been saved successfully" }, 'data' );
        }
    }

    if (my $view_id = param('view'))
    {
        session 'view_id' => $view_id;
        # Save to databse for next login
        update_current_user lastview => $view_id;
        # When a new view is selected, unset sort, otherwise it's
        # not possible to remove a sort once it's been clicked
        session 'sort'    => undef;
    }

    if (my $rows = param('rows'))
    {
        session 'rows' => int $rows;
    }

    if (my $page = param('page'))
    {
        session 'page' => int $page;
    }

    my $viewtype;
    if ($viewtype = param('viewtype'))
    {
        if ($viewtype eq 'graph' || $viewtype eq 'table' || $viewtype eq 'calendar')
        {
            session 'viewtype' => $viewtype;
        }
    }
    else {
        $viewtype = session('viewtype') || 'table';
    }

    my $view       = current_view($user, $layout);

    my $params = {
        page => 'data',
    }; # Variable for the template

    if ($viewtype eq 'graph')
    {
        $params->{viewtype} = 'graph';
        if (my $png = param('png'))
        {
            $params->{scheme}       = 'http';
            $params->{single_graph} = 1;
            my $public              = path(setting('appdir'), 'public');
            $params->{base}         = "file://$public/";
            my $graph_html          = template 'data_graph' => $params;
            my ($fh, $filename)     = tempfile(SUFFIX => '.html');
            print $fh $graph_html;
            close $fh;
            my $mech = WWW::Mechanize::PhantomJS->new;
            $mech->get_local($filename);
            unlink $filename;
            my $gdata = _data_graph($png);
            my $json  = encode_json {
                points  => $gdata->points,
                labels  => $gdata->labels_encoded,
                xlabels => $gdata->xlabels,
            };
            my $graph = GADS::Graph->new(
                layout => $layout,
                schema => schema
            );
            $graph->id($png);
            my $options_in = encode_json {
                type         => $graph->type,
                x_axis_name  => $graph->x_axis_name,
                y_axis_label => $graph->y_axis_label,
                stackseries  => \$graph->stackseries,
                showlegend   => \$graph->showlegend,
                id           => $png,
            };

            $mech->eval_in_page('(function(plotData, options_in){do_plot_json(plotData, options_in)})(arguments[0],arguments[1]);',
                $json, $options_in
            );

            my $png= $mech->content_as_png();
            return send_file(
                \$png,
                content_type => 'image/png',
                filename     => "graph".$graph->id.".png",
            );
        }
        elsif (my $csv = param('csv'))
        {
            my $graph = GADS::Graph->new(
                layout => $layout,
                schema => schema
            );
            $graph->id($csv);
            my $gdata       = _data_graph($csv);
            my $csv_content = $gdata->csv;
            return send_file(
                \$csv_content,
                content_type => 'text/csv',
                filename     => "graph".$graph->id.".csv",
            );
        }
        else {
            $params->{graphs} = GADS::Graphs->new(user => $user, schema => schema, layout => $layout)->all;
        }
    }
    elsif ($viewtype eq 'calendar')
    {
        # Get details of the view and work out color markers for date fields
        my @colors = qw/event-important event-success event-warning event-info event-inverse event-special/;
        my %datecolors;

        my @columns = $view
            ? $layout->view($view->id, user_can_read => 1)
            : $layout->all(user_can_read => 1);

        foreach my $column (@columns)
        {
            if ($column->type eq "daterange" || ($column->return_type && $column->return_type eq "date"))
            {
                $datecolors{$column->name} = shift @colors;
            }
        }

        $params->{calendar}   = session('calendar'); # Remember previous day viewed
        $params->{datecolors} = \%datecolors;
        $params->{viewtype}   = 'calendar';
    }
    else {
        session 'rows' => 50 unless session 'rows';
        session 'page' => 1 unless session 'page';

        my $rows = defined param('download') ? undef : session('rows');
        my $page = defined param('download') ? undef : session('page');

        my $records = GADS::Records->new(user => $user, layout => $layout, schema => schema);

        if (defined param('sort'))
        {
            my $sort     = int param 'sort';
            # Check user has access
            forwardHome({ danger => "Invalid column ID for sort" }, '/data')
                unless !$sort || ($layout->column($sort) && $layout->column($sort)->user_can('read'));
            my $existing = session('sort');
            if (!$existing && @{$view->sorts})
            {
                # Get first sort of existing view
                my $sort = $view->sorts->[0];
                $existing = {
                    id => $sort->{layout_id},
                    type => $sort->{type},
                };
            }
            my $type;
            if ($existing && $existing->{id} == $sort)
            {
                $type = $existing->{type} eq 'desc' ? 'asc' : 'desc';
            }
            else {
                $type = 'asc'; #$existing ? 'asc' : 'desc';
            }
            session 'sort' => { type => $type, id => $sort };
        }

        unless (session 'sort')
        {
            # Default sort if not set
            # Set here in case it's a hidden column
            my $config = GADS::Config->new(schema => schema);
            my $sort = {
                id   => $config->sort_layout_id,
                type => $config->sort_type,
            };
            # session 'sort' => $sort;
            $records->default_sort($sort);
        }

        $records->search(
            view    => $view,
            rows    => $rows,
            page    => $page,
            sort    => session('sort'),
            format  => (defined param('download') ? {plain => 1} : {encode_entities => 1}),
        );
        my $pages = $records->pages;

        my $subset = {
            rows  => session('rows'),
            pages => $pages,
            page  => $page,
        };

        if (param 'sendemail')
        {
            forwardHome({ danger => "There are no records in this view and therefore nobody to email"}, 'data')
                unless $records->results;

            return forwardHome(
                { danger => 'You do not have permission to send messages' }, 'data' )
                unless user_has_role 'message';

            my $params = params;

            my $email = GADS::Email->new(
                message_prefix => config->{gads}->{message_prefix},
                email_from     => config->{gads}->{email_from},
                subject        => param('subject'),
                text           => param('text'),
            );
            if (process( sub { $email->message($records, param('peopcol'), $user) }))
            {
                return forwardHome(
                    { success => "The message has been sent successfully" }, 'data' );
            }
        }

        if (defined param('download'))
        {
            forwardHome({ danger => "You do not have permission to download data"}, 'data')
                unless user_has_role 'download';

            forwardHome({ danger => "There are no records to download in this view"}, 'data')
                unless $records->results;

            my $csv = $records->csv;
            my $now = DateTime->now();
            my $header;
            if ($header = config->{gads}->{header})
            {
                $csv       = "$header\n$csv" if $header;
                $header    = "-$header" if $header;
            }
            return send_file( \$csv, content_type => 'text/csv', filename => "$now$header.csv" );
        }
        else {
            my @columns = $view
                ? $layout->view($view->id, user_can_read => 1)
                : $layout->all(user_can_read => 1);
            $params->{user_can_edit} = $layout->user_can('write_existing');
            $params->{sort}          = $records->sort;
            $params->{subset}        = $subset;
            $params->{records}       = $records->results;
            $params->{columns}       = \@columns;
            $params->{viewtype}      = 'table';
        }
    }

    # Get all alerts
    my $alert = GADS::Alert->new(
        user      => $user,
        layout    => $layout,
        schema    => schema,
    );

    my $views      = GADS::Views->new(user => $user, schema => schema, layout => $layout);

    $params->{v}               = $view,  # View is reserved TT word
    $params->{user_views}      = $views->user_views;
    $params->{alerts}          = $alert->all;
    $params->{user_can_create} = $layout->user_can('write_new');
    template 'data' => $params;
};

any '/account/?:action?/?' => require_login sub {

    my $action = param 'action';
    my $user   = logged_in_user;
    my $audit  = GADS::Audit->new(schema => schema, user => $user);

    if (param 'newpassword')
    {
        my $new_password = _random_pw();
        if (user_password password => param('oldpassword'), new_password => $new_password)
        {
            $audit->login_change("New password set for user");
            forwardHome({ success => qq(Your password has been changed to: $new_password)}, 'account/detail' );
        }
        else {
            forwardHome({ danger => "The existing password entered is incorrect"}, 'account/detail' );
        }
    }

    if (param 'graphsubmit')
    {
        if (process( sub { GADS::User->graphs($user, param('graphs')) }))
        {
            return forwardHome(
                { success => "The selected graphs have been updated" }, 'account/graph' );
        }
    }

    if (param 'submit')
    {
        my $params = params;
        # Update of user details
        my %update = (
            firstname    => param('firstname')    || undef,
            surname      => param('surname')      || undef,
            email        => param('email'),
            username     => param('email'),
            telephone    => param('telephone')    || undef,
            title        => param('title')        || undef,
            organisation => param('organisation') || undef,
            value        => _user_value($params),
        );

        if (process( sub { update_current_user realm => 'dbic', %update }))
        {
            $audit->login_change(
                "User updated own account details. New (or unchanged) email: $update{email}");
            return forwardHome(
                { success => "The account details have been updated" }, 'account/detail' );
        }
    }

    my $data;

    if ($action eq 'graph')
    {
        my $graphs = GADS::Graphs->new(user => $user, schema => schema);
        my $all_graphs = $graphs->all;
        template 'account' => {
            graphs => $all_graphs,
            action => $action,
            page   => 'account',
        };
    }
    elsif ($action eq 'detail')
    {
        template 'user' => {
            edit          => $user->{id},
            users         => [$user],
            titles        => GADS::User->titles,
            organisations => GADS::User->organisations,
            page          => 'account/detail'
        };
    }
    else {
        return forwardHome({ danger => "Unrecognised action $action" });
    }
};

any '/config/?' => require_role layout => sub {

    my $config = GADS::Config->new(schema => schema);

    if (param 'update')
    {
        $config->homepage_text(param 'homepage_text');
        $config->homepage_text2(param 'homepage_text2');
        $config->sort_layout_id(param 'sort_layout_id');
        $config->sort_type(param 'sort_type');

        if (process( sub { $config->write }))
        {
            return forwardHome(
                { success => "Configuration settings have been updated successfully" } );
        }
    }

    my $layout = GADS::Layout->new(
        user   => logged_in_user,
        schema => schema,
    );
    my @all_columns = $layout->all;
    template 'config' => {
        all_columns => \@all_columns,
        instance    => $config,
        page        => 'config'
    };
};


any '/graph/?:id?' => require_role layout => sub {

    my $layout = GADS::Layout->new(user => logged_in_user, schema => schema);
    my $params = {
        layout => $layout,
        page   => 'graph',
    };

    my $id = param 'id';
    if (defined $id)
    {
        my $graph = GADS::Graph->new(schema => schema);
        $graph->id($id) if $id;

        if (param 'delete')
        {
            if (process( sub { $graph->delete }))
            {
                return forwardHome(
                    { success => "The graph has been deleted successfully" }, 'graph' );
            }
        }

        if (param 'submit')
        {
            my $values = params;
            $graph->$_(param $_)
                foreach (qw/title description type x_axis x_axis_grouping y_axis
                    y_axis_label y_axis_stack group_by stackseries metric_group_id/);
            if(process( sub { $graph->write }))
            {
                my $action = param('id') ? 'updated' : 'created';
                return forwardHome(
                    { success => "Graph has been $action successfully" }, 'graph' );
            }
        }
        $params->{graph}         = $graph;
        $params->{dategroup}     = GADS::Graphs->dategroup;
        $params->{graphtypes}    = [GADS::Graphs->types];
        $params->{metric_groups} = GADS::MetricGroups->new(schema => schema)->all;
    }
    else {
        my $graphs = GADS::Graphs->new(schema => schema)->all;
        $params->{graphs} = $graphs;
    }

    template 'graph' => $params;
};

any '/metric/?:id?' => require_role layout => sub {

    my $layout = GADS::Layout->new(user => logged_in_user, schema => schema);
    my $params = {
        layout => $layout,
        page   => 'metric',
    };

    my $id = param 'id';
    if (defined $id)
    {
        my $metricgroup = GADS::MetricGroup->new(
            schema => schema,
            id     => $id,
        );

        if (param 'delete_all')
        {
            if (process( sub { $metricgroup->delete }))
            {
                return forwardHome(
                    { success => "The metric has been deleted successfully" }, 'metric' );
            }
        }

        # Delete an individual item from a group
        if (param 'delete_metric')
        {
            if (process( sub { $metricgroup->delete_metric(param 'metric_id') }))
            {
                return forwardHome(
                    { success => "The metric has been deleted successfully" }, "metric/$id" );
            }
        }

        if (param 'submit')
        {
            $metricgroup->name(param 'name');
            if(process( sub { $metricgroup->write }))
            {
                my $action = param('id') ? 'updated' : 'created';
                return forwardHome(
                    { success => "Metric has been $action successfully" }, 'metric' );
            }
        }

        # Update/create an individual item in a group
        if (param 'update_metric')
        {
            my $metric = GADS::Metric->new(
                id                    => param('metric_id') || undef,
                metric_group_id       => $id,
                x_axis_value          => param('x_axis_value'),
                y_axis_grouping_value => param('y_axis_grouping_value'),
                target                => param('target'),
                schema                => schema,
            );
            if(process( sub { $metric->write }))
            {
                my $action = param('id') ? 'updated' : 'created';
                return forwardHome(
                    { success => "Metric has been $action successfully" }, "metric/$id" );
            }
        }

        $params->{metricgroup} = $metricgroup;
    }
    else {
        my $metrics = GADS::MetricGroups->new(schema => schema)->all;
        $params->{metrics} = $metrics;
    }

    template 'metric' => $params;
};

any '/group/?:id?' => require_role useradmin => sub {

    my $id = param 'id';
    my $group  = GADS::Group->new(schema => schema);
    my $layout = GADS::Layout->new(user => logged_in_user, schema => schema);
    $group->from_id($id);

    if (param 'submit')
    {
        $group->name(param 'name');

        if (process(sub {$group->write}))
        {
            my $action = param('id') ? 'updated' : 'created';
            return forwardHome(
                { success => "Group has been $action successfully" }, '/group' );
        }
    }

    if (param 'delete')
    {
        if (process(sub {$group->delete}))
        {
            return forwardHome(
                { success => "The group has been deleted successfully" }, '/group' );
        }
    }

    my $params = {
        page => 'group'
    };

    if (defined $id)
    {
        # id will be 0 for new group
        $params->{group} = $group;
    }
    else {
        my $groups = GADS::Groups->new(schema => schema);
        $params->{groups} = $groups->all;
        $params->{layout} = $layout;
    }
    template 'group' => $params;
};

any '/view/:id' => require_login sub {

    return forwardHome(
        { danger => 'You do not have permission to edit views' }, 'data' )
        unless user_has_role 'view_create';

    my $view_id = param('id');
    $view_id = param('clone') if param('clone') && !request->is_post;
    my @ucolumns; my $view_values;

    my $user = logged_in_user;
    my $layout = GADS::Layout->new(
        user   => $user,
        schema => schema,
    );
    my %vp = (
        user   => $user,
        schema => schema,
        layout => $layout,
    );
    $vp{id} = $view_id if $view_id;
    my $view = GADS::View->new(%vp);

    if (param 'update')
    {
        my $params = params;
        my $columns = ref param('column') ? param('column') : [ param('column') // () ]; # Ensure array
        $view->columns($columns);
        $view->global (param('global') ? 1 : 0);
        $view->name   (param 'name');
        $view->filter (param 'filter');
        if (process( sub { $view->write }))
        {
            $view->set_sorts($params->{sortfield}, $params->{sorttype});
            # Set current view to the one created/edited
            session 'view_id' => $view->id;
            return forwardHome(
                { success => "The view has been updated successfully" }, 'data' );
        }
    }

    if (param 'delete')
    {
        session 'view_id' => undef;
        if (process( sub { $view->delete }))
        {
            return forwardHome(
                { success => "The view has been deleted successfully" }, 'data' );
        }
    }

    my $output = template 'view' => {
        all_columns  => [$layout->all(user_can_read => 1)],
        sort_types   => $view->sort_types,
        v            => $view, # TT does not like variable "view"
        page         => 'view'
    };
    $output;
};

any qr{/tree[0-9]*/([0-9]*)/?([0-9]*)} => require_login sub {
    # Random number can be used after "tree" to prevent caching

    my ($layout_id, $value) = splat;

    my $tree = GADS::Column::Tree->new(schema => schema);

    if (param 'data')
    {
        return forwardHome(
            { danger => 'You do not have permission to edit trees' } )
            unless user_has_role 'layout';

        $tree->id($layout_id);
        my $newtree = JSON->new->utf8(0)->decode(param 'data');
        $tree->update($newtree);
        return;
    }
    header "Cache-Control" => "max-age=0, must-revalidate, private";

    # If record is specified, select the record's value in the returned JSON
    $tree->from_id($layout_id) if $layout_id; # Blank for new trees
    header "Cache-Control" => "max-age=0, must-revalidate, private";
    content_type 'application/json';
    encode_json($tree->json($value));

};

any '/layout/?:id?' => require_role 'layout' => sub {

    my $user        = logged_in_user;
    my $layout      = GADS::Layout->new(user => $user, schema => schema);
    my @all_columns = $layout->all;

    my $params = {
        page        => 'layout',
        all_columns => \@all_columns,
    };

    if (param('id') || param('submit') || param('update_perms'))
    {
        my $id = param('id');
        my $class = (param('type') && grep {param('type') eq $_} GADS::Column::types)
                  ? param('type')
                  : rset('Layout')->find($id)->type;
        $class = "GADS::Column::".camelize($class);
        my $column = $class->new(schema => schema, user => $user, layout => $layout);
        $column->from_id($id) if $id;
        
        # Update of permissions?
        if (param 'update_perms')
        {
            my $permissions = ref param('permissions') eq 'ARRAY' ? param('permissions') : [param('permissions') || ()];
            $column->set_permissions(param('group_id'), $permissions);
        }

        if (param 'delete')
        {
            if (process( sub { $column->delete }))
            {
                return forwardHome(
                    { success => "The item has been deleted successfully" }, 'layout' );
            }
        }

        if (param 'submit')
        {
            $column->$_(param $_)
                foreach (qw/name type description helptext optional remember/);
            if (param 'display_condition')
            {
                $column->display_field(param 'display_field');
                $column->display_regex(param 'display_regex');
            }
            else {
                $column->display_field(undef);
            }
            if ($column->type eq "file")
            {
                $column->filesize(param('filesize') || undef) if $column->type eq "file";
            }
            elsif ($column->type eq "rag")
            {
                $column->red  (param 'red');
                $column->amber(param 'amber');
                $column->green(param 'green');
                $column->base_url(request->base); # For alerts
            }
            elsif ($column->type eq "enum")
            {
                my $params = params;
                $column->enumvals_from_form($params);
                $column->ordering(param('ordering') || undef);
            }
            elsif ($column->type eq "calc")
            {
                $column->calc(param 'calc');
                $column->return_type(param 'return_type');
                $column->base_url(request->base); # For alerts
            }
            elsif ($column->type eq "tree")
            {
                $column->end_node_only(param 'end_node_only');
            }

            if (process( sub { $column->write }))
            {
                my $action = param('id') ? 'updated' : 'created';
                return forwardHome(
                    { success => "Item has been $action successfully" }, 'layout' );
            }
        }
        $params->{column} = $column;
        $params->{groups} = GADS::Groups->new(schema => schema);
        $params->{permissions} = [GADS::Type::Permissions->all];
    }
    elsif (defined param('id'))
    {
        $params->{column} = 0; # New
        $params->{groups} = GADS::Groups->new(schema => schema);
        $params->{permissions} = [GADS::Type::Permissions->all];
    }

    if (param 'saveposition')
    {
        if (process( sub { $layout->position(param('position')) }))
        {
            return forwardHome(
                { success => "The ordering has been saved successfully" }, 'layout' );
        }
    }

    template 'layout' => $params;
};

any '/user/?:id?' => require_role useradmin => sub {
    my $id = param 'id';

    my $user   = logged_in_user;
    my $audit  = GADS::Audit->new(schema => schema, user => $user);
    my $users;

    # The submit button will still be triggered on a new org/title creation,
    # if the user has pressed enter, in which case ignore it
    if (param('submit') && !param('neworganisation') && !param('newtitle'))
    {
        if (param 'account_request')
        {
            # Check user doesn't already exist
            my $email = param('email');
            return forwardHome({ danger => "User $email already exists" }, 'user' )
                if GADS::User->get_user(email => $email, account_request => 0);
        }
        my %all_permissions = map { $_->id => $_->name } @{GADS::User->permissions};
        my @permissions = ref param('permission') ? @{param('permission')} : (param('permission') || ());
        my %permissions = map { $all_permissions{$_} => 1 } @permissions;
        my %values = (
            firstname       => param('firstname'),
            surname         => param('surname'),
            email           => param('email'),
            username        => param('email'),
            telephone       => param('telephone'),
            title           => param('title') || undef,
            organisation    => param('organisation') || undef,
            permission      => \%permissions,
        );

        $values{value} = _user_value(\%values);

        my $newuser; my $result;
        if (!param('account_request') && param('username')) # Original username to update (hidden field)
        {
            if (!Email::Valid->address(param('email')))
            {
                messageAdd({ danger => "Please enter a valid email address for the new user" });
            }
            else {
                $result = process( sub { $newuser = update_user param('username'), realm => 'dbic', %values });
            }
        }
        else {
            # Delete account request user if this is a new account request
            if (!param('email'))
            {
                messageAdd({ danger => "An email address must be specified for the new user" });
            }
            elsif (!Email::Valid->address(param('email')))
            {
                messageAdd({ danger => "Please enter a valid email address for the new user" });
            }
            else {
                GADS::User->delete($id)
                    if param 'account_request';
                $result = process( sub { $newuser = create_user %values, realm => 'dbic', email_welcome => 1 });
                $id = 0; # Previous ID now deleted
            }
        }
        if ($result)
        {
            # Add groups to user
            my @groups = ref param('groups') ? @{param('groups')} : (param('groups') || ());
            GADS::User->groups($newuser, \@groups);
            my $action;
            my $audit_perms = join ', ', keys %{$newuser->{permission}};
            if ($id) {
                $audit->login_change(
                    "User updated: ID $newuser->{id}, username: $newuser->{username}; permissions: $audit_perms");
                $action = 'updated';
            }
            else {
                $audit->login_change(
                    "New user created: ID $newuser->{id}, username: $newuser->{username}; permissions: $audit_perms");
                $action = 'created';
            }

            return forwardHome(
                { success => "User has been $action successfully" }, 'user' );
        }
        else {
            $users = [\%values];
        }
    }

    my $register_requests;
    if (param('neworganisation') || param('newtitle'))
    {
        if (my $org = param 'neworganisation')
        {
            if (process( sub { GADS::User->organisation_new({ name => $org })}))
            {
                $audit->login_change("Organisation $org created");
                messageAdd({ success => "The organisation has been created successfully" });
            }
        }

        if (my $title = param 'newtitle')
        {
            if (process( sub { GADS::User->title_new({ name => $title }) }))
            {
                $audit->login_change("Title $title created");
                messageAdd({ success => "The title has been created successfully" });
            }
        }

        $users = [{
            firstname    => param('firstname'),
            surname      => param('surname'),
            email        => param('email'),
            title        => { id => param('title') },
            organisation => { id => param('organisation') },
        }];
    }
    elsif (my $delete_id = param('delete'))
    {
        return forwardHome(
            { danger => "Cannot delete current logged-in User" } )
            if logged_in_user->{id} eq $delete_id;
        if (process( sub { GADS::User->delete($delete_id, send_reject_email => 1) }))
        {
            $audit->login_change("User ID $delete_id deleted");
            return forwardHome(
                { success => "User has been deleted successfully" }, 'user' );
        }
    }

    if ($id)
    {
        $users = [ GADS::User->get_user(id => $id) ] if !$users;
    }
    elsif (!defined $id) {
        $users             = GADS::User->all;
        $register_requests = GADS::User->register_requests;
    }

    my $output = template 'user' => {
        edit              => $id,
        users             => $users,
        groups            => GADS::Groups->new(schema => schema)->all,
        register_requests => $register_requests,
        titles            => GADS::User->titles,
        organisations     => GADS::User->organisations,
        permissions       => GADS::User->permissions,
        page              => 'user'
    };
    $output;
};

any '/approval/?:id?' => require_login sub {
    my $id   = param 'id';
    my $user = logged_in_user;

    my $layout = GADS::Layout->new(user => $user, schema => schema);

    # If we're viewing or approving an individual record, first
    # see if it's a new record or edit of existing. This affects
    # permissions
    my $approval_of_new = $id
        ? GADS::Record->new(
            user               => $user,
            layout             => $layout,
            schema             => schema,
            include_approval   => 1,
            record_id          => $id,
        )->approval_of_new
        : 0;

    my @columns_to_show = $approval_of_new ? $layout->all(user_can_approve_new => 1)
        : $layout->all(user_can_approve_existing => 1);

    if (param 'submit')
    {
        # Get latest record for this approval
        my $record = GADS::Record->new(
            user             => $user,
            layout           => $layout,
            schema           => schema,
            approval_id      => $id,
            doing_approval   => 1,
            base_url         => request->base,
        );
        # See if the record exists as a "normal" entry. In the case
        # of an approval for a new record, this will not be the case,
        # so catch the resulting exception, and create a new record,
        # but set the current ID.
        unless (try { $record->find_current_id(param 'current_id') })
        {
            $record->current_id(param 'current_id');
            $record->initialise;
        }
        my $uploads = request->uploads;
        foreach my $key (keys %$uploads)
        {
            next unless $key =~ /^file([0-9]+)/;
            my $upload = $uploads->{$key};
            my $col_id = $1;
            $record->fields->{$col_id}->set_value({
                name     => $upload->filename,
                mimetype => $upload->type,
                content  => $upload->content,
            });
        }
        my $failed;
        foreach my $col (@columns_to_show)
        {
            if ($col->userinput) # Not calculated fields
            {
                # No need to do anything if the file's just been uploaded
                if (my $newv = param($col->field))
                {
                    $failed = !process( sub { $record->fields->{$col->id}->set_value($newv) } ) || $failed;
                }
            }
        }
        if (!$failed && process( sub { $record->write }))
        {
            return forwardHome(
                { success => 'Record has been successfully approved' }, 'approval' );
        }
    }

    my $page;
    my $params = {
        all_columns => \@columns_to_show,
        page        => 'approval',
    };

    if ($id)
    {
        # Get the record of values needing approval
        my $record = GADS::Record->new(
            user             => $user,
            init_no_value    => 0,
            layout           => $layout,
            include_approval => 1,
            schema           => schema,
        );
        $record->find_record_id($id);
        $params->{record} = $record;

        # Get existing values for comparison
        unless ($approval_of_new)
        {
            my $existing = GADS::Record->new(
                user            => $user,
                layout          => $layout,
                schema          => schema,
            );
            $existing->find_current_id($record->current_id);
            $params->{existing} = $existing;
        }
        $page  = 'edit';
    }
    else {
        $page  = 'approval';
        my $approval = GADS::Approval->new(
            schema => schema,
            user   => $user,
            layout => $layout
        );
        $params->{records} = $approval->records;
    }

    template $page => $params;
};

get '/helptext/:id?' => require_login sub {
    my $id     = param 'id';
    my $user   = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);
    my $column = GADS::Column->new(schema => schema, user => $user, layout => $layout);
    $column->from_id(param 'id');
    template 'helptext.tt', { column => $column }, { layout => undef };
};

any '/edit/:id?' => require_login sub {
    my $id = param 'id';

    my $user   = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);
    my $record = GADS::Record->new(
        user     => $user,
        layout   => $layout,
        schema   => schema,
        base_url => request->base,
    );

    my @columns_to_show = $id
        ? $layout->all(user_can_readwrite_existing => 1)
        : $layout->all(user_can_write_new => 1);

    if ($id)
    {
        $record->find_current_id($id);
    }

    if (param 'submit')
    {
        $record->initialise unless $id;
        my $params = params;
        my $uploads = request->uploads;
        foreach my $key (keys %$uploads)
        {
            next unless $key =~ /^file([0-9]+)/;
            my $upload = $uploads->{$key};
            my $col_id = $1;
            my $filecol = $layout->column($col_id);
            $record->fields->{$col_id}->set_value({
                name     => $upload->filename,
                mimetype => $upload->type,
                content  => $upload->content,
            });
        }
        my $failed;
        # We actually only need the write columns for this. The read-only
        # columns can be ignored, but if we do write them, an error will be
        # thrown to the user if they've been changed. This is better than
        # just silently ignoring them, IMHO.
        foreach my $col (@columns_to_show)
        {
            if ($col->userinput) # Not calculated fields
            {
                # No need to do anything if the file's just been uploaded
                unless (upload "file".$col->id)
                {
                    my $newv = param($col->field);
                    $failed = !process( sub { $record->fields->{$col->id}->set_value($newv) } ) || $failed;
                }
            }
        }
        if (!$failed && process( sub { $record->write }))
        {
            return forwardHome(
                { success => 'Submission has been completed successfully' }, 'data' );
        }
    }
    elsif($id) {
        $record->find_current_id($id);
    }
    elsif(my $previous = $user->{lastrecord})
    {
        # Prefill previous values, but only those tagged to be remembered
        my @remember = map {$_->id} $layout->all(remember => 1);
        $record->columns(\@remember);
        $record->include_approval(1);
        $record->init_no_value(0);
        $record->find_record_id($previous);
        $record->columns_retrieved(\@columns_to_show); # Force all columns to be shown
        if ($record->approval_flag)
        {
            # The last edited record was one for approval. This will
            # be missing values, so get its associated main record,
            # and use the values for that too.
            my $related = GADS::Record->new(
                user             => $user,
                layout           => $layout,
                schema           => schema,
                include_approval => 1,
                base_url         => request->base,
            );
            $related->find_record_id($record->approval_record_id);
            foreach my $col (@columns_to_show)
            {
                next unless $col->userinput;
                # See if the record above had a value. If not, fill with the
                # approval record's value
                $record->fields->{$col->id} = $related->fields->{$col->id}
                    if !$record->fields->{$col->id}->has_value && $col->remember;
            }
        }
        $record->current_id(undef);
    }
    else {
        $record->initialise;
    }

    foreach my $col ($layout->all(user_can_write => 1))
    {
        $record->fields->{$col->id}->set_value("")
            if !$col->user_can('read');
    }
    my $output = template 'edit' => {
        record      => $record,
        all_columns => \@columns_to_show,
        page        => 'edit'
    };
    $output;
};

# Simple method to get the dependent regex expression for a column.
# It's a lot easier sending as a separate request, than trying
# to encode into the main page (with multiple escapes etc)
get '/display_regex/:id?' => require_login sub {
    my $user   = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);
    my $column = $layout->column(param 'id') or return;
    $column->display_regex;
};

any '/file/:id' => require_login sub {
    my $id = param 'id';
    my $file;
    process (sub { $file = GADS::Datum::File->get_file($id, schema, logged_in_user) });
    send_file( \($file->content), content_type => $file->mimetype, filename => $file->name );
};

any qr{/(record|history)/([0-9]+)} => require_login sub {

    my ($action, $id) = splat;

    my $user   = logged_in_user;
    my $layout = GADS::Layout->new(user => $user, schema => schema);
    my $record = GADS::Record->new(
        user   => $user,
        layout => $layout,
        schema => schema,
    );

      $action eq 'history'
    ? $record->find_record_id($id)
    : $record->find_current_id($id);

    my @versions = $record->versions;

    if (my $delete_id = param 'delete')
    {
        if (process( sub { $record->delete_current }))
        {
            return forwardHome(
                { success => 'Record has been deleted successfully' }, 'data' );
        }
    }

    my @columns = $layout->all(user_can_read => 1);
    my $output = template 'record' => {
        record         => $record,
        user_can_edit  => $layout->user_can('write_existing'),
        versions       => \@versions,
        all_columns    => \@columns,
        page           => 'record'
    };
    $output;
};

sub reset_text {
    my ($dsl, %options) = @_;
    my $name = config->{gads}->{name};
    my $url  = request->base . "resetpw/$options{code}";
    my $body = <<__BODY;
A request to reset your $name password has been received. Please
click on the following link to set and retrieve a new password:

$url
__BODY
    (
        from    => config->{gads}->{email_from},
        subject => 'Password reset request',
        plain   => $body,
    )
}

sub welcome_text
{   my ($dsl, %options) = @_;
    my $name = config->{gads}->{name};
    my $url  = request->base . "resetpw/$options{code}";
    my $new_account = config->{gads}->{new_account};
    my $subject = $new_account && $new_account->{subject}
        || "Your new account details";
    my $body = $new_account && $new_account->{body} || <<__BODY;

An account for $name has been created for you. Please
click on the following link to retrieve your password:

[URL]
__BODY

    $body =~ s/\Q[URL]/$url/;
    (
        from    => config->{gads}->{email_from},
        subject => $subject,
        plain   => $body,
    );
}

get '/login/denied' => sub {
    forwardHome({ danger => "You do not have permission to access this page" });
};

any '/login' => sub {

    my $audit = GADS::Audit->new(schema => schema);
    my $user  = logged_in_user;

    # Don't allow login page to be displayed when logged-in, to prevent
    # user thinking they are logged out when they are not
    return forwardHome({}, '') if $user;

    # Request a password reset
    if (param('resetpwd'))
    {
        my $username = param('emailreset');
        $audit->login_change("Password reset request for $username");
        defined password_reset_send(username => $username)
        ? messageAdd( { success => 'An email has been sent to your email address with a link to reset your password' } )
        : messageAdd( { danger => 'Failed to send a password reset link. Did you enter a valid email address?' } );
    }

    my $error;

    if (param 'register')
    {
        my $params = params;
        try { GADS::User->register($params) };
        if(my $exception = $@->wasFatal)
        {
            $error = $exception->message->toString;
        }
        else {
            $audit->login_change("New user account request for $params->{email}");
            return forwardHome({ success => "Your account request has been received successfully" });
        }
    }

    if (param('signin'))
    {
        my ($success, $realm) = authenticate_user(
            params->{username}, params->{password}
        );
        if ($success) {
            session logged_in_user => params->{username};
            session logged_in_user_realm => $realm;
            if (param 'remember_me')
            {
                cookie 'remember_me' => param('username'), expires => '60d' if param('remember_me');
            }
            else {
                cookie remember_me => '', expires => '-1d' if cookie 'remember_me';
            }
            $user = logged_in_user;
            $audit->user($user);
            $audit->login_success;
            forwardHome();
        }
        else {
            $audit->login_failure(param 'username');
            messageAdd({ danger => "The username or password was not recognised" });
        }
    }

    my $config = GADS::Config->new(schema => schema);
    my $output  = template 'login' => {
        error         => "".($error||""),
        instance      => $config,
        username      => cookie('remember_me'),
        titles        => GADS::User->titles,
        organisations => GADS::User->organisations,
        register_text => GADS::User->register_text,
        page          => 'login',
    };
    $output;
};

any '/logout' => sub {
    app->destroy_session;
    forwardHome();
};

get '/resetpw/:code' => sub {

    # Perform check first in order to get user ID for audit
    if (my $username = user_password code => param('code'))
    {
        context->destroy_session;
        my $user   = GADS::User->get_user(username => $username, account_request => 0);
        my $audit  = GADS::Audit->new(schema => schema, user => $user);
        $audit->login_change("Password reset performed for user ID $user->{id}");
        my $password = _random_pw();
        user_password code => param('code'), new_password => $password;
        my $output  = template 'login' => {
            password => $password,
            page     => 'login',
        };
        $output;
    }
    else {
        return forwardHome(
            { danger => "The requested authorisation code could not be processed" }, 'login'
        );
    }
};

sub current_view {
    my ($user, $layout) = @_;

    my $views      = GADS::Views->new(user => $user, schema => schema, layout => $layout);
    my $saved_view = $user->{lastview};
    my $view       = $views->view(session('view_id') || $saved_view) || $views->default; # Can still be undef
    $view;
};

sub forwardHome {
    if (my $message = shift)
    {
        messageAdd($message);
    }
    my $page = shift || '';
    redirect "/$page";
}

sub messageAdd($) {
    my $message = shift;
    return unless keys %$message;
    my $text    = ( values %$message )[0];
    my $type    = ( keys %$message )[0];
    my $msgs    = session 'messages';
    push @$msgs, { text => encode_entities($text), type => $type };
    session 'messages' => $msgs;
}

sub error_handler
{   my ($disp, $options, $reason, $message) = @_;

    if ($reason =~ /(TRACE|ASSERT|INFO)/)
    {
        # Debug info. Log to syslog.
    }
    elsif ($reason eq 'NOTICE')
    {
        # Notice that something has happened. Not an error.
        messageAdd({ info => "$message" });
    }
    elsif ($reason =~ /(WARNING|MISTAKE)/)
    {
        # Non-fatal problem. Show warning.
        messageAdd({ warning => "$message" });
    }
    elsif ($reason eq 'ERROR') {
        # A user-created error condition that is not recoverable.
        # This could have already been caught by the process
        # subroutine, in which case we should continue running
        # of the program. In all other cases, we should bail
        # out. With the former, the exception will have been
        # re-thrown as a non-fatal exception, so check that.
        exists $options->{is_fatal} && !$options->{is_fatal}
            ? messageAdd({ danger => "$message" })
            : forwardHome({ danger => "$message" });
    }
    else {
        # 'FAULT', 'ALERT', 'FAILURE', 'PANIC'
        # All these are fatal errors. Display error to user, but
        # forward home so that we can reload. However, don't if
        # it's a GET request to the home, as it will cause a recursive
        # loop. In this case, do nothing, and let dancer handle it.
        forwardHome({ danger => "$message" })
            unless request->uri eq '/' && request->is_get;
    }
}

# This runs a code block and catches errors, which in then
# handles in a more graceful manner, throwing as required
sub process
{
    my $coderef = shift;
    try {&$coderef};
    my $result = $@ ? 0 : 1; # Return true on success
    if (my $exception = $@->wasFatal)
    {
        $exception->throw(is_fatal => 0);
    }
    else {
        $@->reportAll;
    }
    $result;
}

sub _random_pw
{
    my $foo = new String::Random;
    $foo->{'v'} = [ 'a', 'e', 'i', 'o', 'u' ];
    $foo->{'i'} = [ 'b'..'d', 'f'..'h', 'j'..'n', 'p'..'t', 'v'..'z' ];
    scalar $foo->randpattern("iviiviivi");
}

sub _user_value
{   my $user = shift;
    return unless $user;
    my $firstname = $user->{firstname} || '';
    my $surname   = $user->{surname}   || '';
    my $value     = "$surname, $firstname";
    $value;
}

true;
