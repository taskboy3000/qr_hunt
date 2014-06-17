#!/usr/local/bin/perl --
# Exercise the REST service
use strict;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use Data::Dumper;
use HTTP::Request::Common;

my $M = Test::WWW::Mechanize->new();

my $base_url = "http://qr.taskboy.com/api/1.0";

print ">>Test Login\n";

print ">>Test Users\n";
my $url = sprintf("%s/user", $base_url);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get All Users?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

$url = sprintf("%s/user/%d", $base_url, 2);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get user 2?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

my %user_args = ("screen_name" => "Tess Tickle");
$url = sprintf("%s/user", $base_url);
my $res = $M->put($url, content => encode_json(\%user_args));
my $data = $res->content;

ok($data, "Create user?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
if ($data->{error})
{
    warn($data->{error});
}
else
{
    $user_args{id} = $data->{id};
}

#---
print ">>Test Programs\n";
my $url = sprintf("%s/program", $base_url);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get All Programs?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

$url = sprintf("%s/program/%d", $base_url, 1);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get program 1?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

my %program_args = ("name" => "Testing", "user_id" => $user_args{id});
$url = sprintf("%s/program", $base_url);
my $res = $M->put($url, content => encode_json(\%program_args));
my $data = $res->content;

ok($data, "Create program?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
if ($data->{error})
{
    warn($data->{error});
}
else
{
    $program_args{id} = $data->{id};
}


#---
print ">>Test Steps\n";
my $url = sprintf("%s/step", $base_url);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get All Steps?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

$url = sprintf("%s/step/%d", $base_url, 1);
my $res = $M->get($url);
my $data = $res->content;

ok($data, "Get step 1?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
# print Dumper($data);

my %step_args = ("title" => "Testing", "program_id" => $program_args{id});
$url = sprintf("%s/step", $base_url);
my $res = $M->put($url, content => encode_json(\%step_args));
my $data = $res->content;

ok($data, "Create step?");
eval { $data = decode_json($data); };
ok(ref $data, "Decoded response?");
if ($data->{error})
{
    warn($data->{error});
}
else
{
    $step_args{id} = $data->{id};
}

#-----
print "Clean up\n";
if ($program_args{id})
{
    $url = sprintf("%s/step/%s", $base_url, $step_args{id});
    my $req = HTTP::Request::Common::DELETE($url);
    my $res = $M->request($req);
    my $data = $res->content;
    
    ok($data, "Delete step $step_args{id}?");
    eval { $data = decode_json($data); };
    ok(ref $data, "Decoded response?");
}

if ($program_args{id})
{
    $url = sprintf("%s/program/%s", $base_url, $program_args{id});
    my $req = HTTP::Request::Common::DELETE($url);
    my $res = $M->request($req);
    my $data = $res->content;
    
    ok($data, "Delete program $program_args{id}?");
    eval { $data = decode_json($data); };
    ok(ref $data, "Decoded response?");
}

if ($user_args{id})
{
    $url = sprintf("%s/user/%s", $base_url, $user_args{id});
    my $req = HTTP::Request::Common::DELETE($url);
    my $res = $M->request($req);
    my $data = $res->content;
    
    ok($data, "Delete user $user_args{id}?");
    eval { $data = decode_json($data); };
    ok(ref $data, "Decoded response?");
}



done_testing();
