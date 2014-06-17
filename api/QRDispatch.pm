# This is a JSON service entirely
#
package QRDispatch;

use strict;
use base 'CGI::Application::Dispatch';

sub dispatch_args
{
    my %params = ("debug" => 1,
                  table =>  [ 
                              "/auth/url[get]" => { app => "QRController", rm => "get_auth_url"},

                              "/user[get]" => { app => "QRController", rm => "list_users" },
                              "/user/:id[get]" => { app => "QRController", rm => "get_user" }, # fetch
                              "/user[post]" => { app => "QRController", rm => "save_user" }, # update
                              "/user[put]" => { app => "QRController", rm => "save_user" }, # create
                              "/user/:id[delete]" => { app => "QRController", rm => "delete_user" }, # delete
                                                           
                              "/program[get]" => { app => "QRController", rm => "list_programs" },
                              "/program/:id[get]" => { app => "QRController", rm => "get_program" }, # fetch
                              "/program[post]" => { app => "QRController", rm => "save_program" }, # update
                              "/program[put]" => { app => "QRController", rm => "save_program" }, # create
                              "/program/:id[delete]" => { app => "QRController", rm => "delete_program" }, # delete

                              "/step[get]" => { app => "QRController", rm => "list_steps" },
                              "/step/:id[get]" => { app => "QRController", rm => "get_step" }, # fetch
                              "/step[post]" => { app => "QRController", rm => "save_step" }, # update
                              "/step[put]" => { app => "QRController", rm => "save_step" }, # create
                              "/step/:id[delete]" => { app => "QRController", rm => "delete_step" }, # delete
                                                          
                            ],
                 );

    return \%params;
}
1;
