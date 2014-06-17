#!/usr/bin/perl --
use strict;
use Test::More;
use FindBin;
use lib ("$FindBin::Bin/../api");
use QRService;

my $Q = QRService->new;
ok((ref $Q) eq "QRService", "Create QRService?");

# Users 
print "User objects\n";
my %user_args = (
                 "email" => "noone\@dev.null.com",
                 "screen_name" => "testing",
                 "is_admin" => 1,
                @_);

$user_args{id} = $Q->save_user(%user_args);
ok($user_args{id}, "Create User?");
$user_args{screen_name} = "Old Pukey";
ok($Q->save_user(%user_args), "Update User?");
 
print "Testing program CRUD\n";
my %program_args = (
                    name => "TEST - New Game",
                    user_id => $user_args{id},
                    start_date => "2013-01-01",
                   );

$program_args{id} = $Q->save_program(%program_args);
ok($program_args{id}, "Create a new program?");

my $old_name = $program_args{name};
$program_args{name} = "TEST - Changed name";
ok($Q->save_program(%program_args), "Update program?");

my $info = $Q->get_program($program_args{id});
ok($info->{name} ne $old_name, "Name changed?");

print "Testing steps CRUD\n";
my %steps_args = (
                  "program_id" => $program_args{id},
                  "operation" => "show_url",
                  "param1" => "http://www.foo.com/",
                  "seq" => 1,
                  "title" => "Step - 1",
                  "error_url" => "http://www.foo.com/error.html",
                 );

$steps_args{id} = $Q->save_step(%steps_args);
ok($steps_args{id}, "Create a step?");

# Exclusive Groups
my %excl_args = ("program_id" => $program_args{id},
                 "name" => "My Exclusive Group",
                );

$excl_args{id} = $Q->save_exclusive_group(%excl_args);
ok($excl_args{id}, "Create Exclusive Group?");

$steps_args{"exclusive_group"} = $excl_args{id};
ok($Q->save_step(%steps_args), "Update Steps?");


# Sessions
my %session_args = ("user_id" => $user_args{id},
                    "program_id" => $program_args{id},
                   );
ok($session_args{id} = $Q->save_session(%session_args), "Create Session?");

# Game Log
print "Game Log CRUD\n";
my %log_args = ("step_id" => $steps_args{id},
                "session_id" => $session_args{id},
                "notes" => "Testing",
               );
ok($log_args{id} = $Q->save_log(%log_args), "Save game log?");

ok($Q->get_quick_game_stats(1), "Quick stats?");
ok($Q->get_game_stats_for_sessions(1), "Session stats?");

print "Testing download of program $program_args{id}\n";
my $url;
ok($url = $Q->get_game_bundle($program_args{id}), "Got a game bundle?");
printf("--> %s [%0.2f KB]\n", $url, (-s "$FindBin::Bin/../api/$url")/(1024)); # yes, ".$url" is pretty cheesy

# Clean up
print "Cleaning up objects\n";
ok($Q->delete_log($log_args{id}), "Delete game log?");
ok($Q->delete_session($session_args{id}), "Delete session?");
ok($Q->delete_user($user_args{id}), "Delete User?");
ok($Q->delete_program($program_args{id}), "Delete program?");



# THIS SHOULD BE LAST
done_testing();
 
