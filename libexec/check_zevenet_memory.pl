#!/usr/bin/perl
###############################################################################
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
#    check_zevenet_memory.pl
#
#    --------------------------------------------------------------------------
#
#    Check free memory of a Zevenet ADC Load Balancer appliance. Zevenet API v3 
#    (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics from 
#    Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Return CRITICAL if free memory is below CRITICAL treshold.
#
#    Return WARNING if free memory is below WARNING treshold.
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
use Nagios::Plugin;

use vars qw($VERSION $PROGNAME  $verbose $warn $critical $timeout $result);
$VERSION = '1.0';

# Get the base name of this script
use File::Basename;
$PROGNAME = basename($0);


###############################################################################
#  Define and get the command line options.
#   see the command line option guidelines at 
#   https://nagios-plugins.org/doc/guidelines.html#PLUGOPTIONS


# Instantiate Nagios::Plugin object (the 'usage' parameter is mandatory)
my $p = Nagios::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>]
	[ -z|--zapikey=<Zevenet API v3 ZAPI_KEY> ]
    [ -c|--critical=<critical threshold> ] 
    [ -w|--warning=<warning threshold> ]",
    version => $VERSION,
    blurb => 'Check memory status of a Zevenet ADC Load Balancer appliance.', 
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
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.},
	required => 1,
#	default => 10,
);

# CRITICAL threshold
$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number of the generated result, outside of
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

my $total_memory = $response_decoded->{'params'}->{'MemTotal'};
my $free_memory = $response_decoded->{'params'}->{'MemFree'};
my $buffers_memory = $response_decoded->{'params'}->{'Buffers'};
my $cached_memory = $response_decoded->{'params'}->{'Cached'};
my $used_memory = $response_decoded->{'params'}->{'MemUsed'};

my $free_memory_percentage = ($free_memory/ $total_memory) * 100;

my $critical_theshold = $p->opts->critical;
my $warning_theshold = $p->opts->warning;

$critical_theshold =~ s/\://;
$warning_theshold =~ s/\://;

my $critical_theshold_mb = ($critical_theshold * $total_memory) / 100;
my $warning_theshold_mb = ($warning_theshold * $total_memory) / 100;

my $free_memory_percentage_string = sprintf("%.2f", ($free_memory/ $total_memory) * 100);


###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Free",
  value => $free_memory,
  uom => "Mb",
  warning   => $warning_theshold_mb,
  critical  => $critical_theshold_mb,
);

$p->add_perfdata( 
  label => "Buffers",
  value => $buffers_memory,
  uom => "Mb"
);

$p->add_perfdata( 
  label => "Cached",
  value => $cached_memory,
  uom => "Mb"
);

$p->add_perfdata( 
  label => "Used",
  value => $used_memory,
  uom => "Mb"
);

$p->add_perfdata( 
  label => "Total",
  value => $total_memory,
  uom => "Mb",
);


###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

# Threshold methods 
my $code = $p->check_threshold(
  check => $free_memory_percentage,
  warning => $p->opts->warning,
  critical => $p->opts->critical,
);

# Exit
$p->nagios_exit( 
	 return_code => $code, 
	 message => "Zevenet ADC Load Balancer free memory is $free_memory_percentage_string % (Free $free_memory Mb / Total: $total_memory Mb)" 
);

