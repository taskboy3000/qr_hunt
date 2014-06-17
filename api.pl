#!/usr/local/bin/perl --
# The JSON controller
use strict;
use DBI;
use CGI;
use JSON;
use Net::Twitter;
use Crypt::CBC;
use MIME::Base64;
use Time::HiRes;
use Data::Dumper;
use File::Temp ('tempdir');
use FindBin;
use Imager::QRCode;
require "db.pl";

our $Conf = get_twitter();

our $q = CGI->new;
our $T = Net::Twitter->new(traits => ['API::RESTv1_1'],
			  consumer_key => $Conf->{consumer_key},
			  consumer_secret => $Conf->{consumer_secret},
			 );

our $dbh = get_dbh();

my ($method) = $q->param("action");
my $data;
eval
{
    no strict 'refs';
    warn("Servicing method '$method'\n");
    &$method($q, $dbh, $T);
};

if ($@)
{
    respond({ error => $@});
}

#-----
# subs
#-----
# DON'T CONVERT
sub respond
{
    my ($hash) = @_;
    print $q->header(-type=>"application/json");
    print encode_json($hash);
    exit;
}

# CONVERTED as get_step, get_exclusive_group
sub _get_step
{
    my ($q, $dbh, $T, $step_id) = @_;   
    return unless $step_id;

    my $sth = $dbh->prepare("SELECT * FROM steps WHERE id=?");
    unless ($sth->execute($step_id))
    {
	warn($sth->{Statement});
	die("Cannot find step\n");
    }
    
    unless ($sth->rows)
    {
	warn("No step found with that ID");
	die("No such step\n");
    }

    my $step = $sth->fetchrow_hashref();
    $sth->finish;

    if ($step->{exclusive_group})
    {
	($step->{exclusive_group_name}) = $dbh->selectrow_array("SELECT name FROM exclusive_groups WHERE id=" . $dbh->quote($step->{exclusive_group}));
    }

    if ($step->{dependencies})
    {
        # How do enrich these?
    }

    return $step;
}

# INTERNAL, SHOULD NOT BE NEEDED 
sub _make_id
{
    my $id =Time::HiRes::time();
    $id =~ s/\./_/;
    return $id;
}

# CONVERTED as get_user, without cookie stuff
sub _get_user
{ 
    my ($q, $dbh, $T) = @_;
    my $C = Crypt::CBC->new(-key => "fldksjf893120923123dflksdf",
			    -cipher => "Blowfish"
			   );

    my $ses_str = $C->decrypt(decode_base64($q->cookie("QRHuntWebSession")));
    my ($twitter_id, $created) = split(/:/, $ses_str, 2);
    unless ($created)
    {
	warn("No session creation date");
	die("Expired session\n");
    }

    if (time() - $created > (60*60*4))
    {
	warn("No session creation date");
	die("Expired session\n");
    }

    my $sth = $dbh->prepare("SELECT * FROM users WHERE twitter_id=?");

    if (!$sth->execute($twitter_id) || !$sth->rows)
    {
	warn("$sth->{Statement}");
	die("No such user\n");
    }

    my $row = $sth->fetchrow_hashref();
    $sth->finish;
    return $row;
}

#--- API ----
# CONVERTED as get_user, but would need to extract ID from cookie
sub get_user
{
    my ($q, $dbh, $T) = @_;
    print $q->header(-type=> "application/json");
    print encode_json({user => _get_user(@_)});
}

# DON'T CONVERT
sub get_auth_url
{
    my ($q, $dbh, $T) = @_;
    my $url = $T->get_authorization_url("callback", "http://qr.taskboy.com/twitter.pl");
    my $tokens = { url => $url->as_string,
		   request_token => $T->request_token,
		   request_secret => $T->request_token_secret,
		 };

    # Save the tokens to cookies (will this work?)
    my $req_tok = $q->cookie(-name => "QRHunt_Twitter_Request_Token",
			  -value => $T->request_token,
			  -path => "/",);
    my $req_sec = $q->cookie(-name => "QRHunt_Twitter_Request_Token_Secret",
			  -value => $T->request_token_secret,
			  -path => "/",);
    print $q->header(-cookie => [ $req_tok, $req_sec ], -type=>"application/json");
    print encode_json($tokens);
}

