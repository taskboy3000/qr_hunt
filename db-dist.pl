# Include this for local initialization
# 1. Copy to 'db.pl'
# 2. Replace values as needed
use strict;
use DBI;

sub get_dbh
{
    return DBI->connect("dbi:mysql:qr_hunt", "MYSQL_USER", "MYSQL_PASSWORD") or die;
}

sub get_twitter
{
    # Create an app on twitter, put values here
    return {
	     "consumer_key" => undef,
	     "consumer_secret" => undef,
	     "callback" => "http://qr.taskboy.com/twitter.pl",
	     }
}

1;
