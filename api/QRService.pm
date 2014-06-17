# Service layer for QR objects
# Provide basic CRUD operations for core objects
# Provide specialized data retrieval for specific needs
#
# Joe Johnston <jjoh@taskboy.com>
#
package QRService;
use strict;
use DBI;
use Time::HiRes;
use Data::Dumper;
use Imager::QRCode;
use File::Temp ('tempdir');
use Cwd;
use FindBin;
require "$FindBin::Bin/../db.pl";

sub new
{
    my ($class) = shift;
    my %args = ("dbh" => get_dbh(),
                @_);
    
    return bless \%args, (ref $class || $class);
}

sub dbh
{
    return shift->{dbh};
}

sub _Exec
{
    my ($self, $sth, @params) = @_;
    unless ($sth->execute(@params))
    {
        warn("\n$sth->{Statement}\n" . $sth->errstr);
        return;
    }

    if ($sth->{Statement} =~ /SELECT/)
    {
        return $sth->fetchall_arrayref({});
    }

    return 1;   
}

sub _Delete
{
    my ($self, $table, $id) = @_;

    unless ($id)
    {
        warn("No '$table' ID\n");
        return;
    }
    
    my $sth = $self->dbh->prepare("DELETE FROM `$table` WHERE id=?");
    return $self->_Exec($sth, $id);
}

sub _Update
{
    my ($self, $table) = (shift, shift);
    my %args = @_;

    my $id = delete $args{id};

    my @vals;
    my @tmp;
    while (my ($k, $v) = each %args)
    {
        if (defined $v)
        {
            push @tmp, "$k=?";
            push @vals, $v;
        }
    }
    push @vals, $id;

    my $upd = join(",", @tmp);
    my $sql = "UPDATE `$table` SET $upd WHERE id=?";
    my $sth = $self->dbh->prepare($sql);
    unless ($self->_Exec($sth, @vals))
    {
        return;
    }
}

sub _Insert
{
    my ($self, $table) = (shift, shift);
    my %args = @_;

    my @vals;
    my @tmp;
    while (my ($k, $v) = each %args)
    {
        if (defined $v)
        {
            push @tmp, $k;
            push @vals, $v;
        }
    }
    my $fields = join(",", @tmp);
    my $placeholders = join(",", ('?')x@tmp);

    my $sql = "INSERT INTO `$table` ($fields,created) VALUES ($placeholders,CURRENT_TIMESTAMP)";
    my $sth = $self->dbh->prepare($sql);
    unless ($self->_Exec($sth, @vals))
    {
        return;
    }

    # Some objects will generate their own ID
    return $args{id} || $sth->{mysql_insertid};
}

sub _List
{
    my ($self, $table, $order) = (shift, shift, shift);
    my %args = @_;

    my $dbh = $self->dbh;

    my $where = join(" AND ", map { "$_=?" } grep { defined $args{$_} }  keys %args);
    $where = " WHERE $where" if $where;
    my @values = map { $args{$_} } grep { defined $args{$_} }  keys %args;

    if ($order)
    {
        $order = "ORDER BY $order";
    }

    my $sql = qq[SELECT *,DATE(created) AS created,DATE(updated) AS updated FROM `$table` $where $order];
    my $sth = $dbh->prepare($sql);
    return $self->_Exec($sth, @values);
}
sub _get_id
{
    my $id = Time::HiRes::time();
    $id =~ s/\./_/;
    return $id;
}

