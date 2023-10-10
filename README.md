## check_hycu_target

Nagios check that use HYCUs REST API to get HYCU target storage usage and status

### prerequisites

This script uses theses libs : 
REST::Client, Data::Dumper, Monitoring::Plugin, MIME::Base64, JSON, LWP::UserAgent, Readonly

to install them type ::

```
sudo cpan REST::Client Data::Dumper Monitoring::Plugin MIME::Base64 JSON LWP::UserAgent Readonly
```

### Use case

```bash
check_hycu_target.pl 1.0.2

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

Nagios check that uses HYCUs REST API to get target status and storage usage

Usage: check_hycu_target.pl -H <hostname> -p <port>  -u <User> -P <password> [-w <threshold> ] [-c <threshold> ]  [-t <timeout>] [-a <apiversion>]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.
 -H, --host=STRING
   Hostname
 -p, --port=INTEGER
  Port Number
 -a, --apiversion=string
  HYCU API version
 -u, --user=string
  User name for api authentication
 -P, --Password=string
  User name for api authentication
 -n, --name=STRING
   target name
 -S, --ssl
   The hycu serveur use ssl
 -w, --warning=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -c, --critical=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 30)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```

sample :

```bash
 check_hycu_target.pl -H MyHYCUserver --ssl -p 8443 -a v1.0 -u user@domain -P Password  -c :90 -w :80
```

```bash
check_hycu_target.pl -H MyHYCUserver --ssl -p 8443 -a v1.0 -u user@domain -P Password  -c :90 -w :80 -n MyStorage
```

```bash
check_hycu_target.pl -H MyHYCUserver --ssl -p 8443 -a v1.0 -u user@domain -P Password  -c :90 -w :80 -n wtf
```

you may get :

```bash
check_hycu_target OK - Targets ARCHIVE_HYCU, MyStorage, MyStorage1, S3-Scaleway are ok  | ARCHIVE_HYCU=12.90%;:80;:90 MyStorage=21.66%;:80;:90 MyStorage1=21.57%;:80;:90 S3-Scaleway=58.27%;:80;:90
```

```bash
check_hycu_target OK - Target MyStorage is ok  | MyStorage=21.65%;:80;:90
```

```bash
check_hycu_target UNKNOWN -  Target not found. Available target(s) are : ARCHIVE_HYCU, MyStorage, MyStorage1, S3-Scaleway
```

