#!/bin/bash 

# DATE : 03/24/2017
# AUTH : rhill 
# DESC : Caterpillar:HW Pre-install_script.sh to prep server os before installation attempt for CDH  
# Reference URLs  : https://www.cloudera.com/documentation/enterprise/release-notes/topics/rn_consolidated_pcm.html  

PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
COUNTER=0
ME=$(basename $0)
SCRIPT_VER="1.2"
DDMMYY=$(date +%m%d%y%H%M%S)
DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
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

CTR=1
greengo "$myGO"
redwarn "$myWARN" 
yellownote "$myNOTE" 

hdr() {
  longline
  logit "*** Start script run for \"$ME\" on $DDMMYY2 ***"
  longline
  logit "OS     : $OSTYPE" 
  ### Checking OS for CDH 5.8 supported OS ... 
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

chkFStype() { 
  SUPPORTEDFS_CHK=$(mount | egrep 'ext3|ext4|xfs') 
  if [ "$SUPPORTEDFS_CHK" != "" ];then 
    logit "CDH supported filesystems(ext3, ext4 or xfs) found - $myGO" 
  else 
    logit "CDH supported filesystems(ext3, ext4 or xfs) NOT found - $myWARN" 
  fi 
} 

chkIP4enabled() { 
  CHK1=$(find /etc/sysconfig/network-scripts/ -name ifcfg-*|xargs grep -i IPV6 |awk -F= '{print $2}')
  CHK2=$(grep -i IPV6 /etc/sysconfig/network|awk -F= '{print $2}'|egrep -i yes)

  if [ "$CHK1" == "" -a "$CHK2" == "" ];then 
    logit "IPv6 is NOT enabled - $myGO"
  else 
    logit "IPv6 IS enabled - $myWARN"
  fi 
} 

chkPython() { 
  ## CDH 5.8 needs Python 2.4 or higher, but not compat w Python 3.0 
  MyPYTHON=$(/usr/bin/python --version 2>&1 | awk '{print $2}')
  if [ "$(echo $MyPYTHON|awk -F. '{print $1}')" == "2" ];then 
    logit "Python version \"$MyPYTHON\" installed - $myGO" 
  elif [ "$(echo $MyPYTHON|awk -F. '{print $1}')" == "3" ];then 
    logit "Python version \"$MyPYTHON\" installed incompatible - $myWARN" 
  fi 
} 

chkSwappiness() { 
  KERN_BASE_REQ='2.6.32'
  MyKERN_BASE=$(uname -a|awk '{print $3}'|awk -F- '{print $1}')
  if [ "$MyKERN_BASE" == "$KERN_BASE_REQ" ];then 
    logit "Base level kernel is correct for this script $MyKERN_BASE - $myGO" 
  else 
    logit "Base level kernel is incorrect for this check $MyKERN_BASE - $myWARN" 
  fi 

  KERN_X_REQ="303"
  MyKERN_X=$(uname -a|awk '{print $3}'|awk -F. '{print $3}'|awk -F- '{print $2}')
  KERN_CHK=one 
  if [ "$MyKERN_X" -ge "$KERN_X_REQ" ];then
    logit "Exact level kernel is $MyKERN_X, vm.swappiness should be \"1\" " 
    KERN_CHK=one  
  else
    logit "Exact level kernel is $MyKERN_X, vm.swappiness should be \"0\" " 
    KERN_CHK=zero   
  fi

  SWAPPINESS_CHK=$(sysctl -a|grep vm.swappiness | awk -F= '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
  if [ "$SWAPPINESS_CHK" -eq "0" ] && [ "$KERN_CHK" == "zero" ];then 
    logit "Kernel tuning variable to control swap \"vm.swappiness\" is set to \"$SWAPPINESS_CHK\" $myGO" 
  elif [ "$SWAPPINESS_CHK" -eq "1" ] && [ "$KERN_CHK" == "one" ];then
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
  TRANSHUGE_CHK2=$(cat /sys/kernel/mm/transparent_hugepage/defrag|grep "\[never\]"|sed -e 's/^ *//g' -e 's/ *$//g')
  if [ "$TRANSHUGE_CHK" != "" -a "$TRANSHUGE_CHK2" != "" ];then
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
      fi
    fi
  fi
} 

chkKernelOvercommit() { 
  OVERCOMM_CHK1=$(sysctl -a|grep vm.overcommit_memory|awk -F= '{print $2}')
  OVERCOMM_CHK2=$(sysctl -a|grep vm.overcommit_ratio|awk -F= '{print $2}')
  if [ "$OVERCOMM_CHK1" -eq "1" ];then 
    logit "OPT:Kernel tuning variable for \"vm.overcommit_memory\" is set to \"1\" - $myGO" 
  else 
    logit "OPT:Kernel tuning variable for \"vm.overcommit_memory\" is set to \"$OVERCOMM_CHK1\" - $myNOTE" 
  fi 
  smallLine   
  if [ "$OVERCOMM_CHK2" -eq "100" ];then
    logit "OPT:Kernel tuning variable for \"vm.overcommit_ratio\" is set to \"100\" - $myGO"
  else
    logit "OPT:Kernel tuning variable for \"vm.overcommit_ratio\" is set to \"$OVERCOMM_CHK2\" - $myNOTE"
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

  logit "Local storage(disk space) config:" 
  for dir in /var/log /opt /tmp /var /boot 
  do 
    DISKTOT=$(df -Ph $dir|tail -1|awk '{print $2}'|tr -d ' ')
    DISKFREEPER=$(df -Ph $dir|tail -1|awk '{print $4}'|tr -d ' ')
    DISKAVAIL=$(df -Ph $dir|tail -1|awk '{print $3}'|tr -d ' ')
    ## logit "Directory \"$dir\" has \"$DISKTOT\" total diskspace and \"$DISKFREEPER\" free $myNOTE"

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
      ## /var/log, /var and /tmp have different requirements ... ! 
      if [ "$dir" == "/var/log" ];then 
  	DISKTHRESH="50" 
      elif [ "$dir" == "/tmp" ];then 
  	DISKTHRESH="10" 
      elif [ "$dir" == "/var" ];then 
  	DISKTHRESH="20" 
      else 
	DISKTHRESH="25"
      fi 

      if [ "$DISKUSED" -ge "$DISKTHRESH" ];then 
        logit "Sufficient Diskspace for: \"$dir\" directory has \"$DISKUSED GB\" threshold \"$DISKTHRESH G\" $myGO"
      else 
        logit "Insufficient Diskspace available: \"$DISKFREEPER\", \"$DISKAVAIL\" in \"$dir\" , need \"$DISKTHRESH\" GB directory $myWARN"
      fi 
    fi 
  done 
}

chkDiskAccessTime() { 
  logit "Storage linux blk dev mount config(noatime):" 
  IFS=$'\n' 
  logit "** Note : shared mem, root, boot, devpts, proc, root, nfs and swap devices are not being checked" 
  # for dev in $(cat /etc/fstab|egrep -v "#|sysfs|shm|devpts|proc|root|swap|boot|nfs")
  for dev in $(cat /etc/fstab|egrep -v "#|sysfs|shm|devpts|proc|root|swap|boot|nfs|tmp|opt|var|home")
  do 
    if [ "$dev" != "" ];then 
      MYDEV=$(echo $dev|awk '{print $1}')
      MY_FS=$(echo $dev|awk '{print $2}')
      MY_MNT_DIR=$(echo $dev|awk '{print $2}' |awk -F/ '{print $2}')
      DEV_OPTIONS=$(echo $dev|awk '{print $4}') 
      DEV_OPTS_CHK=$(echo $DEV_OPTIONS|grep noatime)
      if [ "$DEV_OPTS_CHK" != "" ];then  
        logit "Dev:$MYDEV w\ options \"$DEV_OPTIONS\" for \"$MY_FS\" $myGO" 
      else 
        logit "Dev:$MYDEV w\ options \"$DEV_OPTIONS\" for \"$MY_FS\" $myWARN missing \"noatime\" attribute" 
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
  logit "Storage linux block device reserved space:" 
  IFS=$'\n'
  logit "** Note : shared mem, root, boot, devpts, proc, nfs, root and swap devices are not being checked" 
  for dev in $(cat /etc/fstab|egrep -v "#|sysfs|shm|devpts|proc|root|boot|swap|nfs|var|opt|home|tmp|^$")
  do
    if [ "$dev" != "" ];then
      MYDEV=$(echo $dev|awk '{print $1}')
      MY_FS=$(echo $dev|awk '{print $2}')
      MY_FS_CHK=$(echo $MY_FS|grep dfs)
      DEV_UUID_CHK=$(echo $dev|grep -i UUID)
      if [ "$DEV_UUID_CHK" != "" ];then 
 	DEV_UUID=$(echo $DEV_UUID_CHK|awk -FUUID= '{print $2}'|awk '{print $1'}) 
 	MYBLK_DEV=$(blkid | grep $DEV_UUID|awk -F: '{print $1}') 
	MYDEV=$MYBLK_DEV
	logit "Found mounted device \"$MYBLK_DEV\" with UUID \"$DEV_UUID\" for mount \"$MY_FS\" " 
      fi 
      if [ "$MY_FS_CHK" != "" ];then 
        BLOCK_COUNT_CHK=$(tune2fs -l $MYDEV|grep 'block count'|awk -F: '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
        if [ "$BLOCK_COUNT_CHK" != "" ];then
          if [ "$BLOCK_COUNT_CHK" != "0" ];then # check if already 0 ... 
            logit "Dev:$MYDEV with  \"$BLOCK_COUNT_CHK\" for mount \"$MY_FS\" $myWARN optimal value 0"
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
            logit "Dev:$MYDEV ALREADY with  \"$BLOCK_COUNT_CHK\" for mount \"$MY_FS\" $myGO"
	  fi 
        else
          logit "Dev:$MYDEV with \"$BLOCK_COUNT_CHK\" for mount \"$MY_FS\" $myWARN optimal value 0"
        fi
      ## else 
        ## logit "Dev:$MYDEV mount \"$MY_FS\" NOT a datanode vol $myNOTE" 
      fi
    fi
  done
  IFS=$OLD_IFS
} 

chkMemory () {
  ## TOTALMEMORY=$(cat /proc/meminfo | grep MemTotal|awk '{print $2}')
  TOTALMEMORY=$(expr $(cat /proc/meminfo | grep MemTotal|awk '{print $2}') / 1000000) ## in GB 
  ## MEMTHRESH="8388608"  # 8 GB in kB
  MEMTHRESH="8"  # 8 GB in kB
  logit "Memory configuration:" 
  if [ "$TOTALMEMORY" -ge "$MEMTHRESH" ];then
    logit "Memory Installed \"$TOTALMEMORY\" GB greater than Mem Threshold \"$MEMTHRESH\" GB $myGO"
  else
    redwarn "$myWARN" 
    logit "Memory Installed \"$TOTALMEMORY\" GB less than Mem Threshold \"$MEMTHRESH\" GB $myWARN"
  fi
}

chkCPUcores () { 
  CPUCORE_THRESH="2" 
  logit "CPU configuration:" 
  TOTALCPU=$(cat /proc/cpuinfo | grep processor|wc -l)
  CPUMODEL=$(cat /proc/cpuinfo|grep 'model name'|tail -1|awk -F: '{print $2}'|cut -d" " -f1-3)

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
  ##logit "Operating System : $myOS $OSVER $myGO" 
  logit "Operating System : $myOS $myGO" 

  OSCHK=$(echo $OSVER|egrep -i '7.2|7.1|6.7|6.6|6.5|6.4|5.10|5.7')
  if [ "$OSVER" == "" ];then 
    logit "Operating System : Ver    : $OSVER $myWARN" 
  else  
    logit "Operating System  Ver    : $OSVER $myGO" 
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
  JAVA7CDH_REQ=67 

  if [ "$JAVAMAJ_VER" == "6" ];then 
    JAVAVER_CHK=$(echo $JAVAVER | awk -F\" '{print $2}'|awk -F. '{print $3}' | awk -F_ '{print $2}')
    if [ "$JAVAVER_CHK" -ge "$JAVA6VER_MIN" ];then 
      logit "Version : $JAVAVER $myGO"
    else 
      logit "Version : $JAVAVER below minimal required version 1.6.0_$JAVA6VER_MIN for CDH 5.8 $myWARN"
    fi 
  elif [ "$JAVAMAJ_VER" == "7" ];then
    JAVAVER_CHK=$(echo $JAVAVER | awk -F\" '{print $2}'|awk -F. '{print $3}' | awk -F_ '{print $2}')
    # if [ "$JAVAVER_CHK" -ge "$JAVA7VER_MIN" ];then
    if [ "$JAVAVER_CHK" -ge "$JAVA7CDH_REQ" ];then
      logit "Version : $JAVAVER $myGO"
    else
      logit "Version : $JAVAVER below minimal required version 1.7.0_$JAVA7VER_MIN for CDH 5.8 $myWARN"
      logit "DEBUG : JAVAVER=\"$JAVAVER\" and JAVA7CDH_REQ=$JAVA7CDH_REQ" 
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

chkNTPconfig() { 
  logit "Checking NTP config - Enable NTP on the Cluster" 
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
  logit "Checking DNS config - Check DNS"
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
    logit "Proxy NOT set successfully $myNOTE"
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
  logit "Checking SELinux - Disable SELinux" 
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

chkFWconfig() { 
  logit "Checking Linux firewall - Disable IPTables" 
  ### FWCHK=$(/etc/init.d/iptables status|grep -i "Firewall is not running")
  FW_CFG_CHK=$(chkconfig --list iptables |grep -i "on")
  FWCHK2=$(/sbin/iptables -L -v -n |egrep -v 'Chain INPUT|Chain FORWARD|Chain OUTPUT|pkts bytes target'|sed -e 's/[[:space:]]*$//')
  if [ "$FWCHK2" == "" -a "$FW_CFG_CHK" == "" ];then 
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

chkPerl(){ 
  CHKPERLBIN=$(which perl)
  CHKPERLBIN_CHK=$(echo $?) 
  if [ "$CHKPERLBIN_CHK" -eq "0" ];then 
    logit "The perl package is installed - $myGO"
  else 
    logit "The perl package is MISSING !  - $myWARN"
  fi  
} 

chkMyHostsFile() { 
  MYIP=$(ifconfig -a| grep inet|grep -v 127.0.0.1|awk '{print $2}' |awk -F: '{print $2}')
  CKFQDN=$(hostname -f) 
  if [ "$MYIP" != "" ];then 
    logit "Checking /etc/hosts format with IP \"$MYIP\" and FQDN \"$FQDN\" ..." 
    HOSTFILE_CHK1=$(grep $MYIP /etc/hosts|awk '{print $1}')
    if [ "$HOSTFILE_CHK1" != "" ];then 
      logit "Host IP Address : $HOSTFILE_CHK1 found in /etc/hosts - $myGO"  
    else 
      logit "Host IP Address : $HOSTFILE_CHK1 MISSING in /etc/hosts - $myWARN"  
    fi 
    DUPLICATE_IP_CHK=$(grep $MYIP /etc/hosts|grep -v "#"|wc -l)
    if [ "$DUPLICATE_IP_CHK" -eq "1" ];then 
      logit "No IP duplicate records found in /etc/hosts for \"$MYIP\" - $myGO" 
    else 
      logit "IP duplicate records found in /etc/hosts for \"$MYIP\" - $myWARN" 
    fi 
    LOCALHOST_CHK=$(grep 127.0.0.1 /etc/hosts|grep localhost|grep -v "#"|wc -l) 
    if [ "$LOCALHOST_CHK" -eq "1" ];then
      logit "The \"localhost\" record is found within /etc/hosts - $myGO"
    else
      logit "The \"localhost\" record NOT found within /etc/hosts - $myWARN"
    fi
    FQDN_CHK=$(cat /etc/hosts |tail -1 |awk '{print $2}'|awk -F. '{print NF}')
    if [ "$FQDN_CHK" -ge "2" ];then 
      logit "The \"$FQDN\" record is formatted correctly in /etc/hosts - $myGO"
    else 
      logit "The \"$FQDN\" record is formatted correctly in /etc/hosts - $myWARN" 
    fi 
    FQDN_IN_HOSTS1=$(grep $MYIP /etc/hosts|awk '{print $2}')
    UPPERCASE_CHK1=$(echo $FQDN_IN_HOSTS1|grep [A-Z])

    FQDN_IN_HOSTS2=$(grep $MYIP /etc/hosts|awk '{print $3}')
    UPPERCASE_CHK2=$(echo $FQDN_IN_HOSTS2|grep [A-Z])
    if [ "$UPPERCASE_CHK1" == "" ];then 
      logit "The FQDN \"$FQDN_IN_HOSTS1\" in /etc/hosts contains no UPPER case letters - $myGO" 
    else 
      logit "The FQDN \"$FQDN_IN_HOSTS1\" in /etc/hosts contains some UPPER case letters - $myWARN" 
    fi 
    if [ "$UPPERCASE_CHK2" == "" ];then
      logit "The FQDN \"$FQDN_IN_HOSTS2\" in /etc/hosts contains no UPPER case letters - $myGO"
    else
      logit "The FQDN \"$FQDN_IN_HOSTS2\" in /etc/hosts contains some UPPER case letters - $myWARN"
    fi
  else 
    logit "Could not determine my IP address - $myWARN" 
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
    ## showSysMisc "-c" 
    ## showSysMisc "-d" 
    ## showSysMisc "-e" 
    ## showSysMisc "-f" 
    ## showSysMisc "-i" 
    ## showSysMisc "-l" 
    ## showSysMisc "-m" 
    showSysMisc "-n" 
    # showSysMisc "-p" 
    # showSysMisc "-q" 
    # showSysMisc "-r" 
    # showSysMisc "-s" 
    # showSysMisc "-t" 
    showSysMisc "-u" 
    # showSysMisc "-v" 
    # showSysMisc "-x" 
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

  myINFO="[ Meet Minimum System Requirements CDH - Hardware ]" 
  blueinfo "$myINFO" 
  logit "Checking : $myINFO" 

  chkMemory
  smallLine

  chkCPUcores
  smallLine

  chkNETinterface 
  smallLine

  chkDiskspace
  smallLine

  chkDevResSpace
  smallLine

  chkDiskAccessTime 
  smallLine

  myINFO="[ Meet Minimum System Requirements - Operating Systems Requirements ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkOS
  smallLine

  myINFO="[ Meet Minimum System Requirements - Software Requirements ]" 
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkRPMS
  smallLine

  myINFO="[ Supported Filesystem ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkFStype 
  smallLine

  myINFO="[ IPv4 Configuration ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkIP4enabled
  smallLine


  myINFO="[ Python Version ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkPython
  smallLine

  myINFO="[ JDK Requirements ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkJDK
  smallLine


  myINFO="[ Perl Installation ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkPerl
  smallLine

  myINFO="[ Validate /etc/hosts file config ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkMyHostsFile
  smallLine

  myINFO="[ Prepare the Environment ]"
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

  chkYumProxy
  smallLine

  myINFO="[ Set Default File and Directory Permissions - Configure Umask Settings ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"
  chkUmaskInBashRCfile
  smallLine

  myINFO="[ Performance Tuning Enhancements ]"
  blueinfo "$myINFO"
  logit "Checking : $myINFO"

  chkUlimits 
  smallLine 

  ### Kernel level settings ... 
  chkTransparentHugePages
  smallLine

  chkSwappiness 
  smallLine
  
  chkKernelOvercommit
}

hdr 

if [ "$PARONE" == "show" -o "$PARONE" == "SHOW" ];then 
  logit "Running in show mode..." 
  smallLine 
  callAllfunct
elif [ "$PARONE" == "change" -o "$PARONE" == "CHANGE" ];then
  ## logit "Running in change mode, modifying system config where possible ... "
  logit "Change mode not fully developed yet, exiting [ OK ]" 
  smallLine 
  ## callAllfunct
else 
  myWarn=$(redwarn "Error") 
  logit "$myWarn Please pass in parameter one either \"[ show | change ]\" "
  help 
fi 

ftr 

exit 0 
