#!/usr/bin/perl
#################################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
#
#    Copyright (C) 2014-today ZEVENET SL, Sevilla (Spain)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    --------------------------------------------------------------------------
#
#    check_zevenet_farm.pl
#
#    --------------------------------------------------------------------------
#
#    Check farm status of a Zevenet ADC Load Balancer appliance. Zevenet API 
#    v3 (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics
#    from Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Returns CRITICAL if farm is not in up state.
#
#    --------------------------------------------------------------------------
#
#    More info at https://www.zevenet.com/
#
#    Author: Mario Pino <mario.pino@zevenet.com>
#
###############################################################################


###############################################################################
# Prologue
use strict;
use warnings;
use WWW::Curl::Easy;
use JSON;
use Data::Dumper;
use Monitoring::Plugin;

use vars qw($VERSION $PROGNAME  $verbose $warn $critical $timeout $result);
$VERSION = '1.0';

# Get the base name of this script
use File::Basename;
$PROGNAME = basename($0);


###############################################################################
#  Define and get the command line options.
#   see the command line option guidelines at 
#   https://nagios-plugins.org/doc/guidelines.html#PLUGOPTIONS


# Instantiate Monitoring::Plugin object (the 'usage' parameter is mandatory)
my $p = Monitoring::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]
	[ -z|--zapikey=<Zevenet API v3 ZAPI_KEY> ]
    [ -n|--name=<farm_name> ]",
    version => $VERSION,
    blurb => 'Check farm status of a Zevenet ADC Load Balancer appliance.', 
	extra => ""
);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.

# Host option
$p->add_arg(
	spec => 'host|H=s',
	help => 
qq{-host, --H=STRING
   Zevenet ADC Load Balancer appliance IP address or FQDN hostname.},
	required => 1,
);

# ZAPI_KEY option
$p->add_arg(
	spec => 'zapikey|z=s',
	help => 
qq{-zapikey, --z=STRING
   Zevenet API v3 ZAPI_KEY},
	required => 1,
);

# FARM name
$p->add_arg(
	spec => 'name|n=s',
	help => 
qq{-n, --name=STRING
   Farm name.},
	required => 1,
#	default => 10,
);

# # WARNING threshold
# $p->add_arg(
	# spec => 'warning|w=s',
	# help => 
# qq{-w, --warning=INTEGER:INTEGER
   # Minimum and maximum number of tracked connections, outside of
   # which a warning will be generated.},
	# required => 1,
# #	default => 10,
# );

# # CRITICAL threshold
# $p->add_arg(
	# spec => 'critical|c=s',
	# help => 
# qq{-c, --critical=INTEGER:INTEGER
   # Minimum and maximum number of tracked connections, outside of
   # which a critical will be generated.. },
# );

# Timeout value
$p->add_arg(
	spec => 'timeout|t=s',
	help => 
qq{-t, --timeout=INTEGER
   Timeout value in seconds. },
   default => 15,
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

# Perform sanity check on command line options
unless ( defined $p->opts->name ) {
	$p->nagios_die( " You didn't supply a farm name " );
}



###############################################################################
# Check stuff.

#  Don't forget to timeout after $p->opts->timeout seconds, if applicable.

my $host = $p->opts->host;
my $farmname = $p->opts->name;
my $port = 444;

# https://www.zevenet.com/zapidocv3/#show-farms-statistics
my $url = "/zapi/v3/zapi.cgi/stats/farms";

my $zapikey = $p->opts->zapikey;

#  ZAPI v3 call
my $response_body;
my $retcode;
my $response_code;
my $response_decoded;
my $curl = WWW::Curl::Easy->new;
$curl->setopt(CURLOPT_HEADER,0);
$curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
$curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);

# Maximun time that a given cURL operation should only take
$curl->setopt(CURLOPT_TIMEOUT, $p->opts->timeout);

$curl->setopt(CURLOPT_URL, ("https://$host:$port$url"));
my @authHeader = ( 'Content-Type: application/json', "ZAPI_KEY: $zapikey");
$curl->setopt(CURLOPT_HTTPHEADER, \@authHeader);

