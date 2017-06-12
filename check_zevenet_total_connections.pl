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
#    check_zevenet_total_connections.pl
#
#    --------------------------------------------------------------------------
#
#    Check total connections of a Zevenet ADC Load Balancer appliance. Zevenet 
#    API v3 (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics
#    from Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Returns CRITICAL if total connections are greater than CRITICAL treshold.
#
#    Returns WARNING if total connections are greater than WARNING and below 
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
	[ -w|--warning=<warning threshold> ]
    [ -c|--critical=<critical threshold> ]",
    version => $VERSION,
    blurb => 'Check total connections of a Zevenet ADC Load Balancer appliance.', 
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
   Minimum and maximum number, outside of
   which a warning will be generated.},
	required => 1,
#	default => 10,
);

# CRITICAL threshold
$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number, outside of
   which a critical will be generated.. },
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

# https://www.zevenet.com/zapidocv3/#show-connections-statistics
my $url = "/zapi/v3/zapi.cgi/stats/system/connections";

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
#    "description" : "System connections",
#    "params" : {
#       "connections" : 324
#    }
# }

$response_decoded = decode_json($response_body);

# DEBUG
#print  Dumper($response_decoded);
#exit;

my $total_connections = $response_decoded->{'params'}->{'connections'};

my $critical_theshold = $p->opts->critical;
my $warning_theshold = $p->opts->warning;

$critical_theshold =~ s/\://;
$warning_theshold =~ s/\://;




###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Total connections",
  value => $total_connections,
  uom => "Conns.",
  warning   => $warning_theshold,
  critical  => $critical_theshold,
);

###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

# Threshold methods 
my $code = $p->check_threshold(
  check => $total_connections,
  warning => $p->opts->warning,
  critical => $p->opts->critical,
);

# Exit
$p->nagios_exit( 
	 return_code => $code, 
	 message => "Zevenet ADC Load Balancer: $total_connections total tracked connections" 
);