#---------------
# Object-specific CRUD operations
#---------------
# Programs
sub get_program
{
    my ($self, $id) = @_;
    my $list = $self->list_programs(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_programs
{
    my ($self) = shift;
    my %args = (id => undef, 
                "name" => undef,
                "user_id" => undef,
                "start_date" => undef,
                "end_date" => undef,
                @_);

    return $self->_List("programs", "created ASC", %args); 
}

sub save_program
{
    my ($self) = shift;
    my %args = ("id" => undef, 
                "name" => undef, 
                "user_id" => undef,
                "start_date" => undef,
                "end_date" => undef,
                @_);

    if ($args{id})
    {
        unless ($self->_Update("programs", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_Insert("programs", %args);
        unless ($args{id})
        {
            return;
        }       
    }

    return $args{id};
}

sub delete_program
{
    my ($self, $id) = @_;

    unless ($id)
    {
        warn("No program ID\n");
        return;
    }
    
    my $dbh = $self->dbh;

    my $steps = $self->list_steps("program_id" => $id);
    for my $s (@$steps)
    {
        unless ($self->delete_step($s->{id}))
        {
            return;
        }
    }

    my $excl_groups = $self->list_exclusive_group("program_id" => $id);
    for my $s (@$excl_groups)
    {
        unless ($self->delete_exclusive_group($s->{id}))
        {
            return;
        }
    }

    return $self->_Delete("programs", $id);
}

# Steps
sub get_step
{
    my ($self, $id) = @_;
    my $list = $self->list_steps(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_steps
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "program_id" => undef,
                "operation" => undef,
                "param1" => undef,
                "seq" => undef,
                "exclusive_group" => undef,
                "title" => undef,
                @_);

    return $self->_List("steps", "seq ASC", %args);
}

sub save_step
{
    my ($self) = shift;
    my %args = ("id" => undef, 
                "program_id" => undef,
                "operation" => undef,
                "param1" => undef,
                "seq" => undef,
                "exclusive_group" => undef,
                "dependencies" => undef,
                "title" => undef,
                "error_url" => undef,
                @_);

    if ($args{id})
    {
        unless ($self->_Update("steps", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_Insert("steps", %args);
        unless ($args{id})
        {
            return;
        }       
    }

    return $args{id};

}

sub delete_step
{
    my ($self, $id) = @_;
    return $self->_Delete("steps", $id);
}

# Exclusive groups
sub get_exclusive_group
{
    my ($self, $id) = @_;
    my $list = $self->list_exclusive_group(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_exclusive_group
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "program_id" => undef,
                "name" => undef,
                @_);
    return $self->_List("exclusive_groups", "created", %args); 
}

sub save_exclusive_group
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "program_id" => undef,
                "name" => undef,
                @_);

    if ($args{id})
    {
        unless ($self->_Update("exclusive_groups", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_get_id();
        $args{id} = $self->_Insert("exclusive_groups", %args); 
        unless ($args{id})
        {
            return;
        }
    }
    
    return $args{id};
}

sub delete_exclusive_group
{
    my ($self, $id) = @_;
    return $self->_Delete("exclusive_groups", $id);
}

# Users
sub get_user
{
    my ($self, $id) = @_;
    my $list = $self->list_users(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_users
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "email" => undef,
                "screen_name" => undef,
                "twitter_id" => undef,
                "is_admin" => undef,
                @_);
    return $self->_List("users", "screen_name", %args);
}

sub save_user
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "email" => undef,
                "screen_name" => undef,
                "twitter_id" => undef,
                "access_token" => undef,
                "access_secret" => undef,
                "is_admin" => undef,
                @_
               );

    if ($args{id})
    {
        unless ($self->_Update("users", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_Insert("users", %args);
        unless ($args{id})
        {
            return;
        }       
    }

    return $args{id};

}

sub delete_user
{
    my ($self, $id) = @_;
    return $self->_Delete("users", $id);
}

# Game Log
sub get_log
{
    my ($self, $id) = @_;
    my $list = $self->list_log(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_log
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "location" => undef,
                "notes" => undef,
                "step_id" => undef,
                "session_id" => undef,
                @_);
    return $self->_List("game_log", "created", %args);
}

sub delete_log
{
    my ($self, $id) = @_;
    return $self->_Delete("game_log", $id);   
}

sub save_log
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "location" => undef, 
                "notes" => undef,
                "step_id" => undef,
                "session_id" => undef,
                @_);

    if ($args{id})
    {
        unless ($self->_Update("game_log", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_Insert("game_log", %args);
        unless ($args{id})
        {
            return;
        }       
    }

    return $args{id};

}

sub get_quick_game_stats
{
    my ($self, $program_id) = @_;
    
    $program_id = sprintf("%d", $program_id);
    unless ($program_id)
    {
        return;
    }

    my $sql = qq[SELECT * FROM
		 (SELECT count(*) AS users_lifetime FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$program_id
		 ) as sub1,
		 (SELECT count(*) AS users_today FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$program_id
		  AND DATE(gl.created) = DATE(CURRENT_TIMESTAMP)
		 ) as sub2,
		 (SELECT count(*) AS users_yesterday FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$program_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY))
		 ) as sub3,
		 (SELECT count(*) AS users_last_week FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$program_id
		  AND DATE(gl.created) > DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 7 DAY))
		 ) as sub4,

		 (SELECT count(*) AS links_lifetime FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$program_id
		 ) as sub5,
		 (SELECT count(*) AS links_today FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$program_id
		  AND DATE(gl.created) = DATE(CURRENT_TIMESTAMP)
		 ) as sub6,
		 (SELECT count(*) AS links_yesterday FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$program_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY))
		 ) as sub7,
		 (SELECT count(*) AS links_last_week FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$program_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 7 DAY))
		 ) as sub8
		];

    my $sth = $self->dbh->prepare($sql);
    my $rows = $self->_Exec($sth);
    return @$rows ? $rows->[0] : "";
}