# A filehandle, reference to a scalar or reference to a typeglob can be used here.
$curl->setopt(CURLOPT_WRITEDATA,\$response_body);

# Starts the actual request
$retcode = $curl->perform;

# Looking at the results...
if ($retcode != 0) {
	$p->nagios_die( "Curl error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf);
}

$response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

#print("$response_body\n");

# Example response body:
#
# {
#    "description" : "List all farms stats",
#    "farms" : [
#       {
#          "established" : 0,
#          "farmname" : "testHttps",
#          "pending" : 0,
#          "profile" : "https",
#          "status" : "up",
#          "vip" : "192.168.101.20",
#          "vport" : "120"
#       },
#       {
#          "established" : 0,
#          "farmname" : "httpFarm",
#          "pending" : 0,
#          "profile" : "http",
#          "status" : "up",
#          "vip" : "192.168.10.31",
#          "vport" : "8080"
#       },
#       {
#          "established" : 0,
#          "farmname" : "testDL",
#          "pending" : 0,
#          "profile" : "datalink",
#          "status" : "up",
#          "vip" : "192.168.102.72",
#          "vport" : "eth1"
#       },
#       {
#          "established" : 0,
#          "farmname" : "testL4",
#          "pending" : 0,
#          "profile" : "l4xnat",
#          "status" : "up",
#          "vip" : "192.168.10.31",
#          "vport" : "30"
#       },
#       {
#          "established" : 0,
#          "farmname" : "testGSLB",
#          "pending" : 0,
#          "profile" : "gslb",
#          "status" : "up",
#          "vip" : "192.168.10.31",
#          "vport" : "53"
#       }
#    ]
# }

$response_decoded = decode_json($response_body);

# DEBUG
#print  Dumper($response_decoded);
#exit;

# Wrong ZAPI key
if (defined $response_decoded->{'message'}) {
	if ($response_decoded->{'message'} eq 'Authorization required' ) {
		$p->nagios_exit( 
			 return_code => CRITICAL, 
			 message => "Authorization required, please specify a correct ZAPI v3 key!" 
		);
	}
}

my $farm_found = 0;
my $farm = "";
my $farm_established = "";
my $farm_pending = "";
my $farm_profile = "";
my $farm_status = "";
my $farm_vip = "";
my $farm_vport = "";

my $farms = $response_decoded->{'farms'};

foreach $farm (@$farms) {
	#print "Farm: " . $farm->{'farmname'} . "\n";
	if ($farm->{'farmname'} eq $farmname ) {
		$farm_found = 1;
		$farm_established = $farm->{'established'};
		$farm_pending = $farm->{'pending'};
		$farm_profile = $farm->{'profile'};
		$farm_status = $farm->{'status'};
		$farm_vip = $farm->{'vip'};
		$farm_vport = $farm->{'vport'};
	}
}

# Exit if farm not found
if ($farm_found eq 0) {
	$p->nagios_exit( 
		 return_code => CRITICAL, 
		 message => "Zevenet ADC Load Balancer farm '$farmname' not found!" 
	);
}

# my $critical_threshold = $p->opts->critical;
# my $warning_threshold = $p->opts->warning;

###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Stablished connections",
  value => $farm_established,
  # warning   => $warning_threshold,
  # critical  => $critical_threshold,
);

$p->add_perfdata( 
  label => "Pending connections",
  value => $farm_pending,
  # warning   => $warning_threshold,
  # critical  => $critical_threshold,
);


###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

if ($farm_status eq "up") {

	# Exit
	$p->nagios_exit( 
		return_code => OK, 
		message => "Zevenet ADC Load Balancer $farm_profile farm '$farmname' listen at $farm_vip:$farm_vport is $farm_status (established connections: $farm_established / pending connections: $farm_pending)" 
	);


} else {

	# Exit
	$p->nagios_exit( 
		return_code => CRITICAL, 
		message => "Zevenet ADC Load Balancer $farm_profile farm '$farmname' listen at $farm_vip:$farm_vport is $farm_status (established connections: $farm_established / pending connections: $farm_pending)"  
	);

}
