#!/usr/local/bin/perl --
# For a given program, create QR pngs
use strict;
use DBI;
use Imager::QRCode;
require "../db.pl";

my ($program_id) = @ARGV;
unless ($program_id)
{
    warn("No program_id");
    exit;
}

my $dbh = get_dbh();

my $sth = $dbh->prepare("SELECT * FROM steps WHERE program_id=? AND operation = 'show_url' ORDER BY seq");
unless ($sth->execute($program_id))
{
    warn("$sth->{Statement} - " . $sth->errstr);
    exit;
}

unless ($sth->rows)
{
    warn("No such program '$program_id'");
    exit;
}

my $qrcode = Imager::QRCode->new(
				 size          => 4,
				 margin        => 3,
				 version       => 1,
				 level         => 'M',
				 casesensitive => 1,
				 lightcolor    => Imager::Color->new(255, 255, 255),
				 darkcolor     => Imager::Color->new(0, 0, 0),
				);

my $made_initial = 0;

while (my $row = $sth->fetchrow_hashref)
{
    my $game_dir = $row->{program_id};
    unless (-d $game_dir)
    {
	mkdir $game_dir;
    }

    unless ($made_initial)
    {
	# Create initial start QR code
	my $img = $qrcode->plot(qq[http://qr.taskboy.com/resolve_links.pl?program_id=$row->{program_id}]);
	$img->write(file => "$game_dir/start.png");
	if ($img->{ERRSTR})
	{
	    warn("$img->{ERRSTR}");
	}
	$made_initial = 1;
    }
    

    my $url = qq[http://qr.taskboy.com/resolve_links.pl?id=$row->{id}];
    my $img = $qrcode->plot($url);
    $img->write(file => "$game_dir/$row->{seq}.png");
    if ($img->{ERRSTR})
    {
	warn("$img->{ERRSTR}");
    }
}


