#!/usr/bin/perl
################################################################################
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
#    check_zevenet_cpu.pl
#
#    --------------------------------------------------------------------------
#
#    Check CPU of a Zevenet ADC Load Balancer appliance. Zevenet API v3 
#    (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics from 
#    Zevenet ADC Load Balancer appliance. Provides performance data.
#    
#    --------------------------------------------------------------------------
#
#    Return CRITICAL if CPU usage is higher than CRITICAL treshold
#    
#    Return WARNING if CPU usage is higher than WARNING treshold and below 
#    
#    CRITICAL.
#
#    --------------------------------------------------------------------------
#    
#    More info at https://www.zevenet.com/
#    
#    Author: Mario Pino <mario.pino@zevenet.com>
#
################################################################################


################################################################################
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
    blurb => 'Check CPU usage of a Zevenet ADC Load Balancer appliance.', 
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

# print "Timeout: " . $p->opts->timeout . " seconds";
# exit;

###############################################################################
# Check stuff.

#  Don't forget to timeout after $p->opts->timeout seconds, if applicable.

my $host = $p->opts->host;
my $port = 444;

# https://www.zevenet.com/zapidocv3/#show-cpu-statistics
my $url = "/zapi/v3/zapi.cgi/stats/system/cpu";

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
#    "description" : "System CPU usage",
#    "params" : {
#       "cores" : 2,
#       "date" : "Fri Jan 27 13:30:52 2017",
#       "hostname" : "api3",
#       "idle" : 94.9,
#       "iowait" : 0,
#       "irq" : 0,
#       "nice" : 0,
#       "softirq" : 0,
#       "sys" : 3.06,
#       "usage" : 5.1,
#       "user" : 2.04
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
			 message => "Authorization required, please especify a correct ZAPI v3 key!" 
		);
	}
}

my $idle_cpu = $response_decoded->{'params'}->{'idle'};
my $iowait_cpu = $response_decoded->{'params'}->{'iowait'};
my $irq_cpu = $response_decoded->{'params'}->{'irq'};
my $nice_cpu = $response_decoded->{'params'}->{'nice'};
my $softirq_cpu = $response_decoded->{'params'}->{'softirq'};
my $sys_cpu = $response_decoded->{'params'}->{'sys'};
my $usage_cpu = $response_decoded->{'params'}->{'usage'};
my $user_cpu = $response_decoded->{'params'}->{'user'};

#my $total_cpu = $idle_cpu + $iowait_cpu + $irq_cpu + $nice_cpu + $softirq_cpu + $sys_cpu + $usage_cpu + $user_cpu;
my $total_cpu = $idle_cpu + $iowait_cpu + $irq_cpu + $nice_cpu + $softirq_cpu + $sys_cpu + $user_cpu;



my $critical_theshold = $p->opts->critical;
my $warning_theshold = $p->opts->warning;

$critical_theshold =~ s/\://;
$warning_theshold =~ s/\://;




###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Idle",
  value => $idle_cpu,
  uom => "%",
  warning   => $warning_theshold,
  critical  => $critical_theshold,
);

$p->add_perfdata( 
  label => "IOWait",
  value => $iowait_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "IRQ",
  value => $irq_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "Nice",
  value => $nice_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "SoftIRQ",
  value => $softirq_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "Sys",
  value => $sys_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "Usage",
  value => $usage_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "User",
  value => $user_cpu,
  uom => "%"
);

$p->add_perfdata( 
  label => "Total",
  value => $total_cpu,
  uom => "%"
);

###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

# Threshold methods 
my $code = $p->check_threshold(
  check => $idle_cpu,
  warning => $p->opts->warning,
  critical => $p->opts->critical,
);

# Exit
$p->nagios_exit( 
	 return_code => $code, 
	 message => "Zevenet ADC Load Balancer CPU usage is $usage_cpu % ($idle_cpu % idle)" 
);