# CONVERTED as list_games (no windowing available)
sub list_games
{
    my ($q, $dbh, $T) = @_;
    my $user_id = $q->param("user_id");
    my $limit = $q->param("limit") || 25;
    my $page = $q->param("page") || 0;

    unless ($user_id) 
    {
	die("No user given");
    }

    my $sth = $dbh->prepare(sprintf("SELECT id,name,DATE(created) as created,DATE(updated) as updated FROM programs WHERE user_id=? LIMIT %d,%d", $limit*$page, $limit));
    unless ($sth->execute($user_id))
    {
	warn($sth->{Statement});
	die("Cannot find game\n");
    }
    print $q->header(-type=>"application/json");
    print encode_json({ games => $sth->fetchall_arrayref({})});
}

# CONVERTED but requires get_program, get_steps
sub get_game
{
    my ($q, $dbh, $T) = @_;   
    my $game_id = $q->param("id");
    unless ($game_id)
    {
	die("No game ID\n");
    }

    my $sth = $dbh->prepare("SELECT * FROM programs WHERE id=?");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot find game\n");
    }
    
    unless ($sth->rows)
    {
	warn("No game found with that ID");
	die("No such game\n");
    }

    my $game = $sth->fetchrow_hashref();
    $sth->finish;

    $sth = $dbh->prepare("select * FROM steps WHERE program_id=? ORDER BY seq");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot find steps\n");
    }
    
    my $steps = [];
    if ($sth->rows)
    {
	while (my $hr = $sth->fetchrow_hashref)
	{
	    push @$steps, _get_step(@_, $hr->{id});;
	}
    }

    print $q->header(-type=>"application/json");
    print encode_json({ game => $game, steps => $steps});
}

# CONVERTER as get_step(id => ?)
sub get_step
{
    my ($q, $dbh, $T) = @_;   
    
    my $step_id = $q->param("id");
    unless ($step_id)
    {
	die("No step ID\n");
    }

    my $step = _get_step(@_, $step_id);

    print $q->header(-type=>"application/json");
    print encode_json({ step => $step });
}

# CONVERTED as save_program
sub save_game_meta
{
    my ($q, $dbh, $T) = @_;   

    my $user = _get_user(@_);
    unless ($user)
    {
	die("No session\n");	
    }
    
    my $program_id = $q->param("program_id");
    my $name = $q->param("name");
    my $start_date = $q->param("start_date") || undef;
    my $end_date = $q->param("end_date") || undef;
    
    if ($program_id)
    {
	my $sth = $dbh->prepare("UPDATE programs SET name=?,start_date=?,end_date=? WHERE id=?");
	unless ($sth->execute($name,$start_date,$end_date,$program_id))
	{
	    warn("$sth->{Statement}");
	    die("Can't update game\n");
	}
    }
    else
    {
	my $sth = $dbh->prepare("INSERT INTO programs (name,user_id,start_date,end_date,created) VALUE (?,?,?,?,CURRENT_TIMESTAMP)");
	unless ($sth->execute($name,$user->{id},$start_date,$end_date))
	{
	    warn("$sth->{Statement}");
	    die("Can't create game\n");
	}
	$program_id = $dbh->{mysql_insertid};
    }

    print $q->header(-type=>"application/json");
    print encode_json({ id => $program_id });
}

