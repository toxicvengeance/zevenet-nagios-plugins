# Zevenet Nagios Plugins

Nagios plugin collection written in Perl to monitor Zevenet ADC Load Balancer Enterprise Edition system health check and performance.



| Plugin                             | Check             | Provided performance data                                                  |
| ---------------------------------- | ----------------- | ---------------------------------------------------------------------------|
| check_zevenet_cpu.pl               | CPU usage         | Idle, iowait, irq, nice, softirq, system, usage, user and total CPU usage  |
| check_zevenet_farm.pl              | Farm status       | Established and pending connections                                        | 
| check_zevenet_farm_backend.pl      | Backend status    | Established and pending connections                                        | 
| check_zevenet_interface.pl         | Interface status  | Traffic in and out                                                         |            
| check_zevenet_memory.pl            | Memory usage      | Free, buffers, cached, used and total                                      |
| check_zevenet_swap.pl              | Swap usage        | Free, cached, used and total                                               |
| check_zevenet_total_connections.pl | Total connections | Total connections                                                          |


The plugins are also compatible with Icinga, Naemon, Shinken, Sensu, and other monitoring applications.

Nagios (https://www.nagios.org) is a enterprise-class Open Source IT monitoring, network monitoring, server and applications monitoring.  

Plugins provide performace data, so yo can use PNP4Nagios (https://docs.pnp4nagios.org/) or similar tool to make graphs from 
collected metrics.

Further information about how to use this package in the following article:
https://www.zevenet.com/knowledge-base/howtos/monitoring-zevenet-nagios/


## INSTALLATION

Zevenet Nagios Plugins are developed to be installed in your Nagios (Or Nagios plugin's compatible) monitoring server. So please access via SSH to
your monitoring host as root to install the required software.

### 1. Install dependencies

Install required perl modules:

#### Debian Jessie:

```
apt-get update && apt-get install libwww-curl-perl libjson-perl libmonitoring-plugin-perl
```

If Perl modules doesn't exist in your distribution package manager, you can install manually:

#### Other distributions:

```
perl -MCPAN -e 'install WWW::Curl'
perl -MCPAN -e 'install JSON'
perl -MCPAN -e 'install Monitoring::Plugin'  
```


### 2. Decompress Zevenet Nagios plugins pack

```
wget https://github.com/zevenet/zevenet-nagios-plugins/archive/master.zip 
unzip master.zip
```

### 3. Copy check scripts to /usr/local/nagios/libexec/

```
cd zevenet-nagios-plugins
cp libexec/* /usr/local/nagios/libexec/
```

### 4. Create a valid ZAPI v3 key thought Zevenet ADC Load Balancer web interface

Login into Zevenet web interface and go to System > Users > Edit zapi user > Generate random key, we'll use this key as a authentication method to retrieve the metrics from Zevenet ADC Load Balancer appliance.  Finally make sure zapi user is active.


### 5. Test plugin manually

```
cd /usr/local/nagios/libexec/
perl check_zevenet_cpu.pl -H <zevenet_appliance_ip_address> -z <zevenet_appliance_api_v3_key> -w 20 -c 10
```
Example output:

```
ZEVENET_CPU CRITICAL - Zevenet ADC Load Balancer CPU usage is 40 % (Idle 60 %) | Idle=60%;20;10 IOWait=0%;; IRQ=0%;; Nice=0%;; SoftIRQ=0%;; Sys=8%;; Usage=40%;; User=32%;; Total=100%;;
```

### 6. Add commands definition to Nagios configuration

See Nagios command definitions example file in etc/zevenet_commands.cfg.

You can add the command definitions to your Nagios configuration:

```
cd etc
cat zevenet_commands.cfg >>/usr/local/nagios/etc/objects/commands.cfg
```

### 7. Add services to Nagios configuration

See Nagios service definitions example file in etc/zevenet_services.cfg

Make sure you replace the string <zapi_v3_key> with the Zevenet API v3 key string you generate in step 4.

You can also tune the tresholds to suit your needs. See more information in 'Threshold and ranges' section at https://nagios-plugins.org/doc/guidelines.html.


### 8. Restart Nagios and have fun!

Restart Nagios process and access Nagios web interface to see the services you have just created.
 
