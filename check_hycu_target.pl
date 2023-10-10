#!/usr/bin/perl -w
#=============================================================================== 
# Script Name   : check_hycu_target.pl
# Usage Syntax  : check_hycu_target.pl -H <hostname> -p <port>  -u <User> -P <password> [-w <threshold> ] [-c <threshold> ]  [-t <timeout>] [-a <apiversion>] 
# Version       : 1.0.2
# Last Modified : 24/01/2023
# Modified By   : Start81 (DESMAREST JULIEN) 
# Description   : Nagios check that uses HYCUs REST API to get target storage usage and status
# Depends On    : REST::Client Data::Dumper Monitoring::Plugin MIME::Base64 JSON LWP::UserAgent Readonly
# 
# Changelog: 
#    Legend: 
#       [*] Informational, [!] Bugfix, [+] Added, [-] Removed 
#  - 15/04/2022| 1.0.0 | [*] First release
#  - 19/04/2022| 1.0.1 | [!] bug fix now skip target without storage
#  - 24/01/2023| 1.0.2 | [!] bug fix now skip inactive target 
#===============================================================================

use strict;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use warnings;
use Monitoring::Plugin;
use Data::Dumper;
use REST::Client;
use Data::Dumper;
use JSON;
use utf8; 
use MIME::Base64;
use LWP::UserAgent;
use File::Basename;
use Readonly;

Readonly our $VERSION => "1.0.2";
my $me = basename($0);
my $o_verb;
sub verb { my $t=shift; if ($o_verb) {print $t,"\n"}  ; return 0 }

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -H <hostname> -p <port>  -u <User> -P <password> [-w <threshold> ] [-c <threshold> ]  [-t <timeout>] [-a <apiversion>] \n",
    plugin => $me,
    shortname => $me,
    blurb => "$me Nagios check that uses HYCUs REST API to get target status and storage usage",
    version => $VERSION,
    timeout => 30
);
$np->add_arg(
    spec => 'host|H=s',
    help => "-H, --host=STRING\n"
          . '   Hostname',
    required => 1
);
$np->add_arg(
    spec => 'port|p=i',
    help => "-p, --port=INTEGER\n"
          . '  Port Number',
    required => 1,
    default => "8443"
);
$np->add_arg(
    spec => 'apiversion|a=s',
    help => "-a, --apiversion=string\n"
          . '  HYCU API version',
    required => 1,
    default => 'v1.0'
);
$np->add_arg(
    spec => 'user|u=s',
    help => "-u, --user=string\n"
          . '  User name for api authentication',
    required => 1,
);
$np->add_arg(
    spec => 'Password|P=s',
    help => "-P, --Password=string\n"
          . '  User password for api authentication',
    required => 1,
);
$np->add_arg(
    spec => 'name|n=s',
    help => "-n, --name=STRING\n"
          . '   target name',
    required => 0
);
$np->add_arg(
    spec => 'ssl|S',
    help => "-S, --ssl\n   The hycu serveur use ssl",
    required => 0
);
$np->add_arg(
    spec => 'warning|w=s',
    help => "-w, --warning=threshold\n" 
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);
$np->add_arg(
    spec => 'critical|c=s',
    help => "-c, --critical=threshold\n"  
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);

$np->getopts;

#Get parameters
my $o_host = $np->opts->host;
my $o_login = $np->opts->user;
my $o_pwd = $np->opts->Password;
my $o_apiversion = $np->opts->apiversion;
my $o_port = $np->opts->port;
my $o_use_ssl = 0;
my $o_name = $np->opts->name;
$o_use_ssl = $np->opts->ssl if (defined $np->opts->ssl);
$o_verb = $np->opts->verbose;
my $o_warning = $np->opts->warning;
my $o_critical = $np->opts->critical;
my $o_timeout = $np->opts->timeout;

#Check parameters
if ($o_timeout > 60){
    $np->plugin_die("Invalid time-out");
}