# CONVERTED - BUT requires several Method calls 
sub save_step
{
    my ($q, $dbh, $T) = @_;   

    my $user = _get_user(@_);
    unless ($user)
    {
	die("No session\n");	
    }

    my $param1 = $q->param("url");
    my $seq = sprintf("%d", $q->param("seq"));
    my $step_id = $q->param("step_id");
    my $title = $q->param("title");
    my $excl_group = $q->param("exclusive_group");
    my $program_id = $q->param("program_id");
    my @dependencies = $q->param("dependencies[]");
    my $error_url = $q->param("error_url");

    my $deps = undef;
    if (@dependencies)
    {
	$deps = join(",", @dependencies);
    }

    if ($excl_group eq "*create*")
    {
	my $new_group = $q->param("new_exclusive_group");
	if ($new_group)
	{
	    # Create new group
	    $excl_group = _make_id();
	    my $sth = $dbh->prepare("INSERT INTO exclusive_groups (id, name, program_id) VALUES (?,?,?)");
	    unless ($sth->execute($excl_group, $new_group, $program_id))
	    {
		die("$sth->{Statement} - " . $sth->error);
	    }
	}
	else
	{
	    warn("No group name given\n");
	    $excl_group = undef();
	}
	
    }

    if ($step_id)
    {
	my $sth = $dbh->prepare("UPDATE steps SET param1=?,seq=?,title=?,exclusive_group=?,dependencies=?,error_url=? WHERE id=?");
	unless ($sth->execute($param1,$seq,$title,$excl_group,$deps,$error_url,$step_id))
	{
	    warn($sth->{Statement});
	    die("Cannot update step\n");
	}
    }
    else
    {
	my $sth = $dbh->prepare("INSERT INTO steps 
         (param1,seq,title,program_id,exclusive_group,dependencies,error_url,created) 
         VALUES (?,?,?,?,?,?,?,CURRENT_TIMESTAMP)");
	unless ($sth->execute($param1,$seq,$title,$program_id,$excl_group,$deps,$error_url))
	{
	    warn($sth->{Statement});
	    die("Cannot create step\n");
	}

	$step_id = $dbh->{mysql_insertid};
    }

    print $q->header(-type=>"application/json");
    print encode_json({ id => $step_id });
}

# CONVERTED as list_exclusive_group(program_id => ?)
sub get_exclusive_groups_for_game
{
    my ($q, $dbh, $T) = @_;   
    my $game_id = $q->param("id");
    unless ($game_id)
    {
	die("No game ID\n");
    }

    my $sth = $dbh->prepare("SELECT * FROM exclusive_groups WHERE program_id=?");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot find step\n");
    }

    print $q->header(-type=>"application/json");
    print encode_json({ groups => $sth->fetchall_arrayref({}) });
}

# CONVERTED as get_game_bundle
sub download
{
    my ($q, $dbh, $T) = @_;  
 
    my $user = _get_user(@_);
    my $game_id = $q->param("program_id");

    unless ($game_id)
    {
	die("No game ID\n");
    }

    my $url = "/download/";
    my $sth = $dbh->prepare("SELECT * FROM programs WHERE user_id=? AND id=?");
    unless ($sth->execute($user->{id}, $game_id))
    {
	warn("$sth->{Statement}");
	die("Error connecting to DB\n");
    }
    
    unless ($sth->rows)
    {
	die("No such game for the current user\n");
    }

    my $game_meta = $sth->fetchrow_hashref();
    $sth->finish;

    $sth = $dbh->prepare("select * FROM steps WHERE program_id=? ORDER BY seq");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot find steps\n");
    }
    
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

    if ($sth->rows)
    {
	my $cnt = 0;
	while (my $hr = $sth->fetchrow_hashref)
	{
	    my $step = _get_step(@_, $hr->{id});

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

	unless ($cnt == $sth->rows)
	{
	    warn(sprintf("Generated fewer than expected QR codes %d/%d\n", $cnt, $sth->rows));
	}
	
	(my $name = $game_meta->{name}) =~ s/\W/_/g;
	my $zipfile = sprintf("qr_hunt-%d-%s.zip", $game_meta->{id}, $name);
	my $cmd = qq[zip $FindBin::Bin/download/$zipfile *.png];
	warn($cmd);
	system($cmd);
	$url .= $zipfile;
    }

    print $q->header(-type=>"application/json");
    print encode_json({ url => $url });
}

