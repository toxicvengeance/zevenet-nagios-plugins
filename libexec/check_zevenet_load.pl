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
#    check_zevenet_load.pl
#
#    --------------------------------------------------------------------------
#
#    Check load averages of a Zevenet ADC Load Balancer appliance. Zevenet API 
#    v3 (https://www.zevenet.com/zapidocv3/) is used to retrieve the metrics
#    from Zevenet ADC Load Balancer appliance. Provides performance data.
# 
#    --------------------------------------------------------------------------
#
#    Returns CRITICAL if 1/5/15 minutes average load are greater than CRITICAL 
#    tresholds.
#
#    Returns WARNING if 1/5/15 minutes average load are below CRITICAL and 
#    greater than WARNING tresholds.
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
	[ -w|--warning=<WLOAD1>,<WLOAD5>,<WLOAD15> ]
    [ -c|--critical=<CLOAD1>,<CLOAD5>,<CLOAD15> ]",
    version => $VERSION,
    blurb => 'Check load of a Zevenet ADC Load Balancer appliance.', 
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

# WARNING thresholds
$p->add_arg(
	spec => 'warning|w=s',
	help => 
qq{-w, --warning=INTEGER,INTEGER,INTEGER
   Warning thresholds for 1, 5 and 15 min load averages.},
	required => 1,
#	default => 10,
);

# CRITICAL thresholds
$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-w, --critical=INTEGER,INTEGER,INTEGER
   Critical thresholds for 1, 5 and 15 min load averages.},
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

# https://www.zevenet.com/zapidocv3/#show-load-statistics
my $url = "/zapi/v3/zapi.cgi/stats/system/load";

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
#    "description" : "System load",
#    "params" : {
#       "Last_1" : 0.66,
#       "Last_15" : 0.39,
#       "Last_5" : 0.49,
#       "date" : "Fri Jan 27 13:15:01 2017",
#       "hostname" : "api3"
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

my $load_1_min = $response_decoded->{'params'}->{'Last_1'};
my $load_5_min = $response_decoded->{'params'}->{'Last_5'};
my $load_15_min = $response_decoded->{'params'}->{'Last_15'};


my $warning_thresholds = $p->opts->warning;
my @warning_thresholds_array = split(/,/, $warning_thresholds);
my $load_1_min_warning_threshold = $warning_thresholds_array[0];
my $load_5_min_warning_threshold = $warning_thresholds_array[1];
my $load_15_min_warning_threshold = $warning_thresholds_array[2];

my $critical_thresholds = $p->opts->critical;
my @critical_thresholds_array = split(/,/, $critical_thresholds);
my $load_1_min_critical_threshold = $critical_thresholds_array[0];
my $load_5_min_critical_threshold = $critical_thresholds_array[1];
my $load_15_min_critical_threshold = $critical_thresholds_array[2];

###############################################################################
# Perfdata methods
#

$p->add_perfdata( 
  label => "Load 1 min",
  value => $load_1_min,
  uom => "Avg.",
  warning   => $load_1_min_warning_threshold,
  critical  => $load_1_min_critical_threshold,
);

$p->add_perfdata( 
  label => "Load 5 min",
  value => $load_5_min,
  uom => "Avg.",
  warning   => $load_5_min_warning_threshold,
  critical  => $load_5_min_critical_threshold,
);

$p->add_perfdata( 
  label => "Load 15 min",
  value => $load_15_min,
  uom => "Avg.",
  warning   => $load_15_min_warning_threshold,
  critical  => $load_15_min_critical_threshold,
);


###############################################################################
# Check the result against the defined warning and critical thresholds,
# output the result and exit

if ($load_1_min > $load_1_min_critical_threshold) {
	
	# Critical
	$p->nagios_exit( 
		 return_code => CRITICAL, 
		 message => "Zevenet ADC Load Balancer 1 Min Load average is CRITICAL (Avg. 1 min load is $load_1_min)" 
	);

} elsif ($load_1_min > $load_1_min_warning_threshold) {

	# Warning
	$p->nagios_exit( 
		 return_code => WARNING, 
		 message => "Zevenet ADC Load Balancer 1 Min Load average is WARNING (Avg. 1 min load is $load_1_min)" 
	);

}

if ($load_5_min > $load_5_min_critical_threshold) {
	
	# Critical
	$p->nagios_exit( 
		 return_code => CRITICAL, 
		 message => "Zevenet ADC Load Balancer 5 Min Load average is CRITICAL (Avg. 5 min load is $load_5_min)" 
	);

} elsif ($load_5_min > $load_5_min_warning_threshold) {

	# Warning
	$p->nagios_exit( 
		 return_code => WARNING, 
		 message => "Zevenet ADC Load Balancer 5 Min Load average is WARNING (Avg. 5 min load is $load_5_min)" 
	);

}


if ($load_15_min > $load_15_min_critical_threshold) {
	
	# Critical
	$p->nagios_exit( 
		 return_code => CRITICAL, 
		 message => "Zevenet ADC Load Balancer 15 Min Load average is CRITICAL (Avg. 15 min load is $load_15_min)" 
	);

} elsif ($load_15_min > $load_15_min_warning_threshold) {

	# Warning
	$p->nagios_exit( 
		 return_code => WARNING, 
		 message => "Zevenet ADC Load Balancer 15 Min Load average is WARNING (Avg. 15 min load is $load_15_min)" 
	);

}


# Ok
$p->nagios_exit( 
	 return_code => OK, 
	 message => "Zevenet ADC Load Balancer Load average is OK (Avg. load is $load_1_min/$load_5_min/$load_15_min)" 
);