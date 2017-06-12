# zevenet-nagios-plugins
Nagios plugins for Zevenet Load Balancer

INSTALLATION
============

1. Install dependencies:
------------------------

Debian Jessie:

apt-get update
apt-get install libwww-curl-perl libjson-perl libnagios-plugin-perl


2. Decompress Zevenet Nagios plugins pack:
------------------------------------------

tar xvzf zevenet-nagios-plugins.tar.gz


3. Copy all check scripts to /usr/local/nagios/libexec/:
--------------------------------------------------------

cd xvzf zevenet-nagios-plugins
cp check_zevenet_* /usr/local/nagios/libexec/


4. Create a valid ZAPI v3 key thought Zevenet ADC Load Balancer web interface.
------------------------------------------------------------------------------


5. Test plugin manually:
------------------------

cd /usr/local/nagios/libexec/
perl check_zevenet_cpu.pl -H <zevenet_appliance_ip_address> -z <your_zapi_v3_key> -w 20 -c 10

Example output:

ZEVENET_CPU CRITICAL - Zevenet ADC Load Balancer CPU usage is 40 % (Idle 60 %) | Idle=60%;20;10 IOWait=0%;; IRQ=0%;; Nice=0%;; SoftIRQ=0%;; Sys=8%;; Usage=40%;; User=32%;; Total=100%;;


6. Add commands definition to Nagios configuration.
---------------------------------------------------

See example file etc\zevenet_commands.cfg


7. Add services to Nagios configuration.
----------------------------------------

See example file etc\zavenet_services.cfg
