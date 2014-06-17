#!/usr/local/bin/perl --
# Resolve incoming links to actual URLs
# - log use
use strict;
use CGI;
use DBI;
use URI;
require "../db.pl";

my $q = CGI->new;
my $step_id = $q->param("id");

my $dbh = get_dbh();

unless ($step_id)
{
    warn("No step_ID\n");
    error($q);
}

my $sth = $dbh->prepare("SELECT s.id AS step_id, s.program_id,s.operation,
                             s.param1,s.seq,s.exclusive_group,s.dependencies,
                             p.name AS program_name, p.user_id, p.start_date,
                             p.end_date,s.error_url
                             FROM steps AS s,programs AS p 
                             WHERE s.program_id=p.id AND s.id=? AND (p.start_date IS NULL OR p.start_date <= CURRENT_TIMESTAMP) 
                             AND (p.end_date IS NULL OR p.end_date >= CURRENT_TIMESTAMP)");

unless ($sth->execute($step_id))
{
    warn("$sth->{Statement} - " . $sth->errstr);
    error($q);
}

unless ($sth->rows)
{
    warn("No steps that match criteria");
    error($q);
}

my $row = $sth->fetchrow_hashref();
my $program_id = $row->{program_id};
my $error_url = $row->{error_url};

warn("Processing step '$step_id' for game '$row->{program_id}'\n");

# This is the only supported operation
unless ($row->{operation} eq 'show_url')
{
    warn("Unsuppored operation '$row->{operation}'\n");
    error($q);
}

my $cookie = "";
my $session_id = $q->cookie("QRHunt");

unless ($session_id)
{
    warn("No session cookie, issuing new one");

    my $ret = new_session("q" => $q,
			  "dbh" => $dbh,
			  "step_id" => $step_id,
			  "program_id" => $program_id,
			 );

    $cookie = $ret->{cookie};
    $session_id = $ret->{session_id};
}

# Is the current session for another game?
$sth = $dbh->prepare("SELECT count(*) FROM sessions WHERE id=? AND program_id=?");
unless ($sth->execute($session_id, $program_id))
{
    die($sth->{Statement});
}

my ($cnt) = $sth->fetchrow_array;
$sth->finish;
unless ($cnt)
{
    warn("Session for an old game");
    my $ret = new_session("q" => $q,
			  "dbh" => $dbh,
			  "step_id" => $step_id,
			  "program_id" => $program_id,
			 );

    $cookie = $ret->{cookie};
    $session_id = $ret->{session_id};
}

# Is this an exclusive choice?
if ($row->{exclusive_group})
{
    # yes, what are the other choices?
    my $exclusive_group_sth = $dbh->prepare(qq[SELECT id FROM steps WHERE exclusive_group=? AND id != ?]);
    
    unless ($exclusive_group_sth->execute($row->{exclusive_group}, $step_id))
    {
	warn("$exclusive_group_sth->{Statement}");
	error($q);
    }
    
    my @ids = (-1);
    while (my $hr = $exclusive_group_sth->fetchrow_hashref)
    {
	push @ids, $hr->{id};
    }
    
    my $sql = sprintf("SELECT count(*) FROM game_log WHERE session_id=? AND step_id IN (%s)", join(",", @ids));
    my $log_sth = $dbh->prepare($sql);
    
    unless ($log_sth->execute($session_id))
    {
	warn("$log_sth->{Statement}");
	error($q);
    }
    
    my ($cnt) = $log_sth->fetchrow_array();
    $log_sth->finish;
    
    if ($cnt)
    {
	warn("Choice has been made");
	if ($error_url)
	{
	    print $q->header(-cookie => $cookie, -location => $error_url);
	    exit;
	}
	else
	{
	    error($q, code => 418, message => "You have already choosen from your options");
	}
    }
}

if ($row->{dependencies})
{
    # Which steps are required?
    my @steps = split /,/, $row->{dependencies};
    
    my $sql = sprintf("SELECT count(*) AS c, step_id FROM game_log WHERE session_id=? AND step_id IN (%s) GROUP BY step_id", join(",", @steps));
    my $dep_sth = $dbh->prepare($sql);
    unless ($dep_sth->execute($session_id))
    {
	warn("$dep_sth->{Statement}");
	error($q);
    }
    
    unless ($dep_sth->rows)
    {
	warn("Missing all dependencies");
	if ($error_url)
	{
	    print $q->header(-cookie => $cookie, -location => $error_url);
	    exit;
	}
	else
	{
	    error($q, code=>418, message=>"Missing a dependency");
	}
    }
    
    my $completed = 0;
    while (my $hr = $dep_sth->fetchrow_hashref)
    {
	next unless $hr->{step_id};
	if ($hr->{c} == 0)
	{
	    warn("Missing step $hr->{step_id}");
	}
	else
	{
	    $completed += 1;
	}
    }
    
    if ($completed != scalar @steps)
    {
	if ($error_url)
	{
	    print $q->header(-cookie => $cookie, -location => $error_url);
	    exit;
	}
	else
	{
	    error($q, code=>418, message=>"Missing a dependency");
	}
    }
}

# Log this 
my $sql = "INSERT INTO game_log (created, step_id, session_id, notes) VALUES (CURRENT_TIMESTAMP, ?, ?, ?)";
$sth = $dbh->prepare($sql);
unless ($sth->execute($step_id, $session_id, "show_url"))
{
    warn("$sth->{Statement} - " . $sth->errstr);
}

warn("Request granted\n");
 
# redirect
my $U = URI->new($row->{param1});
$U->query_form({session_id=>$session_id,step_id=>$step_id});
print $q->header(-cookie => $cookie, -location => $U->as_string);
exit;

#------------
sub error
{
    my ($q) = shift;
    my %opts = ("code" => 413,
		"message" => "No such link", 
		@_);

    print $q->header(-status => "$opts{code} $opts{message}");
    print $q->h1($opts{message});
    exit;
}

sub new_session
{
    my %args = ("q" => "",
		"dbh" => "",
		"program_id" => "",
		"step_id" => "",
		@_);

    my $sth = $args{dbh}->prepare("INSERT INTO sessions (program_id,created) VALUES (?,CURRENT_TIMESTAMP)");
    unless ($sth->execute($args{program_id}))
    {
	warn("$sth->{Statement} - " . $sth->errstr);
	error($q);
    }
    
    my ($session_id) = $args{dbh}->{mysql_insertid};
    
    # Put this in a cookie
    my $cookie = $args{q}->cookie(-name=>"QRHunt",
			    -value=>$session_id,
			    -path => "/");
    
    # For geolocation
    # http://www.w3schools.com/html/html5_geolocation.asp
    
    # Log this 
    my $sql = "INSERT INTO game_log (created, step_id, session_id, notes) VALUES (CURRENT_TIMESTAMP, ?, ?, ?)";
    $sth = $args{dbh}->prepare($sql);
    unless ($sth->execute($args{step_id}, $session_id, "started"))
    {
	warn("$sth->{Statement} - " . $sth->errstr);
    }
    
    return { "session_id" => $session_id, "cookie" => $cookie };
}
