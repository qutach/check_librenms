#!/usr/bin/env perl

use warnings;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;
use Nagios::Monitoring::Plugin;
use Data::Dumper;

my $np = Nagios::Monitoring::Plugin->new(
    usage => "Usage: %s -u|--url <http(s)://<librenms-url>:port/<API uri> -a|--attributes <attributes> "
    . "[ -c|--critical <thresholds> ] "
    . "[ -w|--warning <thresholds> ] "
    . "[ -x|--xauth <X-Auth-Token> ] "
    . "[ --ignoressl ] "
    . "[ -h|--help ] ",
    version => '1.0',
    blurb   => 'Nagios plugin to check LibreNMS Alerts (REST API)',
    plugin  => 'check_librenms',
    timeout => 15,
    shortname => "Check LibreNMS Alerts",
);

$np->add_arg(
    spec => 'url|u=s',
    help => '-u, --url http://librenms.domain.com/api/v01',
);

$np->add_arg(
    spec => 'warning|w=s',
    help => '-w, --warning INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'xauth|x=s',
    default => '',
    help => "--x|--xauth <X-Auth-Token>"
);

$np->add_arg(
    spec => 'ignoressl',
    help => "--ignoressl Ignore bad ssl certificates",
);


# Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;
if ($np->opts->verbose) { (print Dumper ($np))};


# Get URL
my $ua = LWP::UserAgent->new;

$ua->env_proxy;
$ua->agent('check_librenms/1.0');
$ua->default_header('Accept' => 'application/json', 'X-Auth-Token' => ($np->opts->xauth));
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

## Ignore Cert
if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

# Make request
my $response;
$response = $ua->request(GET $np->opts->url . '/api/v0/alerts');

if ($response->is_success) {    
} else {
    $np->nagios_exit(CRITICAL, "Connection failed to LibreNMS: ".$response->status_line);
}

# Check response
my $librenms = decode_json($response->decoded_content);

if (int($librenms->{'count'}) == 0) {
     $np->nagios_exit(OK, "Alerts in LibreNMS: ".$librenms->{'count'});
} else {
    if (int($librenms->{'count'}) >= (int($np->opts->critical))) {
        $np->nagios_exit(CRITICAL, "Alerts in LibreNMS: ".$librenms->{'count'});
    } else {
    if (int($librenms->{'count'}) >= (int($np->opts->warning))) {
        $np->nagios_exit(WARNING, "Alerts in LibreNMS: ".$librenms->{'count'});
    }
  }
}
