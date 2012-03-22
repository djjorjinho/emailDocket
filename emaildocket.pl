#!/usr/bin/env perl
use strict;
use Data::Dumper;
use Cwd;
use Mojolicious::Lite;
use MongoDB;
use IP::Country::Fast;
use Geo::IP;
use DateTime;
use lib './lib';

# current path
my $cwd = fastgetcwd();

# connect to mongodb
my $conn = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db   = $conn->local;

# "whois" helper
app->helper(whois => sub {
    my $self  = shift;
    my $agent = $self->req->headers->user_agent || 'Anonymous';
    my $ip    = $self->tx->remote_address;
    return ($agent,$ip);
});

app->helper(logid => sub {
    my ($self,$id,$ip,$agent)  = @_;
    
    my $dt = DateTime->now;
    my $reg = IP::Country::Fast->new();
    my $gi = Geo::IP->open( $cwd."/GeoLiteCity.dat");
    my $r = $gi->record_by_addr( $ip );
    
    my $dockets = $db->dockets;
    my $logs = $db->logs;
    my $R = $dockets->find_one({email_id=>$id});
    
    my $obj = {email_id => $id,date=>$dt->datetime(),ts=>$dt->epoch(),ip=>$ip,agent=>$agent};
    if($r){$obj->{country}=$r->country_name; $obj->{city}=$r->city;}
    
    if($R){
        $logs->insert($obj);
    }else{
        $dockets->insert({ email_id => $id,date=>$dt->datetime(),ts=>$dt->epoch()});
        $logs->insert($obj);
    }
    
    return ;
});

my $ignoreip = {
                '192.168.0.1' => 1,
                '127.0.0.1' => 1,
                };

# routes
get '/(:id).gif' => sub{
        my $self = shift;
        my $id = $self->param('id');
        my ($agent,$ip) = $self->whois();
        $self->logid($id,$ip,$agent) if(not $ignoreip->{$ip});
        #app->log->info("$id docket by $ip,$agent");
        my $fh;
        open($fh,$cwd.'/img/1.gif');
        my $octets = <$fh>;
        close $fh;
        $self->render(data=>$octets,format=>'gif');
    };

get '/test' => sub {
    my $self = shift;
    
    my $id = $self->param('id');
    my $list = $self->param('list');
    
    if($id){
        my $logs = $db->logs;
        my $c = $logs->find({email_id=>$id});
        my @r = $c->all();
        $self->render(text => Dumper(\@r));
    }elsif($list){
        my $dockets = $db->dockets;
        my $c = $dockets->find();
        my @r = $c->all();
        $self->render(text => Dumper(\@r));
    }else{
        $self->render(text => Dumper($self));
    }
};

get '/' => sub {
    my $self = shift;
    $self->render(text => "");
};



# starting server
app->secret('myownstuffheyheyhey');
app->mode('production');
app->log->level('error');
app->start;