sub get_game_stats_for_sessions
{
    my ($self, $program_id) = @_;

    $program_id = sprintf("%d", $program_id);
    unless ($program_id)
    {
        warn("No program ID\n");
        return;
    }

    my $steps = $self->list_steps(program_id => $program_id);

    unless (@$steps)
    {
        warn("Program has no steps\n");
        return;
    }

    my %stats; 
    
    # Look through the log
    $stats{headers} = [ 'session_id' ];
    for my $step (@$steps)
    {
	push @{$stats{headers}}, sprintf("step_%d", $step->{id});
	
    }

    my $sessions = {};
    for my $step (@$steps)
    {
    	my $sth = $self->dbh->prepare("SELECT count(*) AS c,session_id FROM game_log WHERE step_id=? AND notes='show_url' GROUP BY session_id ORDER BY session_id");
	unless ($sth->execute($step->{id}))
	{
	    warn("$sth->{Statement}");
	    next;
	}
	
	while (my $log = $sth->fetchrow_hashref)
	{
	    my $session_id = $log->{session_id};
	    unless (exists $sessions->{$session_id})
	    {
		$sessions->{$session_id} = {};
	    }

	    my $step_name = sprintf("step_%d", $step->{id});
	    $sessions->{$session_id}->{$step_name} = $log->{c};
	}
    }

    # Make a structure amenable to JS traversal
    for my $session_id (sort {$b <=> $a} keys %$sessions)
    {
        my $rec = $sessions->{$session_id};
        push @{$stats{sessions}}, { session_id => $session_id,
                                    %$rec
                                  };
    }

    return \%stats;
}

# Sessions
sub save_session
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "program_id" => undef,
                "user_id" => undef,
                @_);

    if ($args{id})
    {
        unless ($self->_Update("sessions", %args))
        {
            return;
        }
    }
    else
    {
        $args{id} = $self->_Insert("sessions", %args);
        unless ($args{id})
        {
            return;
        }       
    }

    return $args{id};

}

sub get_session
{
    my ($self, $id) = @_;
    my $list = $self->list_sessions(id => $id);
    return @$list ? $list->[0] : undef;
}

sub list_sessions
{
    my ($self) = shift;
    my %args = ("id" => undef,
                "user_id" => undef,
                "program_id" => undef
                @_);

    return $self->_List("sessions", "screen_name DESC", %args);
}

sub delete_session
{
    my ($self, $id) = @_;
    return $self->_Delete("sessions", $id);
}

sub get_game_bundle
{
    my ($self, $program_id) = @_;
    $program_id = sprintf("%d", $program_id);
    unless ($program_id)
    {
        warn("No program ID\n");
        return;
    }

    my $program = $self->get_program($program_id);
    unless ($program) 
    {
        warn("Program '$program_id' not found\n");
        return;
    }

    my $steps = $self->list_steps(program_id => $program_id);
    unless (@$steps)
    {
        warn("Program has no steps!\n");
        return;
    }

    my $old_dir = getcwd();

    my $dir = tempdir(CLEANUP => 1);
    chdir $dir;

    my $qrcode = Imager::QRCode->new(
				     size          => 4,
				     margin        => 3,
				     version       => 1,
				     level         => 'M',
				     casesensitive => 1,
				     lightcolor    => Imager::Color->new(255, 255, 255),
				     darkcolor     => Imager::Color->new(0, 0, 0),
				    );

    my $cnt = 0;
    for my $step (@$steps)
    {
        
        my $img = $qrcode->plot(qq[http://qr.taskboy.com/l/?id=$step->{id}]);
        (my $title = $step->{title}) =~ s/\W/_/g;
        
        my $file = sprintf("%03d-%s.png", $step->{id}, $title);
        $img->write(file => $file);

        if ($img->{ERRSTR})
        {
            warn("$img->{ERRSTR}");
        }
        else
        {
            $cnt++;
        }
    }

    if ($cnt != @$steps)
    {
        warn(sprintf("Generated different count of expected QR codes %d/%d\n", $cnt, scalar @$steps));
    }

    (my $name = $program->{name}) =~ s/\W/_/g;
    my $zipfile = sprintf("qr_hunt-%d-%s.zip", $program->{id}, $name);
    my $zipfile_path = "$FindBin::Bin/download/$zipfile";
    my $cmd = qq[zip -q $zipfile_path *.png];
    # warn($cmd);
    system($cmd);
    
    unless (-e $zipfile_path)
    {
        warn("Did not create zipfile '$zipfile_path'\n");
        return;
    }

    my $url = "/download/$zipfile";

    chdir $old_dir;
    return $url;
}

1;
