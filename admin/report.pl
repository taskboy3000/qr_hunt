#!/usr/local/bin/perl --
use strict;
use CGI;
use DBI;
require "../db.pl";
my $dbh = get_dbh(); 

my $sth_read = $dbh->prepare("SELECT * FROM programs ORDER BY id");

unless ($sth_read->execute())
{
   warn("$sth_read->{Statement}");
   exit;
}

my $q = CGI->new;
print $q->header, $q->start_html(-title => "Game progress report");

while (my $hr = $sth_read->fetchrow_hashref)
{
    
    my $sth = $dbh->prepare("SELECT * FROM steps WHERE program_id=? ORDER BY seq");
    unless ($sth->execute($hr->{id}))
    {
	warn("$sth->{Statement}");
	next;
    }
    
    print "<h2>Game: $hr->{name}</h2>";

    next unless $sth->rows;
    my $steps = $sth->fetchall_arrayref({});
    
    # Look through the log
    
    print "<table border=1><tr><th>Session ID</th>";
    for my $step (@$steps)
    {
	printf("<th>Step %d</th>", $step->{id});
    }
    print "</tr>";
    
    # "[session_id]" => { "step_X" => "count" }},
    my %stats = ();
    for my $step (@$steps)
    {
    	$sth = $dbh->prepare("SELECT count(*) AS c,session_id FROM game_log WHERE step_id=? AND notes='show_url' GROUP BY session_id ORDER BY session_id");
	unless ($sth->execute($step->{id}))
	{
	    warn("$sth->{Statement}");
	    next;
	}
	
	while (my $log = $sth->fetchrow_hashref)
	{
	    next unless ($log->{session_id});

	    unless ($stats{$log->{session_id}})
	    {
		$stats{$log->{session_id}} = {};
	    }
	    
	    $stats{$log->{session_id}}->{$step->{id}} = $log->{c};
	}
    }

    for my $sid (sort {$b <=> $a } keys %stats)
    {
	print "<tr>";
	print "<td>$sid</td>";
	for my $step (@$steps)
	{
	    printf "<td>%d</td>", $stats{$sid}->{$step->{id}};
	}
	print "</tr>";

    }
    print "</table>\n";
}  
  	
print $q->end_html;