# CONVERTED as delete_program
sub delete_game
{
    my ($q, $dbh, $T) = @_;  
 
    my $user = _get_user(@_);
    my $game_id = $q->param("program_id");

    unless ($game_id)
    {
	die("No game ID\n");
    }

    my $sth = $dbh->prepare("DELETE FROM steps WHERE program_id=?");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot delete steps\n");
    }
    
    $sth = $dbh->prepare("DELETE FROM programs WHERE id=?");
    unless ($sth->execute($game_id))
    {
	warn($sth->{Statement});
	die("Cannot delete game\n");
    }

    print $q->header(-type=>"application/json");
    print encode_json({ success => 1 });
}

# CONVERTED
sub delete_step
{
    my ($q, $dbh, $T) = @_;  
 
    my $user = _get_user(@_);
    my $step_id = $q->param("id");

    unless ($step_id)
    {
	die("No step ID\n");
    }

    my $sth = $dbh->prepare("DELETE FROM steps WHERE id=?");
    unless ($sth->execute($step_id))
    {
	warn($sth->{Statement});
	die("Cannot delete step\n");
    }

    print $q->header(-type=>"application/json");
    print encode_json({ success => 1 });
}

# CONVERTED
sub get_quick_game_stats
{
    my ($q, $dbh, $T) = @_;  
 
    my $user = _get_user(@_);

    my $game_id = sprintf("%d", $q->param("id"));
    unless ($game_id)
    {
	die("No game id\n");
    }

    # TODO: Does this user own this game?
    # Get total unique session (started) counts for: today, yesterday, last_week, lifetime
    # Get total links served for: today, yesterday, last_week, lifetime
    my $sql = qq[SELECT * FROM
		 (SELECT count(*) AS users_lifetime FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$game_id
		 ) as sub1,
		 (SELECT count(*) AS users_today FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$game_id
		  AND DATE(gl.created) = DATE(CURRENT_TIMESTAMP)
		 ) as sub2,
		 (SELECT count(*) AS users_yesterday FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$game_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY))
		 ) as sub3,
		 (SELECT count(*) AS users_last_week FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='started'
		  AND p.id=$game_id
		  AND DATE(gl.created) > DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 7 DAY))
		 ) as sub4,

		 (SELECT count(*) AS links_lifetime FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$game_id
		 ) as sub5,
		 (SELECT count(*) AS links_today FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$game_id
		  AND DATE(gl.created) = DATE(CURRENT_TIMESTAMP)
		 ) as sub6,
		 (SELECT count(*) AS links_yesterday FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$game_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY))
		 ) as sub7,
		 (SELECT count(*) AS links_last_week FROM game_log AS gl,steps AS s,programs AS p
		  WHERE gl.step_id=s.id AND s.program_id=p.id AND gl.notes='show_url'
		  AND p.id=$game_id
		  AND DATE(gl.created) = DATE(DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 7 DAY))
		 ) as sub8
		];
    my $sth = $dbh->prepare($sql);
    unless ($sth->execute())
    {
	warn("$sth->{Statement}");
	die("Could not generate stats\n");
    }

    my $stats = $sth->fetchrow_hashref;
    $sth->finish;

    print $q->header(-type=>"application/json");
    print encode_json({ stats => $stats });
}

# CONVERTED
sub get_game_stats_for_sessions
{
    my ($q, $dbh, $T) = @_;  
 
    my $user = _get_user(@_);

    my $game_id = sprintf("%d", $q->param("id"));
    unless ($game_id)
    {
	die("No game id\n");
    }

    my $sth = $dbh->prepare("SELECT * FROM steps WHERE program_id=? ORDER BY seq");
    unless ($sth->execute($game_id))
    {
	warn("$sth->{Statement}");
	next;
    }
    
    unless ($sth->rows)
    {
	warn("Game $game_id has no steps\n");
	die("No steps for this game\n");
    }

    my %stats; 
    my $steps = $sth->fetchall_arrayref({});
    
    # Look through the log
    $stats{headers} = [ 'session_id' ];
    for my $step (@$steps)
    {
	push @{$stats{headers}}, sprintf("step_%d", $step->{id});
	
    }

    my $sessions = {};
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

    print $q->header(-type=>"application/json");
    print encode_json({ stats => \%stats });
}
