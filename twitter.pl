#!/usr/local/bin/perl --
# The only thing this does is validate and record the callback from twitter;
use strict;
use Net::Twitter;
use DBI;
use CGI;
use MIME::Base64;
use Crypt::CBC;
use Mail::Sender;
use Data::Dumper;
require "db.pl";
our $Conf = get_twitter();

my $q = CGI->new;
my $T = Net::Twitter->new(traits => ['API::RESTv1_1'],
			  consumer_key => $Conf->{consumer_key},
			  consumer_secret => $Conf->{consumer_secret},
			 );

my $dbh = DBI->connect("dbi:mysql:qr_hunt:localhost", "editor", "editor") or die("Connect");

if ($q->param("oauth_token"))
{
    # get auth tokens from cookies
    my $request_token = $q->cookie("QRHunt_Twitter_Request_Token");
    my $request_token_secret = $q->cookie("QRHunt_Twitter_Request_Token_Secret");
    warn("RT: '$request_token'   Secret: '$request_token_secret'\n");
    warn("Verifier: " . $q->param("oauth_verifier") . "\n");

    $T->request_token($request_token);
    $T->request_token_secret($request_token_secret);
    
    my ($access_token, $access_secret, $user_id, $screen_name);
    
    eval
    {
        ($access_token, $access_secret, $user_id, $screen_name) = $T->request_access_token("verifier", $q->param("oauth_verifier"));
    };

    if ($@)
    {
        warn("Twitter rejected this session\n");
        warn("ERROR: $@\n");

        print $q->header(-location => "http://qr.taskboy.com/");
        exit;
    }
    
    # New user?
    my ($cnt) = $dbh->selectrow_array("SELECT count(*) FROM users WHERE twitter_id=" . $dbh->quote($user_id));
    if ($cnt)
    {
	my $sql = q[UPDATE users SET screen_name=?,access_token=?,access_secret=? WHERE twitter_id=?];
	my $sth = $dbh->prepare($sql);
	unless ($sth->execute($screen_name, $access_token, $access_secret, $user_id))
	{
	    warn("$sth->{Statement}");
	    exit 1;
	}
    }
    else
    {
	my $sql = q[INSERT INTO users (created,twitter_id,screen_name,access_token,access_secret) VALUES (CURRENT_TIMESTAMP,?,?,?,?)];
	my $sth = $dbh->prepare($sql);
	unless ($sth->execute($user_id, $screen_name, $access_token, $access_secret))
	{
	    warn("$sth->{Statement}");
	    exit 1;
	}

        notify(
               message => "new user - \@$screen_name"
              );
    }
    
    my $C = Crypt::CBC->new(-key => "fldksjf893120923123dflksdf",
			    -cipher => "Blowfish"
			   );

    my $session = $C->encrypt(sprintf("%s:%s", $user_id, time()));

    my $cookie = $q->cookie(-name => "QRHuntWebSession",
			    -value => encode_base64($session),
			    -path => "/");

    print $q->redirect(-uri=> "/games.html", -cookie => $cookie);
    exit;
}

sub notify
{
    my (%args) = (
                  to => 'jjohn@taskboy.com',
                  from => 'joseph_c_johnston@yahoo.com',
                  subject => 'New QR Hunt User',
                  smtp=>"plus.smtp.mail.yahoo.com",
                  port=>"25",
                  auth=>"PLAIN",
                  authid=>'joseph_c_johnston',
                  authpwd=>'green*2013',
                  message => "",
                  @_);

    my $body = delete $args{message};
    my $M = Mail::Sender->new(\%args);

    eval
    {
        my $rc = $M->MailMsg({msg => $body});
    };
    if ($@)
    {
        warn($@);
    }
}
