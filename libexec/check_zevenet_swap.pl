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
#    check_zevenet_swap.pl
#
#    --------------------------------------------------------------------------
#
#    Check free swap space of a Zevenet ADC Load Balancer appliance. Zevenet 
#    API v3 (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics
#    from Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Return CRITICAL if swap free space is below CRITICAL treshold.
#
#    Returns WARNING if swap free space is below WARNING and greater than 
#
#    CRITICAL treshold.
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
    [ -c|--critical=<critical threshold> ] 
    [ -w|--warning=<warning threshold> ]",
    version => $VERSION,
    blurb => 'Check swap memory status of a Zevenet ADC Load Balancer appliance.', 
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

# WARNING threshold
$p->add_arg(
	spec => 'warning|w=s',
	help => 
qq{-w, --warning=INTEGER:INTEGER
   Minimum and maximum free swap space in Mb, outside of which a
   warning will be generated.  If omitted, no warning is generated.},
	required => 1,
#	default => 10,
);

# CRITICAL threshold
$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum free swap spacein Mb, outside of
   which a critical will be generated. },
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
unless ( defined $p->opts->warning || defined $p->opts->critical ) {
	$p->nagios_die( " You didn't supply a threshold argument " );
}



###############################################################################
# Check stuff.

#  Don't forget to timeout after $p->opts->timeout seconds, if applicable.

my $host = $p->opts->host;
my $port = 444;

# https://www.zevenet.com/zapidocv3/#show-memory-statistics
my $url = "/zapi/v3/zapi.cgi/stats/system/memory";

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

# Example response body
#
# {
#    "description" : "Memory usage",
#    "params" : {
#       "Buffers" : 51.51,
#       "Cached" : 82.18,
#       "MemFree" : 181.11,
#       "MemTotal" : 488.82,
#       "MemUsed" : 307.71,
#       "SwapCached" : 0.04,
#       "SwapFree" : 1503.8,
#       "SwapTotal" : 1504,
#       "SwapUsed" : 0.2,
#       "date" : "Wed Jun  7 12:33:03 2017",
#       "hostname" : "zvato505"
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

my $cached_swap = $response_decoded->{'params'}->{'SwapCached'};
my $free_swap = $response_decoded->{'params'}->{'SwapFree'};
my $total_swap = $response_decoded->{'params'}->{'SwapTotal'};
my $used_swap = $response_decoded->{'params'}->{'SwapUsed'};

my $free_swap_percentage = ($free_swap/ $total_swap) * 100;

my $critical_threshold = $p->opts->critical;
my $warning_threshold = $p->opts->warning;

$critical_threshold =~ s/\://;
$warning_threshold =~ s/\://;

my $critical_threshold_mb = ($critical_threshold * $total_swap) / 100;
my $warning_threshold_mb = ($warning_threshold * $total_swap) / 100;

my $free_swap_percentage_string = sprintf("%.2f", ($free_swap / $total_swap) * 100);


###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Free",
  value => $free_swap,
  uom => "MB",
  warning   => $warning_threshold_mb,
  critical  => $critical_threshold_mb,
);

$p->add_perfdata( 
  label => "Cached",
  value => $cached_swap,
  uom => "MB"
);

$p->add_perfdata( 
  label => "Used",
  value => $used_swap,
  uom => "MB"
);

$p->add_perfdata( 
  label => "Total",
  value => $total_swap,
  uom => "MB",
);


###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

# Threshold methods 
my $code = $p->check_threshold(
  check => $free_swap_percentage,
  warning => $p->opts->warning,
  critical => $p->opts->critical,
);

# Exit
$p->nagios_exit( 
	 return_code => $code, 
	 message => "Zevenet ADC Load Balancer free swap space is $free_swap_percentage_string % (Free $free_swap Mb / Total: $total_swap Mb)" 
);
