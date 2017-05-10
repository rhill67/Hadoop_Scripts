#!/bin/bash 

# Date:  01/27/2014 
# Auth: Roger K. Hill - DISYS 
# Desc: Baseline information and data collection script for RHEL6 linux 

me=$(uname -n)
shortname=$(hostname -s)
fqdn_name=$(hostname -f)

LOGFILE=$shortname.baseline.$(date "+%m-%d-%Y-%H%M".log)

logit () {
  DATEFMT=$(date "+%m-%d-%Y %H:%M:%S")
  echo "$DATEFMT: $1" | tee -a $LOGFILE 
}

line () { 
  logit "-----------------------------------------------------" 
} 

basehardware() {
  mem=$(free -m|grep Mem|awk '{print $2}')
  rootdiskspace=$(df -ha /|tail -1|awk '{print $3}')
  cpunum=$(cat /proc/cpuinfo|grep processor|wc -l)
  cputype=$(cat /proc/cpuinfo|grep "model name"|tail -1|awk -F: '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
 
  logit "Memory Installed: $mem" 
  logit "Root Disk space: $rootdiskspace" 
  logit "CPU cores: $cpunum" 
  logit "CPU type: $cputype" 
  logit "Filesystem: " 
  line 
  df -ha | tee -a $LOGFILE
}

clear 
logit "*** QA Server Basic system checklist ***"
line 

me=$(uname -n)
mehosts=$(grep $me /etc/hosts|awk '{print $2}') 

basehardware

line
logit "0.) Hostname (uname -n) set to:    $me" 

line
logit "1.) Hostname (/etc/hosts) config file:"
logit 		$mehosts

line 
logit "2.) Network (/etc/sysconfig/network) config file:"
cat /etc/sysconfig/network | tee -a $LOGFILE

line 
logit "3.) DNS (/etc/resolv.conf) config file:"
cat /etc/resolv.conf | tee -a $LOGFILE

line 
logit "4.) Net Interfaces (ifconfig -a):" 
ifconfig -a | tee -a $LOGFILE

line 
logit "5.) Redhat Release (/etc/redhat-release) config file:" 
cat /etc/redhat-release | tee -a $LOGFILE

line 
logit "6.) Routing Table(route -n)" 
route -n | tee -a $LOGFILE

line 
logit "7.) NTP (/etc/ntp.conf) config file:" 
cat /etc/ntp.conf|egrep -v '^$|#' | tee -a $LOGFILE

line 
logit "8.) NTP Step-tickers (/etc/ntp/step-tickers) config file:"
cat /etc/ntp/step-tickers | tee -a $LOGFILE

line
logit "9.) Netstat table current state(netstat -na):"
netstat -na | egrep 'LISTEN|ESTABLISHED' | tee -a $LOGFILE

line
logit "10.) SNMP configuration (cat /etc/snmpd.config):"
cat /etc/snmpd.config | egrep -v '$^|#' | tee -a $LOGFILE

line 
logit "11.) Name service config file (cat /etc/nsswitch.conf):"
cat /etc/nsswitch.conf| egrep -v '$^|#' | tee -a $LOGFILE

line 
MAILDOVECHECK=$(pkg_info | grep dovecot|awk '{print $1}')
if [ "$MAILDOVECHECK" != "" ];then 
  logit "Dovecot package : $MAILDOVECHECK is installed" 
  logit "12.) Dovecot configuration details(cat /usr/local/etc/dovecot.conf):" 
  cat /etc/dovecot/dovecot.conf |  egrep -v '$^|#' | tee -a $LOGFILE
fi 

line 
logit "13.) Finding all crontabs:" 
for i in $(ls /var/spool/cron/)
do 
  logit "Cronbtab $i (cat /var/spool/cron/$i)"
  cat /var/spool/cron/$i | tee -a $LOGFILE
done

line 
logit "14.) User account report (cat /etc/passwd):"
cat /etc/passwd | tee -a $LOGFILE

line 
logit "15.) Group account report (cat /etc/group):" 
cat /etc/group | tee -a $LOGFILE

line 
logit "16.) Kernel paramters and existing kernel state(sysctl -a):" 
sysctl -a | tee -a $LOGFILE

exit 0 
