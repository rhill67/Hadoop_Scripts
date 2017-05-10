#!/bin/bash 

# DATE : 02/04/2014
# AUTH : rhill 314-884-2054 
# DESC : HW HDP 2.2 Pre-install_script.sh to prep server os before installation attempt for HDP 
# Reference URL : http://docs.hortonworks.com/HDPDocuments/Ambari-1.7.0.0/Ambari_Install_v170/Ambari_Install_v170.pdf 

PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
COUNTER=0
ME=$(basename $0)
SCRIPT_VER="2.4"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
REPTFILE="$HOME/$ME.$DDMMYY.rpt"
SHORTHOST=$(uname -n|awk -F. '{print $1}') 
FQDN=$(uname -n) 
OSTYPE=$(cat /etc/redhat-release|awk '{print $1" "$2}')
CENTOS_CHK=$(grep -i centos /etc/redhat-release)
if [ "$CENTOS_CHK" == "" ];then
  OSVER=$(cat /etc/redhat-release |awk '{print $7}')
else
  OSVER=$(cat /etc/redhat-release |awk '{print $3}')
fi
KERNEL=$(uname -r)
MAILRCPT="roger.hill2@unisys.com"
RHVER=$(cat /etc/redhat-release|awk '{print $7}'|awk -F. '{print $1}')

# set global variables for standard [ OK ], [ ERROR ], [ NOTED ] messages ... 
myWARN="[ WARN ]"
myGO="[ OK ]" 
myINFO="Informational Text Debug" 
myNOTE="[ NOTED ]" 

### begin core functions ... 

redwarn() { 
  # expect only 1 parameter ... 
  myTxt=$1 
  myWARN=$(echo -e "\e[31m$myTxt\e[0m") 
} 

greengo(){ 
  # expect only 1 parameter ...
  myTxt=$1
  myGO=$(echo -e "\e[32m$myTxt\e[0m")
}

blueinfo() {
  # expect only 1 parameter ...
  myTxt=$1
  myINFO=$(echo -e "\e[36m$myTxt\e[0m")
}

yellownote() { 
  # expect only 1 parameter ...
  myTxt=$1
  myNOTE=$(echo -e "\e[33m$myTxt\e[0m")
}

logit() {
  DATEFMT=$(date "+%b %d %H:%M:%S $SHORTHOST")
  # DATEFMT=$(date "+%c")
  if [ "$2" == "prompt" ];then 
    echo -n "$DATEFMT : $1" | tee -a $LOGFILE
  else 
    echo "$DATEFMT : $1" | tee -a $LOGFILE
  fi 
}

smallLine() { 
  logit "--------------------"
}

longline() { 
  logit "------------------------------------------------------------" 
}

starline(){ 
  logit "***************************************"
}

hdr() {
  logit "*** Start script run for \"$ME\" on $DDMMYY2 ***"
  logit "OS     : $OSTYPE"
  logit "Ver    : $OSVER"
  logit "Kernel : $KERNEL"
  logit "Script Ver : $SCRIPT_VER"
  if [ "$NUMPARAMETERS" == "3" ];then
    logit "Parameters(3) : \"$PARONE\" \"$PARTWO\" \"$PARTHREE\" "
  elif [ "$NUMPARAMETERS" == "2" ];then
    logit "Parameters(2) : \"$PARONE\" \"$PARTWO\" "
  elif [ "$NUMPARAMETERS" == "1" ];then
    logit "Parameters(2) : \"$PARONE\" "
  fi
  longline 
}

ftr() {
  longline
  logit "*** End script run for  \"$ME\" on $DDMMYY2 ***"
}

help() {

  starline 
  logit "*** $ME HELP Menu ***"
  logit "Run this script with either one of two parameters:"
  logit ""
  logit "Example :"
  logit ""
  logit "   ./$ME show"
  logit "   ./$ME change"
  logit ""
  logit "*** $ME HELP Menu ***"
  starline
  longline

}

### Begin local functions to be run in mainline logic ...
CTR=1
greengo "$myGO"
redwarn "$myWARN" 
yellownote "$myNOTE" 

backUpConfigFile(){
  ## $1 is the fullpath of the file to be backed up
  DATEFMT2=$(date '+%m-%d-%y.%H%M')

  if [ ! -e $1.$DATEFMT2.bak ];then
    logit "Creating a backup copy of \"$1\" file to $1.$DATEFMT2.bak"
    /bin/cp -f -p $1 $1.$DATEFMT2.bak
  else
    logit "No new backup file was needed, file \"$1.bak\" exists $myGO"
  fi
}

