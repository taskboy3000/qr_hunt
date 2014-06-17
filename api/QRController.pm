package QRController;
use strict;
use QRService;
use JSON;
use base 'CGI::Application';
use Data::Dumper;
use Net::Twitter;
use FindBin;
require "$FindBin::Bin/../db.pl";

our $Conf = get_twitter();

our $S = QRService->new;

sub setup 
{
   my ($self) = shift;
   $self->start_mode("list_users");
   $self->mode_param("rm");
   my %modes = (
                "get_auth_url" => "get_auth_url",

                "get_user"    => "get_user",
                "delete_user" => "delete_user",
                "list_users"  => "list_users",
                "save_user"   => "save_user",

                "get_program"    => "get_program",
                "delete_program" => "delete_program",
                "list_programs"  => "list_programs",
                "save_program"   => "save_program",

                "get_step"    => "get_step",
                "delete_step" => "delete_step",
                "list_steps"  => "list_steps",
                "save_step"   => "save_step",

               );
   $self->run_modes(%modes);
}

sub reply
{
    my ($self, $data) = @_;
    $self->header_props(-"Content-Type" => "application/json");
    my $str = encode_json($data);
    return $str;
}

sub get_auth_url
{
    #my ($q, $dbh, $T) = @_;
    my ($self) = @_;
    my $q = $self->query;

    my $T = Net::Twitter->new(traits => ['API::RESTv1_1'],
                              consumer_key => $Conf->{consumer_key},
                              consumer_secret => $Conf->{consumer_secret},
                             );
   
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
    # Stash cookie
    $self->header_props(-cookie => [ $req_tok, $req_sec ],
                        -type => "application/json",
                       );

    return $self->reply($tokens);
}

#-------------
# CRUD: Users
#-------------
sub get_user
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        unless ($ret{user} = $S->get_user($id))
        {
            $ret{error} = "User '$id' not found";          
        }
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

sub list_users 
{
    my ($self) = @_;
    return $self->reply($S->list_users());
}

sub save_user
{
    my ($self) = @_;
    my $q = $self->query;

    # was this post?
    my $data = $q->param("POSTDATA") || $q->param("PUTDATA");
    
    unless ($data)
    {
        for my $k ($q->param("keywords"))
        {
            $data .= $k;
        }
    }

    eval 
    {
        $data = decode_json($data);
    };

    if ($@ || !ref $data)
    {
        return $self->reply({error => "Malformed request"});
    }
    return $self->reply({id => $S->save_user(%$data)});
}

sub delete_user
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        $ret{success} = $S->delete_user($id);
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

#-------------
# CRUD: Programs
#-------------
sub get_program
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        unless ($ret{user} = $S->get_program($id))
        {
            $ret{error} = "Program '$id' not found";          
        }
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

sub list_programs 
{
    my ($self) = @_;
    return $self->reply($S->list_programs());
}

sub save_program
{
    my ($self) = @_;
    my $q = $self->query;

    # was this post?
    my $data = $q->param("POSTDATA") || $q->param("PUTDATA");
    
    unless ($data)
    {
        for my $k ($q->param("keywords"))
        {
            $data .= $k;
        }
    }

    eval 
    {
        $data = decode_json($data);
    };

    if ($@ || !ref $data)
    {
        return $self->reply({error => "Malformed request"});
    }
    return $self->reply({id => $S->save_program(%$data)});
}

sub delete_program
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        $ret{success} = $S->delete_program($id);
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

#-------------
# CRUD: Steps
#-------------
sub get_step
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        unless ($ret{user} = $S->get_step($id))
        {
            $ret{error} = "Step '$id' not found";          
        }
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

sub list_steps 
{
    my ($self) = @_;
    return $self->reply($S->list_steps());
}

sub save_step
{
    my ($self) = @_;
    my $q = $self->query;

    # was this post?
    my $data = $q->param("POSTDATA") || $q->param("PUTDATA");
    
    unless ($data)
    {
        for my $k ($q->param("keywords"))
        {
            $data .= $k;
        }
    }

    eval 
    {
        $data = decode_json($data);
    };

    if ($@ || !ref $data)
    {
        return $self->reply({error => "Malformed request"});
    }
    return $self->reply({id => $S->save_step(%$data)});
}

sub delete_step
{
    my ($self) = @_;
    my ($id) = $self->param("id");
    my %ret;

    if ($id)
    {
        $ret{success} = $S->delete_step($id);
    }
    else
    {
        $ret{error} = "Missing ID";
    }

    return $self->reply(\%ret);
}

1;
