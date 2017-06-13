# Zevenet Nagios Plugins

Nagios plugin collection written in Perl to monitor Zevenet ADC Load Balancer system health and performance.


| Plugin                             | Description       | Performance data                                                 |
| ---------------------------------- | ----------------- | -----------------------------------------------------------------|
| check_zevenet_cpu.pl               | CPU usage         | Idle, iowait, irq, nice, softirq, system, usage, user and total  |
| check_zevenet_farm.pl              | Farm status       | Established and pending connections                              | 
| check_zevenet_interface.pl         | Interface status  | Traffic in and out                                               |            
| check_zevenet_memory.pl            | Memory usage      | Free, buffers, cached, used and total                            |
| check_zevenet_swap.pl              | Swap usage        | Free, cached, used and total                                     |
| check_zevenet_total_connections.pl | Total connections | Total connections                                                |

The plugins are also compatible with Icinga, Naemon, Shinken, Sensu, and other monitoring applications.

Nagios (https://www.nagios.org) is a enterprise-class Open Source IT monitoring, network monitoring, server and applications monitoring.  

Plugins provide performace data, so yo can use PNP4Nagios (https://docs.pnp4nagios.org/) or similar tool to make graphs from 
collected metrics.


## INSTALLATION

### 1. Install dependencies

Install required perl modules:

#### Debian Jessie:

```
apt-get update && apt-get install libwww-curl-perl libjson-perl libnagios-plugin-perl
```

If Perl modules doesn't exist in your distribution package manager, you can install manually:

#### Other distributions:

```
perl -MCPAN -e 'install WWW::Curl'
perl -MCPAN -e 'install JSON'
perl -MCPAN -e 'install Nagios::Plugin'  
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

See example file etc\zevenet_commands.cfg


### 7. Add services to Nagios configuration

See example file etc\zavenet_services.cfg