showSysMisc(){
  ## $1 is the switch passed to ulimit(i.e. "-c")
  if [ "$1" == "-t" ];then 
    ULIMITDESC=$(ulimit -a|grep \\"$1"|tail -1|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITDESC2=$(ulimit -a|grep \\"$1"|tail -1|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITVAL=$(ulimit -a|grep \\"$1"|tail -1|awk -F")" '{print $2}'|tr -d ' ')
    logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" "
  else 
    ULIMITDESC=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITDESC2=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITVAL=$(ulimit -a|grep \\"$1"|awk -F")" '{print $2}'|tr -d ' ')
    if [ "$1" == "-n" ];then
      if (( $ULIMITVAL >= 32768 ));then 
        logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" $myGO" 
      else 
        logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" $myWARN optimal value is \"32768\" " 
        if [ "$PARONE" == "change" ];then
	  CHKLIMITSFILE=$(grep nofile /etc/security/limits.conf|grep -v "#"|tail -1) 
	  if [ "$CHKLIMITSFILE" != "" ];then 
	    logit "Hadoop system setting \"ulimit -n\" not set in current shell, but already set in /etc/security/limits.conf $myGO" 
	  else 
            logit "Hadoop system setting \"ulimit -n\" set to \"32768\" continue [ y / n ] " "prompt"
            read ans
            if [ "$ans" == "y" -o "$ans" == "Y" ];then
              logit "Setting the \"ulimit -n\" to \"32768\" in file /etc/security/limits.conf $myGo"
	      backUpConfigFile /etc/security/limits.conf 
              echo "*         -       nofile  32768" >> /etc/security/limits.conf
            fi
	  fi 
        fi
      fi 
    elif [ "$1" == "-u" ];then
      if (( $ULIMITVAL >= 65536 ));then
        logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" $myGO"
      else
        logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" $myWARN optimal value is \"65536\" "
        if [ "$PARONE" == "change" ];then
          CHKLIMITSFILE=$(grep nproc /etc/security/limits.conf|grep -v "#"|tail -1)
          if [ "$CHKLIMITSFILE" != "" ];then
            logit "Hadoop system setting \"ulimit -u\" not set in current shell, but already set in /etc/security/limits.conf $myGO"
          else
            logit "Hadoop system setting \"ulimit -u\" set to \"65536\" continue [ y / n ] " "prompt"
            read ans
            if [ "$ans" == "y" -o "$ans" == "Y" ];then
              logit "Setting the \"ulimit -u\" to \"65536\" in file /etc/security/limits.conf $myGo"
              backUpConfigFile /etc/security/limits.conf 
              echo "*         -       nproc  65536" >> /etc/security/limits.conf
            fi
          fi
        fi
      fi
    else 
      logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" "
    fi 
  fi 
}

chkSwappiness() { 
  SWAPPINESS_CHK=$(sysctl -a|grep vm.swappiness | awk -F= '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
  if (( $SWAPPINESS_CHK <= 0 ));then 
    logit "Kernel tuning variable to control swap \"vm.swappiness\" is set to \"$SWAPPINESS_CHK\" $myGO" 
  else 
    logit "Kernel tuning variable to control swap \"vm.swappiness\" is set to \"$SWAPPINESS_CHK\" $myWARN" 
    if [ "$PARONE" == "change" ];then
      logit "Kernel tuning variable to control swap \"vm.swappiness\" about to be set to \"0\" continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        logit "Setting kernel tuning variable \"vm.swappiness\" to \"0\" $myGO" 
        backUpConfigFile /etc/sysctl.conf  
 	sysctl -w vm.swappiness=0 
	echo "vm.swappiness = 0" >> /etc/sysctl.conf 
	echo "# Change made by $ME on $DDMMYY" >> /etc/sysctl.conf
      fi
    fi
  fi 
}

chkTransparentHugePages() { 
  # TRANSHUGE_CHK=$(sysctl -a|grep vm.nr_hugepages|grep -v policy|awk -F= '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
  TRANSHUGE_CHK=$(cat /sys/kernel/mm/transparent_hugepage/enabled|grep "\[never\]"|sed -e 's/^ *//g' -e 's/ *$//g')
  if [ "$TRANSHUGE_CHK" != "" ];then
    logit "Kernel tuning variable to control transparent huge pages \"vm.nr_hugepages\" is set to \"$TRANSHUGE_CHK\" $myGO"
  else
    logit "Kernel tuning variable to control transparent huge pages \"vm.nr_hugepages\" is set to \"$TRANSHUGE_CHK\" $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Kernel tuning variable to control transparent huge \"vm.nr_hugepages\" about to be set to \"0\" continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        logit "Setting kernel tuning variable \"vm.nr_hugepages\" to \"0\" $myGO"
        backUpConfigFile /etc/sysctl.conf
        sysctl -w vm.nr_hugepages=0
	## change now in the running kernel ... 
	echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag
	echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
	CHK_RCLOCAL=$(grep transparent /etc/rc.local)
	if [ "$CHK_RCLOCAL" != "" ];then 
	  logit "The \"transparent_hugepage\" is already being disabled by the /etc/rc.local script [ OK ]" 
	else 
	  logit "The \"transparent_hugepage\" will be disable in the /etc/rc.local script [ OK ]"
	  echo "echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag" >> /etc/rc.local 
	  echo "echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled" >> /etc/rc.local 
	fi 
        echo "vm.swappiness = 0" >> /etc/sysctl.conf
        echo "# Change made by $ME on $DDMMYY" >> /etc/sysctl.conf
      fi
    fi
  fi
} 

chkRPMS() { 

  YUMCK=$(rpm -qa|grep yum-3)
  if [ "$YUMCK" != "" ];then 
    logit "Pkg \"$YUMCK\" installed $myGO"
  else 
    logit "Pkg \"yum-3*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Cannot automatically install \"yum\" without \"yum\" ! Manually check yum repos for problems $myWARN"  
    fi
  fi 

  RPMCK=$(rpm -qa|grep rpm-4)
  if [ "$RPMCK" != "" ];then
    logit "Pkg \"$RPMCK\" installed $myGO"
  else
    logit "Pkg \"rpm-4*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"rpm\" missing, install \"rpm\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
	yum install rpm-4* -y 
      fi
    fi
  fi

  SCPCK=$(rpm -qa|grep openssh-clients-5)
  if [ "$SCPCK" != "" ];then
    # greengo "$myGO"
    logit "Pkg \"$SCPCK\" installed $myGO"
  else
    logit "Pkg \"openssh-clients-5*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"openssh-clients\" missing, install \"openssh-clients\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install openssh-clients-5* -y
      fi
    fi
  fi

  CURLCK=$(rpm -qa|grep curl-7|egrep -v 'python|libcurl')
  if [ "$CURLCK" != "" ];then
    logit "Pkg \"$CURLCK\" installed $myGO"
  else
    logit "Pkg \"curl-7*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"curl-7*\" missing, install \"curl-7*\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install curl-7* -y
      fi
    fi
  fi
 
  WGETCK=$(rpm -qa|grep wget)
  if [ "$WGETCK" != "" ];then
    logit "Pkg \"$WGETCK\" installed $myGO"
  else
    logit "Pkg \"wget*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"wget\" missing, install \"wget\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install wget -y
      fi
    fi
  fi

  UNZIPCK=$(rpm -qa|grep unzip)
  if [ "$UNZIPCK" != "" ];then
    logit "Pkg \"$UNZIPCK\" installed $myGO"
  else
    logit "Pkg \"$UNZIPCK\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"unzip\" missing, install \"unzip\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install unzip -y
      fi
    fi
  fi

  TARCK=$(rpm -qa|grep tar-1|grep -v libtar)
  if [ "$TARCK" != "" ];then
    logit "Pkg \"$TARCK\" installed $myGO"
  else
    logit "Pkg \"tar-1*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"tar\" missing, install \"tar\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install tar -y
      fi
    fi
  fi

  BINUTILSCK=$(rpm -qa|grep bind-utils) 
  if [ "$BINUTILSCK" != "" ];then
    logit "Pkg \"$BINUTILSCK\" installed $myGO"
  else
    logit "Pkg \"bind-utils*\" NOT installed $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"bind-utils\" missing, install \"bind-utils\" now ? continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        yum install bind-utils -y
      fi
    fi
  fi

}

chkDiskspace () { 
  DISKTHRESH="25"

  logit "Storage configuration:" 
  for dir in / /usr /var /boot 
  do 
    DISKTOT=$(df -Ph $dir|tail -1|awk '{print $2}'|tr -d ' ')
    DISKFREEPER=$(df -Ph $dir|tail -1|awk '{print $4}'|tr -d ' ')
    DISKAVAIL=$(df -Ph $dir|tail -1|awk '{print $3}'|tr -d ' ')
    logit "Directory \"$dir\" has \"$DISKTOT\" total diskspace and \"$DISKFREEPER\" free $myNOTE"

    DISK_MB_GB_CHK=$(echo $DISKTOT|grep G)
    if [ "$DISK_MB_GB_CHK" != "" ];then 
      ## we have a 'G' value 
      DISKUSED=$(echo $DISKTOT|awk -FG '{print $1}'|cut -d. -f1) 
    else 
      ## we have a 'M' value 
      DISKUSED=$(echo $DISKTOT|awk -FM '{print $1}'|cut -d. -f1) 
    fi 

    if [ "$dir" == "/boot" ];then 
      logit "Diskspace found in \"$dir\" has \"$DISKFREEPER\" and \"$DISKAVAIL\" available $myNOTE" 
    else 
      if [ "$DISKUSED" -ge "$DISKTHRESH" ];then 
        logit "Sufficient Diskspace found in \"$dir\" directory is more than required threshold \"$DISKTHRESH G\" $myGO"
      else 
        logit "Insufficient Diskspace available \"$DISKFREEPER\", \"$DISKAVAIL\" in \"$dir\" , need \"$DISKTHRESH\" GB directory $myWARN"
      fi 
    fi 
  done 
}

chkDiskAccessTime() { 
  logit "Storage linux block device configuration:" 
  IFS=$'\n' 
  logit "** Note : shared mem, root, boot, devpts, proc, root and swap devices are not being checked" 
  for dev in $(cat /etc/fstab|egrep -v "#|sysfs|shm|devpts|proc|root|swap|boot")
  do 
    if [ "$dev" != "" ];then 
      MYDEV=$(echo $dev|awk '{print $1}')
      MY_FS=$(echo $dev|awk '{print $2}')
      MY_MNT_DIR=$(echo $dev|awk '{print $2}' |awk -F/ '{print $2}')
      DEV_OPTIONS=$(echo $dev|awk '{print $4}') 
      DEV_OPTS_CHK=$(echo $DEV_OPTIONS|grep noatime)
      if [ "$DEV_OPTS_CHK" != "" ];then  
        logit "Device : $MYDEV with options \"$DEV_OPTIONS\" for filesystem \"$MY_FS\" $myGO" 
      else 
        logit "Device : $MYDEV with options \"$DEV_OPTIONS\" for filesystem \"$MY_FS\" $myWARN missing the \"noatime\" attribute" 
        if [ "$PARONE" == "change" ];then
          logit "Only hadoop HDFS volumes need configuration with \"noatime\", set device $MYDEV continue [ y / n ] " "prompt"
          read ans
          if [ "$ans" == "y" -o "$ans" == "Y" ];then
	    backUpConfigFile "/etc/fstab" 
	    if [ "$MY_MNT_DIR" != "" ];then 
              logit "Setting the \"noatime\" to on block device $MYDEV for mount point /$MY_MNT_DIR within /etc/fstab file $myGo" 
	      sed -i '/'"$MY_MNT_DIR"'/ s/defaults/defaults,noatime/' /etc/fstab 
	      /bin/mount -o remount,defaults,noatime /$MY_MNT_DIR
	    fi 
          fi
        fi
      fi 
    fi 
  done 
  IFS=$OLD_IFS
}

chkDevResSpace() { 
  logit "Storage linux block device reserved root space:" 
  IFS=$'\n'
  logit "** Note : shared mem, root, boot, devpts, proc, root and swap devices are not being checked" 
  for dev in $(cat /etc/fstab|egrep -v "#|sysfs|shm|devpts|proc|root|boot|swap|^$")
  do
    if [ "$dev" != "" ];then
      MYDEV=$(echo $dev|awk '{print $1}')
      MY_FS=$(echo $dev|awk '{print $2}')
      DEV_UUID_CHK=$(echo $dev|grep -i UUID)
      if [ "$DEV_UUID_CHK" != "" ];then 
 	DEV_UUID=$(echo $DEV_UUID_CHK|awk -FUUID= '{print $2}'|awk '{print $1'}) 
 	MYBLK_DEV=$(blkid | grep $DEV_UUID|awk -F: '{print $1}') 
	MYDEV=$MYBLK_DEV
	logit "Found mounted device \"$MYBLK_DEV\" with UUID \"$DEV_UUID\" for filesystem \"$MY_FS\" " 
      fi 
      BLOCK_COUNT_CHK=$(tune2fs -l $MYDEV|grep 'block count'|awk -F: '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
      if [ "$BLOCK_COUNT_CHK" != "" ];then
        if [ "$BLOCK_COUNT_CHK" != "0" ];then # check if already 0 ... 
          logit "Device : $MYDEV with  \"$BLOCK_COUNT_CHK\" for filesystem \"$MY_FS\" $myWARN optimal value 0"
	  ### modify 
	  if [ "$PARONE" == "change" ];then 
	    logit "Only hadoop HDFS volumes need \"reserved root space\" set to 0% on block device $MYDEV continue [ y / n ] " "prompt"
	    read ans 
	    if [ "$ans" == "y" -o "$ans" == "Y" ];then 
	        logit "Setting the \"reserved root space\" to 0% on block device $MYDEV $myGo" 
	        tune2fs -m 0 $MYDEV
	    fi  
 	  fi 
        else 
          logit "Device : $MYDEV ALREADY with  \"$BLOCK_COUNT_CHK\" for filesystem \"$MY_FS\" $myGO"
	fi 
      else
        logit "Device : $MYDEV with \"$BLOCK_COUNT_CHK\" for filesystem \"$MY_FS\" $myWARN optimal value 0"
      fi
    fi
  done
  IFS=$OLD_IFS
} 

chkMemory () {
  TOTALMEMORY=$(cat /proc/meminfo | grep MemTotal|awk '{print $2}')
  MEMTHRESH="8388608"  # 4 GB in kB
  logit "Memory configuration:" 
  if [ "$TOTALMEMORY" -ge "$MEMTHRESH" ];then
    logit "Memory Installed \"$TOTALMEMORY\" kB greater than Mem Threshold \"$MEMTHRESH\" kB $myGO"
  else
    redwarn "$myWARN" 
    logit "Memory Installed \"$TOTALMEMORY\" kB less than Mem Threshold \"$MEMTHRESH\" kB $myWARN"
  fi
}

chkCPUcores () { 
  CPUCORE_THRESH="2" 
  logit "CPU configuration:" 
  TOTALCPU=$(cat /proc/cpuinfo | grep processor|wc -l)
  CPUMODEL=$(cat /proc/cpuinfo|grep 'model name'|tail -1|awk -F: '{print $2}')

  if (( "$TOTALCPU" >= "$CPUCORE_THRESH" ));then 
    logit "CPU's Installed \"$TOTALCPU\" , model \"$CPUMODEL\" are greater than CPU Threshold \"$CPUCORE_THRESH\" $myGO" 
  else 
    logit "CPU's Installed \"$TOTALCPU\" , model \"$CPUMODEL\" are less than CPU Threshold \"$CPUCORE_THRESH\" $myWARN" 
  fi 
}

chkNETinterface (){
  BONDIFACE=$(ls /etc/sysconfig/network-scripts/|grep bond|grep ifcfg|awk -F- '{print $2}')
  logit "Network Interface configuration:" 
  if [ "$BONDIFACE" != "" ];then 
    # we are not using nic bonding ...
    ### ETH0IPADDR=$(/sbin/ifconfig eth0 | grep inet | grep -v inet6 | awk -F: '{print $2}' | awk '{print $1}')
    ### logit "Using eth0 \"$ETH0IPADDR\" detected interface IP addr $myGO" 
    # ensure we get an ip address and not an empty line ... 
  ### else 
    # we are using nic bonding, get primary ip interface from there 
    BONDIPADDR=$(ip addr show $BONDIFACE|grep inet|awk '{print $2}'|awk -F\/ '{print $1}')
    logit "Using bond0 \"$BONDIFACE\" detected interface IP addr $myGO" 
    ETH0IPADDR=$BONDIPADDR
  fi 
 
  # for eth in $(ip link show|egrep -iv 'loopback|ether'|grep eth|awk '{print $2}'|awk -F: '{print $1}')
  for eth in $(ip addr show|grep UP|grep -v lo|awk '{print $2}'|awk -F: '{print $1}') 
  do 
    MTU_HADOOP=1500
    NICSPEED=$(ethtool $eth|grep Speed|awk '{print $2}')
    NICDUPLX=$(ethtool $eth|grep Duplex|awk '{print $1 $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
    # NICTXERR=$(ethtool -S $eth|grep "pkts tx err:"|awk '{print $4}')
    NICTXERR=$(ethtool -S $eth|grep tx_err|awk '{print $2}')
    # NICRXERR=$(ethtool -S $eth|grep "pkts rx err:"|awk '{print $4}')
    NICRXERR=$(ethtool -S $eth|grep rx_err|awk '{print $2}')
    logit "NIC \"$eth\" configured with speed : \"$NICSPEED\", and \"$NICDUPLX\""
    logit "NIC \"$eth\" err check : transmitt errors = \"$NICTXERR\", receive errors = \"$NICRXERR\""
    MTUVAL=$(/sbin/ifconfig $eth|grep -i mtu | awk -FMTU '{print $2}'| awk '{print $1}' |awk -F: '{print $2}') 
    if (( $MTUVAL >=  $MTU_HADOOP ));then  
      logit "NIC \"$eth\" MTU configured value : \"$MTUVAL\" $myGO" 
    else 
      logit "NIC \"$eth\" MTU configured value : \"$MTUVAL\" $myWARN optimal value is \"$MTU_HADOOP\" for ethernet " 
      if [ "$PARONE" == "change" ];then
        logit "NIC \"$eth\" MTU configured value : \"$MTUVAL\", about to set MTU=$MTU_HADOOP, continue [ y / n ] " "prompt"
        read ans
        if [ "$ans" == "y" -o "$ans" == "Y" ];then
          logit "Setting the NIC \"$eth\" MTU value to 1500 $myGO" 
          echo "MTU=$MTU_HADOOP" >> /etc/sysconfig/network-scripts/ifcfg-$eth  
        fi
      fi      
    fi 
  done   

}

chkOS() { 
  CHK_LSB=$(which lsb_release 2>&1 > /dev/null;echo $?)
  if [ "$CHK_LSB" == "0" ];then 
    myOS=$(lsb_release -a | grep Description | awk -F: '{print $2}'|sed -e 's/^[ \t]*//')
  else 
    myOS=$(cat /etc/redhat-release|awk '{print $1" "$2}'|sed -e 's/^[ \t]*//')
  fi 

  test -f /etc/redhat-release && REDHAT_CHK=$(cat /etc/redhat-release|awk '{print $1" "$2}');CENTOS_CHK=$(grep -i centos /etc/redhat-release)
  test -f /etc/SuSE-release && SUSE_CHK=$(cat /etc/SuSE-release) 

  if [ "$CENTOS_CHK" == "" ];then
    OSVER=$(cat /etc/redhat-release |awk '{print $7}')
  else
    OSVER=$(cat /etc/redhat-release |awk '{print $3}')
  fi
  logit "Operating System : $myOS $OSVER $myGO" 
}

chkExistingDB() { 
  PGA_CHK=$(rpm -qa | grep -i postgres | grep server)
  ORA_CHK=$(rpm -qa | grep -i oracle | grep server)
  MYS_CHK=$(rpm -qa | grep mysql | grep server)

  if [ "$PGA_CHK" != "" ];then 
    logit "PostgreSQL database pre-installed ($PGA_CHK) extra configuration may be needed $myWARN"
  else 
    logit "PostgreSQL database not fouund $myGO"  
  fi 

  if [ "$ORA_CHK" != "" ];then
    logit "Oracle database pre-installed ($ORA_CHK) extra configuration may be needed $myWARN"
  else
    logit "Oracle database not fouund $myGO"
  fi

  if [ "$MYS_CHK" != "" ];then
    logit "MySQL database pre-installed ($MYS_CHK) extra configuration may be needed $myWARN"
  else
    logit "MySQL database not fouund $myGO"
  fi
} 

chkJDK() { 
  WHICHJAVA=$(which java 2>/dev/null)

  if [ "$?" != "0" ];then
    logit "Java JDK not installed ! $myWARN"
    exit 2 
  fi 

  JAVAMAJ_VER=$($WHICHJAVA -version 2>&1>/dev/null|head -1|awk -F\" '{print $2}'|awk -F. '{print $2}') 
  JAVAVER=$($WHICHJAVA -version 2>&1>/dev/null|head -1)
  JAVAJDKENV=$($WHICHJAVA -version 2>&1>/dev/null|head -2|tail -1)
  JAVAJDKARCH=$($WHICHJAVA -version 2>&1>/dev/null|head -3|tail -1)

  JAVA6VER_MIN=31 
  JAVA7VER_MIN=51 

  if [ "$JAVAMAJ_VER" == "6" ];then 
    JAVAVER_CHK=$(echo $JAVAVER | awk -F\" '{print $2}'|awk -F. '{print $3}' | awk -F_ '{print $2}')
    if [ "$JAVAVER_CHK" -ge "$JAVA6VER_MIN" ];then 
      logit "Version : $JAVAVER $myGO"
    else 
      logit "Version : $JAVAVER below minimal required version 1.6.0_$JAVA6VER_MIN for HDP 2.2 $myWARN"
    fi 
  elif [ "$JAVAMAJ_VER" == "7" ];then
    JAVAVER_CHK=$(echo $JAVAVER | awk -F\" '{print $2}'|awk -F. '{print $3}' | awk -F_ '{print $2}')
    if [ "$JAVAVER_CHK" -ge "$JAVA7VER_MIN" ];then
      logit "Version : $JAVAVER $myGO"
    else
      logit "Version : $JAVAVER below minimal required version 1.7.0_$JAVA7VER_MIN for HDP 2.2 $myWARN"
    fi
  fi 

  logit "JDK Build Details : $JAVAJDKENV"

  JAVAJDKARCH_CHK=$(echo $JAVAJDKARCH | grep 64) 
  if [ "$JAVAJDKARCH_CHK" != "" ];then 
    logit "JDK Arch Details : $JAVAJDKARCH $myGO"
  else 
    logit "JDK Arch Details : $JAVAJDKARCH $myWARN 64 bit JDK not detected"
  fi 
}

chkRemoteRepos() { 
  if [ -f /etc/yum.repos.d/hdp.repo -o -f /etc/yum.repos.d/HDP.repo ];then  
    logit "The \"/etc/yum.repos.d/hdp.repo\" file exists $myGO"
  else  logit "The \"/etc/yum.repos.d/hdp.repo\" file is missing $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Manually check all repos config listed below ..."  
      IFS=$'\n'
      for repo in $(grep -i enabled /etc/yum.repos.d/*.repo |sort -u)
      do
        logit "$repo" 
      done
      IFS=$OLD_IFS
    fi 
  fi 
}

chkFQDNhost() {
  CKFQDN=$(hostname -f) 
  DOTS=$(echo $CKFQDN|grep "." |awk -F. '{print NF}') 
  if [ "$DOTS" -ge "3" ];then 
    logit "Server FQDN \"$CKFQDN\" set correctly $myGO"
  else 
    logit "Server FQDN \"$CKFQDN\" NOT set correctly $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Use the \"hostname\" command to set the \"FQDN\" of the server correctly $myWARN" 
    fi 
  fi 
} 

chkNTPconfig() { 
  logit "Checking NTP config - 1.5.1. Enable NTP on the Cluster" 
  NTPLOCALIP="server"
  NTPCK=$(grep "$NTPLOCALIP" /etc/ntp.conf|wc -l)
  NTPQCHK=$(/usr/sbin/ntpq -p >/dev/null 2>&1;echo $?) 
  if [ "$NTPCK" -ge "2" -a "$NTPQCHK" -eq "0" ];then 
    logit "NTP Config check $myGO" 
  else 
    logit "NTP Config check $myWARN" 
    if [ "$PARONE" == "change" ];then
      logit "Manually set the \"server\" variable within /etc/ntp.conf correctly to a local ip or centos or redhat ntp source $myWARN"
      IFS=$'\n'
      for ntp_server in $(grep -i server /etc/ntp.conf|egrep -v "$^|#")
      do
        logit "$ntp_server"
      done
      IFS=$OLD_IFS
      service ntpd start
      chkconfig ntpd on
      logit "Turning on NTP and adding into start-up config $myGO"
    fi
  fi
}

chkDNSconfig() {
  logit "Checking DNS config - 1.5.2. Check DNS"
  #DNSLOCALIP="10.12.132"
  #DNSCK=$(grep $DNSLOCALIP /etc/resolv.conf|wc -l)
  #if [ "$DNSCK" -ge "2" ];then
  DNSHOSTCHK=$(host -W 2 unisys.com 2>&1>/dev/null ; echo $?)
  if [ "$DNSHOSTCHK" -eq "0" ];then
    logit "DNS Config check $myGO"
  else
    logit "DNS Config check $myWARN"
    DNSSERVERCHK=$(cat /etc/resolv.conf|grep server|grep -v "#")
    if [ "$DNSSERVERCHK" != "" ];then 
      logit "DNS Resolver in /etc/resolv.conf : $DNSSERVERCHK" 
    else 
      if [ "$PARONE" == "change" ];then
        logit "Hadoop config \"DNS\" needs setup, continue [ y / n ] " "prompt"
        read ans
        if [ "$ans" == "y" -o "$ans" == "Y" ];then
	  logit "Enter the IP address for DNS Server:" "prompt"
	  read dnsip 
          logit "Setting the \"/etc/resolv.conf\" to \"nameserver $dnsip\" now $myGo"
	  backUpConfigFile /etc/resolv.conf 
          echo "nameserver $dnsip" >> /etc/resolv.conf
	else 
	  logit "Set \"/etc/resolv.conf\" name servers to use googles DNS Servers [ y / n ] " "prompt"
	  read googledns
	  if [ "$googledns" == "y" -o "$googledns" == "Y" ];then 
	    logit "Setting the \"/etc/resolv.conf\" to googles nameservers now $myGo"
	    backUpConfigFile /etc/resolv.conf 
	    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
	    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	  fi 
        fi
      fi
    fi 
  fi
  IFS=$'\n'
  for dns_server in $(cat /etc/resolv.conf|grep server|grep -v "#")
  do 
    logit "DNS Resolver in /etc/resolv.conf : $dns_server" 
  done 
  IFS=$OLD_IFS

  logit "Checking the nscd daemon configuration" 
  NSCD_CHK=$(/sbin/chkconfig --list nscd 2>&1) 
  if [ "$(echo $NSCD_CHK|grep error)" != "" ];then 
    logit "The nscd daemon software is not installed $myWARN" 

    if [ "$PARONE" == "change" ];then
      logit "Hadoop pkg \"nscd\" and service required, installation continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
	logit "Installing the \"nscd\" pkg and configuring $myGo"
	backUpConfigFile /etc/resolv.conf 
        yum install nscd -y 
	/sbin/chkconfig nscd on 
	service nscd start 
      fi
    fi 
  elif [ "$(echo $NSCD_CHK|grep on)" != "" ];then 
    logit "The nscd daemon is installed and configured $myGO" 
  else 
    logit "The nscd daemon is installed but not configured $myWARN" 
    if [ "$PARONE" == "change" ];then
      logit "The nscd daemon is installed but not configured configure now, continue [ y / n ] " "prompt" 
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        logit "Configuring the \"nscd\" pkg and configuring $myGo"
        /sbin/chkconfig nscd on
        service nscd start
      fi 
    fi 
  fi  
}

chkPROXYconfig() {
  HTTPPROXYCHK=$(env 2>&1|grep http_proxy)
  if [ "$HTTPPROXYCHK" != "" ];then
    logit "Proxy set successfully to \"$HTTPPROXYCHK\" $myGO"
  else
    logit "Proxy NOT set successfully $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "Hadoop proxy \"http_proxy\" not set or on, continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        logit "Enter proxy \"http\" or \"https\" protocol:" "prompt" 
	read ans2
	logit "Enter proxy \"address\" or \"ip\" address:" "prompt"
 	read ans3 
	logit "Enter proxy \"port\" number:" "prompt"
	read ans4 
	myPROXY="http_proxy="$ans2"://"$ans3":"$ans4

  	backUpConfigFile /root/.bash_profile 
   	echo "export $myPROXY" >> /root/.bash_profile
	logit "Adding httpd_proxy to current root shell and \"/root/.bash_profile\" $myGO"
	export $ADDPROXY
	
	YUMPROXYCHK=$(grep proxy /etc/yum.conf|grep -v "#")
	if [ "$YUMPROXYCHK" != "" ];then
	  logit "Proxy already set in \"/etc/yum.conf\" file $myGO"
	else
	  backUpConfigFile /etc/yum.conf
	  echo "$myPROXY" >> /etc/yum.conf
	  logit "Adding \"$ADDPROXY\" to file \"/etc/yum.conf\" $myGO"
	fi
      fi
    fi 
  fi
}

chkSELINUXcfg() { 
  logit "Checking SELinux - 1.5.3. Disable SELinux" 
  SECHK=$(getenforce)
  if [ "$SECHK" == "Disabled" ];then
    logit "SELinux is Disabled $myGO" 
  else 
    logit "SELinux is NOT Disabled, current mode \"$SECHK\" $myWARN" 
    if [ "$PARONE" == "change" ];then
      logit "Hadoop security \"SELinux\" set to \"$SECHK\", disabling now, continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
        logit "Setting the \"SELinux\" security config to \"Disabled\" $myGo Reboot required !"
	backUpConfigFile /etc/sysconfig/selinux
	backUpConfigFile /etc/selinux/config	
	sed -i '/SELINUX=enforcing/ s/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
	sed -i '/SELINUX=permissive/ s/SELINUX=permissive/SELINUX=disabled/' /etc/sysconfig/selinux
 	sed -i '/SELINUX=enforcing/ s/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
 	sed -i '/SELINUX=permissive/ s/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
	## echo 0 >/selinux/enforce	# Permissive only
	## /usr/sbin/setenforce 0 	# Permissive only 
      fi
    fi
  fi 

}

chkSSHconn() { 

  logit "From this server, checking SSH connections to specified remote hosts"
  HOSTS="hw02.savvis.lab hw03.savvis.lab hw04.savvis.lab hw05.savvis.lab"

  for host in $HOSTS
  do 
    SSHCK=$(ssh root@$host date 2>&1> /dev/null|tail -1;echo $?)
    if [ $SSHCK -eq 0 ];then
      logit "SSH connection to host \"$host\" $myGO"
    else 
      logit "SSH connection to host \"$host\" $myWARN"
    fi 
  done 

}

chkFWconfig() { 
  logit "Checking Linux firewall - 1.5.4. Disable IPTables" 
  FWCHK=$(/etc/init.d/iptables status|grep -i "Firewall is not running")
  FW_CFG_CHK=$(chkconfig --list iptables |grep -i "on")
  if [ "$FWCHK" != "" -a "$FW_CFG_CHK" == "" ];then 
    logit "Iptables has been disabled $myGO"
  else 
    logit "Iptables has been NOT disabled $myWARN"
    if [ "$PARONE" == "change" ];then
      logit "About to disable and turn off iptables (linux firewall), continue [ y / n ] " "prompt"
      read ans
      if [ "$ans" == "y" -o "$ans" == "Y" ];then
  	FWCHK=$(/etc/init.d/iptables status |grep "not running")
  	if [ "$FWCHK" == "" ];then
    	  /etc/init.d/iptables stop
    	  logit "The firewalls service is now stopped $myGO"
  	else
    	  logit "The firewalls service is already stopped $myGO"
  	fi

  	FWCFGCHK=$(chkconfig --list|grep iptables|awk -F'3:' '{print $2}'|awk '{print $1}')
  	if [ "$FWCFGCHK" != "off" ];then
    	  chkconfig iptables off
    	  logit "The firewalls service is now unconfigured $myGO"
  	else
    	  logit "The firewalls service is already configured off $myGO"
  	fi
  	logit "Turned off firewalls, and removed from start-up config $myGO"
      fi 
    fi
  fi
}

chkUmaskInBashRCfile() { 

  #UMASKCHK1=$(grep umask /etc/bashrc|grep -v "#"|head -1|awk '{print $2}'|tr -d ' ')
  UMASKCHK2=$(grep umask /etc/bashrc|grep -v "#"|tail -1|awk '{print $2}'|tr -d ' ')
  if [ "$UMASKCHK2" == "0022" -o "$UMASKCHK2" == "022" ];then
    logit "Umask creation setting in /etc/bashrc of \"$UMASKCHK1\" and \"$UMASKCHK2\" is correct $myGO"
  else
    logit "Umask creation \"$UMASKCHK1\" and \"$UMASKCHK2\" setting in /etc/bashrc incorrect ! $myWARN"
  fi

  UMASKCURRENT=$(umask)
  if [ "$UMASKCURRENT" == "0022" ];then
    logit "Umask current setting in this shell of \"$UMASKCURRENT\" is correct $myGO"
  else
    logit "Umask current setting in this shell of \"$UMASKCURRENT\" is incorrect ! $myWARN"
    logit "Correct by adding to root users .bash_profile \"umask 0022\" $myNOTE"
  fi

  UMASKCHK3=$(grep umask /etc/sysconfig/init|awk '{print $2}'|tr -d ' ')
  if [ "$UMASKCHK3" == "0022" -o "$UMASKCHK3" == "" ];then
    logit "Umask creation setting in /etc/sysconfig/init of \"$UMASKCHK3\" is correct $myGO"
  else
    logit "Umask creation \"$UMASKCHK3\" setting in /etc/sysconfig/init incorrect ! $myWARN"
  fi

  UMASKCHK4=$(grep umask /etc/profile|grep -v "#"|tail -1|awk '{print $2}'|tr -d ' ')
  if [ "$UMASKCHK4" == "0022" -o "$UMASKCHK4" == "022" ];then
    logit "Umask creation setting in /etc/profile of \"$UMASKCHK4\" is correct $myGO"
  else
    logit "Umask creation \"$UMASKCHK4\" setting in /etc/profile incorrect ! $myWARN"
  fi

  UMASKCHK5=$(grep umask /etc/csh.cshrc|grep -v "#"|tail -1|awk '{print $2}'|tr -d ' ')
  if [ "$UMASKCHK5" == "0022" -o "$UMASKCHK5" == "022" ];then
    logit "Umask creation setting in /etc/csh.cshrc of \"$UMASKCHK5\" is correct $myGO"
  else
    logit "Umask creation \"$UMASKCHK5\" setting in /etc/csh.cshrc incorrect ! $myWARN"
  fi

}

chkUlimits() { 

    showSysMisc "-c" 
    showSysMisc "-d" 
    showSysMisc "-e" 
    showSysMisc "-f" 
    showSysMisc "-i" 
    showSysMisc "-l" 
    showSysMisc "-m" 
    showSysMisc "-n" 
    showSysMisc "-p" 
    showSysMisc "-q" 
    showSysMisc "-r" 
    showSysMisc "-s" 
    showSysMisc "-t" 
    showSysMisc "-u" 
    showSysMisc "-v" 
    showSysMisc "-x" 

}

chkYumProxy() {
  YUMPROXYCHK=$(grep proxy /etc/yum.conf|egrep -v "#|export")
  if [ "$YUMPROXYCHK" != "" ];then
    logit "Proxy set to \"$YUMPROXYCHK\" in /etc/yum.conf $myGO"
  else
    logit "Proxy NOT set in /etc/yum.conf ! $myNOTE"
  fi

  YUMCHKLIVE=$(yum list gcc &>/dev/null;echo $?)
  if [ "$YUMCHKLIVE" == "0" ];then
    logit "Yum connectivty to repo db passes $myGO"
  else
    logit "Yum connectivty to repo db fails ! $myWARN"
  fi
}

### Mainline logic ... 

callAllfunct() { 

  myINFO="[ Meet Minimum System Requirements 1.1.1 - Hardware ]" 
  blueinfo "$myINFO" 
  logit "Checking : $myINFO" 

  chkMemory
  smallLine

  chkDiskspace
  smallLine

  chkDevResSpace
  smallLine

  chkDiskAccessTime 
  smallLine

  chkCPUcores
  smallLine

  chkNETinterface 
  smallLine

  myINFO="[ Meet Minimum System Requirements 1.1.2 - Operating Systems Requirements ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkOS
  smallLine
  chkSwappiness 
  smallLine

  myINFO="[ Meet Minimum System Requirements 1.1.3 - Software Requirements ]" 
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkRPMS
  smallLine

  myINFO="[ Meet Minimum System Requirements 1.1.4 - Metastore Database Requirements ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkExistingDB 
  smallLine

  myINFO="[ JDK Requirements 1.1.5 ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkJDK
  smallLine

  myINFO="[ Configure the Remote Repositories 1.2 ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkRemoteRepos
  smallLine

  myINFO="[ Collect Information 1.4 ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkFQDNhost
  smallLine

  myINFO="[ Prepare the Environment 1.5 ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkNTPconfig
  smallLine

  chkDNSconfig
  smallLine

  chkSELINUXcfg
  smallLine

  chkPROXYconfig
  smallLine

  chkFWconfig
  smallLine

  #chkSSHconn
  #smallLine

  myINFO="[ Set Default File and Directory Permissions 2.1 - Configure Umask Settings ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkUmaskInBashRCfile
  smallLine

  chkUlimits 
  smallLine 

  chkTransparentHugePages
  smallLine

  chkYumProxy
}

hdr 

if [ "$PARONE" == "show" -o "$PARONE" == "SHOW" ];then 
  logit "Running in show mode..." 
  smallLine 
  callAllfunct
elif [ "$PARONE" == "change" -o "$PARONE" == "CHANGE" ];then
  logit "Running in change mode, modifying system config where possible ... "
  smallLine 
  callAllfunct
else 
  myWarn=$(redwarn "Error") 
  logit "$myWarn Please pass in parameter one either \"[ show | change ]\" "
  help 
fi 

ftr 

exit 0 
