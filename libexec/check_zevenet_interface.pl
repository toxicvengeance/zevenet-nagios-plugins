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
#    check_zevenet_interface.pl
#
#    --------------------------------------------------------------------------
#
#    Check interface status of a Zevenet ADC Load Balancer appliance. Zevenet 
#    API v3 (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics
#    from Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Returns CRITICAL if specified interface status is not up
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
    [ -n|--name=<interface_name> ]",
    version => $VERSION,
    blurb => 'Check interface status of a Zevenet ADC Load Balancer appliance.', 
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

# INTERFACE name
$p->add_arg(
	spec => 'name|n=s',
	help => 
qq{-n, --name=STRING
   Interface name.},
	required => 1,
#	default => 10,
);

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
	$p->nagios_die( " You didn't supply a interface name " );
}



###############################################################################
# Check stuff.

#  Don't forget to timeout after $p->opts->timeout seconds, if applicable.

my $host = $p->opts->host;
my $port = 444;

# https://www.zevenet.com/zapidocv3/#show-interfaces-statistics
my $url = "/zapi/v3/zapi.cgi/stats/system/network/interfaces";

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
#    "description" : "Interfaces info",
#    "params" : {
#       "bond" : [
#          {
#             "in" : "234.72",
#             "interface" : "bond1",
#             "ip" : "",
#             "mac" : "3a:3a:a7:e3:33:73",
#             "out" : "0.00",
#             "slaves" : [
#                "eth2"
#             ],
#             "status" : "down",
#             "virtual" : [],
#             "vlan" : []
#          },
#          {
#             "in" : "815.70",
#             "interface" : "bond3",
#             "ip" : "",
#             "mac" : "ea:00:7d:88:1d:bd",
#             "out" : "4300.38",
#             "slaves" : [
#                "eth4",
#                "eth5",
#                "eth6"
#             ],
#             "status" : "up",
#             "virtual" : [],
#             "vlan" : []
#          },
#          {
#             "in" : "234.72",
#             "interface" : "bond0",
#             "ip" : "",
#             "mac" : "c2:d0:d7:64:df:68",
#             "out" : "0.00",
#             "slaves" : [
#                "eth1"
#             ],
#             "status" : "down",
#             "virtual" : [],
#             "vlan" : [
#                "bond0.10"
#             ]
#          }
#       ],
#       "nic" : [
#          {
#             "in" : "77.42",
#             "interface" : "eth6",
#             "ip" : "",
#             "mac" : "ea:00:7d:88:1d:bd",
#             "out" : "0.00",
#             "status" : "up",
#             "virtual" : [],
#             "vlan" : []
#          },
#          {
#             "in" : "2704.81",
#             "interface" : "eth0",
#             "ip" : "192.168.101.46",
#             "mac" : "9e:2e:3e:a5:2e:6a",
#             "out" : "51039.13",
#             "status" : "up",
#             "virtual" : [
#                "eth0:1",
#                "eth0:2",
#                "eth0.2:6"
#             ],
#             "vlan" : [
#                "eth0.2"
#             ]
#          },
#          {
#             "in" : "234.72",
#             "interface" : "eth1",
#             "ip" : "192.168.101.58",
#             "mac" : "c2:d0:d7:64:df:68",
#             "out" : "0.00",
#             "status" : "up",
#             "virtual" : [],
#             "vlan" : []
#          },
#          {
#             "in" : "234.72",
#             "interface" : "eth2",
#             "ip" : "",
#             "mac" : "3a:3a:a7:e3:33:73",
#             "out" : "0.00",
#             "status" : "up",
#             "virtual" : [],
#             "vlan" : []
#          },
#          {
#             "in" : "0.00",
#             "interface" : "eth3",
#             "ip" : "192.168.101.72",
#             "mac" : "16:97:ab:43:87:02",
#             "out" : "0.00",
#             "status" : "down",
#             "virtual" : [
#                "eth3:1",
#                "eth3:8",
#                "eth3:6"
#             ],
#             "vlan" : []
#          },
#          {
#             "in" : "436.89",
#             "interface" : "eth4",
#             "ip" : "",
#             "mac" : "ea:00:7d:88:1d:bd",
#             "out" : "4300.38",
#             "status" : "up",
#             "virtual" : [
#                "eth4.6:5"
#             ],
#             "vlan" : [
#                "eth4.6"
#             ]
#          },
#          {
#             "in" : "301.39",
#             "interface" : "eth5",
#             "ip" : "",
#             "mac" : "ea:00:7d:88:1d:bd",
#             "out" : "0.00",
#             "status" : "up",
#             "virtual" : [],
#             "vlan" : [
#                "eth5.5"
#             ]
#          }
#       ]
#    }
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

my $interface_name = $p->opts->name;
my $interface_type;
my $interface_status;
my $interface_in;
my $interface_out;
my $interface;

# Is Bond or NIC interface?

my $bond_interface_list = $response_decoded->{'params'}->{'bond'};
my $nic_interface_list = $response_decoded->{'params'}->{'nic'};


foreach $interface (@$nic_interface_list) {
	#print "Interface: " . $interface->{'interface'} . "\n";
	if ($interface->{'interface'} eq $interface_name ) {
		$interface_status = $interface->{'status'};
		$interface_in = $interface->{'in'};
		$interface_out = $interface->{'out'};
		$interface_type = "NIC";
	}
}

foreach $interface (@$bond_interface_list) {
	#print "Interface: " . $interface->{'interface'} . "\n";
	if ($interface->{'interface'} eq $interface_name ) {
		$interface_status = $interface->{'status'};
		$interface_in = $interface->{'in'};
		$interface_out = $interface->{'out'};
		$interface_type = "Bond";
	}
}

###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Traffic in",
  value => $interface_in,
);

$p->add_perfdata( 
  label => "Traffic out",
  value => $interface_out,
);

###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

if ($interface_status eq "up") {

	# Exit
	$p->nagios_exit( 
		 return_code => OK, 
		 message => "Zevenet ADC Load Balancer interface '$interface_name' is $interface_status (Traffic in: $interface_in Mbps / Traffic out: $interface_out Mbps)" 
	);


} else {

	# Exit
	$p->nagios_exit( 
		 return_code => CRITICAL, 
		 message => "Zevenet ADC Load Balancer interface '$interface_name' is $interface_status (Traffic in: $interface_in Mbps / Traffic out: $interface_out Mbps)" 
	);

}