#Rest client Init
my $client = REST::Client->new();
$client->setTimeout($o_timeout);
my $url = "http://";
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
$client->addHeader('Accept-Encoding',"gzip, deflate, br");
if ($o_use_ssl) {
    my $ua = LWP::UserAgent->new(
        timeout  => $o_timeout,
        ssl_opts => {
            verify_hostname => 0,
            SSL_verify_mode => SSL_VERIFY_NONE
        },
    );
    $url = "https://";
    $client->setUseragent($ua);
}
$url = "$url$o_host:$o_port/rest/$o_apiversion/targets?pageSize=100&pageNumber=1&includeDatastores=false";
#Add authentication
$client->addHeader('Authorization', 'Basic ' . encode_base64("$o_login:$o_pwd"));
verb($url);
$client->GET($url);
if($client->responseCode() ne '200'){
    $np->plugin_exit('UNKNOWN', "response code : " . $client->responseCode() . " Message : Error when getting target list". $client->{_res}->decoded_content );
}

my $rep = $client->{_res}->decoded_content;
my $target = from_json($rep);
my $i = 0;
my @criticals = ();
my @warnings = ();
my @not_found_lists;
my @target_list;
my $msg;
my $target_found = 0;

while (exists ($target->{'entities'}->[$i])){
    my $name = $target->{'entities'}->[$i]->{'name'};
    my $capacity_in_bytes = $target->{'entities'}->[$i]->{'totalSizeInBytes'};
    if ((!defined($o_name)||(index($o_name,$name)!= - 1))){
        if ($target->{'entities'}->[$i]->{'status'} eq "ACTIVE"){
            if (defined($capacity_in_bytes)) {
                push(@target_list,  $name);
                verb(Dumper($target->{'entities'}->[$i]));
                $target_found = $target_found +1;
                my $target_status = "KO";
                $target_status = $target->{'entities'}->[$i]->{'testResult'} if ($target->{'entities'}->[$i]->{'testResult'});
                my $error_msg = $target->{'entities'}->[$i]->{'testErrorMessage'}->{'detailsDescriptionEn'} if (defined($target->{'entities'}->[$i]->{'testErrorMessage'}));
                my $free_size_in_bytes = $target->{'entities'}->[$i]->{'freeSizeInBytes'};
                my $total_usage_bytes = $capacity_in_bytes - $free_size_in_bytes;
                my $usage_per100 = ($total_usage_bytes * 100) / $capacity_in_bytes ;
                $usage_per100 = substr($usage_per100 ,0,5);
            
                #"status": "ACTIVE"
                if (($target_status  ne 'OK' or ($error_msg ))) {
                    $msg = "$name test result is $target_status $error_msg storage usage  : $usage_per100%";
                    push( @criticals, $msg) ;
                }
                $np->add_perfdata(label => $name, value => $usage_per100, uom => "%", warning => $o_warning, critical => $o_critical);
                if ((defined($np->opts->warning) || defined($np->opts->critical))) {
                    $np->set_thresholds(warning => $o_warning, critical => $o_critical);
                    my $exit_code = $np->check_threshold($usage_per100);
                    push( @criticals, "$name storage almost full") if ($exit_code == 2);
                    push( @warnings, "$name target storage almost full") if ($exit_code == 1);
                } 
                
            } else {
                verb("SKIPPED $name empty storage")
            }
        } else {
            verb("SKIPPED $name State Inactive")
        } 
        
        
    } else {
        push(@not_found_lists,  $name) if (defined($capacity_in_bytes) || ($target->{'entities'}->[$i]->{'status'} eq "ACTIVE"));
    }
    
    $i=$i+1;
}
#Format output
$np->plugin_exit('UNKNOWN', "Target not found or disabled. Active target(s) are : " . join(", ", @not_found_lists)) if ($target_found == 0);
$np->plugin_exit('CRITICAL', join(', ', @criticals)) if (scalar @criticals > 0);
$np->plugin_exit('WARNING', join(', ', @warnings)) if (scalar @warnings > 0);
$np->plugin_exit('OK', "Targets ". join(", ", @target_list) . " are ok ") if (scalar @target_list> 1);
$np->plugin_exit('OK', "Target ". join(", ", @target_list) . " is ok ") ;
