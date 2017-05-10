#!/bin/bash 

# Author : Roger K. Hill  
# Date : 02/16/2017 
# Org : Yash Technologies / Caterpillar 
# Desc : hw_mon_cat.sh is a script for us to help check the dmesg utility for hardware related errors and report them via email ... 

### Script global vars ... 

SHORTHOST=$(hostname --short)
PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
PARTHREE="$3"
COUNTER=0
ME=$(basename $0)
SCRIPT_VER="1.2"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
REPTFILE="$HOME/$ME.$DDMMYY.rpt"
OSTYPE=$(cat /etc/redhat-release|awk '{print $1" "$2}')
OSVER=$(cat /etc/redhat-release |awk '{print $7}')
KERNEL=$(uname -r)
SENDMAILCHK=$(rpm -qa|grep sendmail)
MAILRCPT="hill_roger_k@cat.com"
MSGBODYTMPFILE="messagebody.tmp"
REPORTMODE="false"
optimizedVal="NO" 
OLD_IFS=$IFS
me=`uname -n`
mehosts=`grep $me /etc/hosts`
ONCALLPHONE="6186986055@messaging.sprintpcs.com" 	# Roger Hill 
GLOBALERR_FLAG="false" 

### Script global function defs ... 

logit() {

  ### If we receive only $1 parameter
  ### If we receive $1 and $2 parameter, it is for bldHTMLmsgTableRow in "show" mode, 2 separate strings 
  ### If we receive $1, $2, $3 parameter, it is for bldHTMLmsgTableRow in "show" mode, all 3 in one string 
  ### If we receive $1, $2, $3,  and $4 parameter, it is for bldHTMLmsgTableRow in "debug" or "optimize" mode 4 separate strings 

  LOCALNUMPAR="$#"
  DATEFMT=$(date '+%b %d %H:%M:%S')

  logtxt () {
    if [ $# -eq 4 ];then
      if [ "$optimizedVal" == "YES" -a "$PARONE" == "debug" ];then
        ## OPTFLAG="OPTIMIZED"
        OPTFLAG="OK"
        echo "$DATEFMT $SHORTHOST $1 : \"$2\" currently, but \"$3\" is already optimized [$OPTFLAG]" | tee -a $LOGFILE
      elif [ "$PARONE" == "debug" ];then
        OPTFLAG=$(echo $PARONE|tr '[:lower:]' '[:upper:]')
        echo "$DATEFMT $SHORTHOST $1 : \"$2\" currently, but \"$3\" is optimized [$OPTFLAG]" | tee -a $LOGFILE
      elif [ "$PARONE" == "optimize" ];then
	if [ "$optimizedVal" == "YES" ];then 
	  ## OPTFLAG=$(echo $PARONE|tr '[:lower:]' '[:upper:]')
	  OPTFLAG="OPTIMIZED" 
          echo "$DATEFMT $SHORTHOST $1 : \"$2\" currently, but \"$3\" is already optimized [$OPTFLAG]" | tee -a $LOGFILE
	else
	  ## orig code brnach 
	  OPTFLAG=$(echo $PARONE|tr '[:lower:]' '[:upper:]')
          echo "$DATEFMT $SHORTHOST $1 : \"$2\" currently, modified to \"$3\" now optimizing [$OPTFLAG]" | tee -a $LOGFILE
  	fi 
      fi
    else
      echo "$DATEFMT $SHORTHOST $1" | tee -a $LOGFILE
    fi
  }

  if [ $LOCALNUMPAR -eq 1 ];then
    logtxt "$1"
  elif [ $LOCALNUMPAR -eq 2 ];then
    logtxt "$1 $2"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "$1" "$2"
    fi
  elif [ $LOCALNUMPAR -eq 3 ];then
    logtxt "$1 $2 $3"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "$1" "$2" "$3"
    fi
  elif [ $LOCALNUMPAR -eq 4 ];then
    logtxt "$1" "$2" "$3" "$4"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "$1 :" "$2" "$3" "$4"
    fi
  fi
}

helpMenu() { 
  ## stdout and log only ... 
  logit "Script \"$ME\" takes two parameters" 
  logit "" 
  logit "Parameter 1 [ --report=true ] we will print to stdout,log,Text msgs and send HTML email report" 
  logit "" 
  logit "Parameter 2 [ --mode=verbose ] we will print alerts and non-alerts, else, only send if alerts exist"  
  logit "" 
  logit "Parameter Nonw we will print alerts and non-alerts, only to stdout and log, no email report, no Text msgs" 
}

emailHTMLfile() {
  ## internal use function 
  if [ "$PARONE_VAL" == "true" ];then 
    if [[ "$PARTWO_VAL" == "verbose" ]] || [[ "$PARTWO_VAL" == "onlyerrors" ]];then 
      /usr/sbin/sendmail -t < message.html
      sleep 2 
      if [ -f $MSGBODYTMPFILE ];then 
        rm -rf $MSGBODYTMPFILE
        logit "Cleaning up the temporary files now [ NOTED ]"
      fi 
      if [ -f message.html ];then 
        rm -rf message.html
        logit "Remove message.html" 
      fi 
    fi 
  else 
    logit "HTML Report, nothing to report or dis-abled" 
  fi 
}


bldHTMLhdr() {

  catIt () { 
    echo "$1" >> message.html
  }

  ## $1 will be the mail subject 
  ## $2  
 
  ## logit "Creating HTML Header file now" 
  catIt "To: $MAILRCPT" 
  catIt "From: root@$HOSTNAME" 
  catIt "Subject: Caterpillar System $ME report:$HOSTNAME:$descCHK" 
  catIt "Content-Type: text/html; charset=\"us-ascii\""
  catIt "Mime-Version: 1.0"
  catIt "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"DTD/xhtml1-transitional.dtd\">"
  catIt "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>"
  catIt "<meta http-equiv=\"content-type\" content=\"text/html; charset=ISO-8859-1\">"
  catIt "<style type=\"text/css\">"
  catIt "body {background-color: #ffffff; color: #000000;}"
  catIt "body, td, th, h1, h2 {font-family: sans-serif;}"
  catIt "pre {margin: 0px; font-family: monospace;}"
  catIt "a:link {color: #000099; text-decoration: none; background-color: #ffffff;}"
  catIt "a:hover {text-decoration: underline;}"
  catIt "table {border-collapse: collapse;}"
  catIt ".center {text-align: center;}"
  catIt ".center table { margin-left: auto; margin-right: auto; text-align: left;}"
  catIt ".center th { text-align: center !important; }"
  catIt "td, th { border: 1px solid #000000; font-size: 75%; vertical-align: baseline;}"
  catIt "h1 {font-size: 150%;}"
  catIt "h2 {font-size: 125%;}"
  catIt ".p {text-align: left;}"
  #catIt ".e {background-color: #ccffcc; font-weight: bold; color: #000000;}"
  #catIt ".e {background-color: #99ccff; font-weight: bold; color: #000000;}"
  catIt ".e {background-color: #F8F6F4; font-weight: bold; color: #000000;}"
  #catIt ".h {background-color: #66ff00; font-weight: bold; color: #000000;}"
  catIt ".h {background-color: #FFD841; font-weight: bold; color: #000000;}"
  catIt ".b {background-color: #00ffff; font-weight: bold; color: #000000;}"
  catIt ".v {background-color: #cccccc; color: #000000;}"
  catIt ".r {background-color: red; color: #000000;}"
  catIt ".g {background-color: #66ff00; color: #000000;}"
  catIt ".n {background-color: #C6E2FF; color: #000000;}"
  catIt ".vr {background-color: #cccccc; text-align: right; color: #000000;}"
  catIt ".desc {background-color: #cccccc; text-align: center; color: #000000;}"
  catIt "img {float: right; border: 0px;}" 
  catIt "hr {width: 600px; background-color: #cccccc; border: 0px; height: 1px; color: #000000;}" 
  catIt "</style>" 
  catIt "<title>$ME report</title><meta name=\"ROBOTS\" content=\"NOINDEX,NOFOLLOW,NOARCHIVE\"></head>" 
  catIt "<body><div class="center">" 
  catIt "" 
  catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
  catIt "<tbody><tr class=\"h\"><td>"
  catIt "<h1 class=\"p\">Caterpillar \"$ME\" report</h1>"
  catIt "</td></tr>"
  catIt "</tbody></table><br>"
  
  if [ "$descCHK" != "" ];then 
    catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
    catIt "<tbody><tr class=\"v\"><td>"
    catIt "<h1 class=\"desc\">Description : $descCHK </h1>"
    catIt "</td></tr>"
    catIt "</tbody></table><br>"
  fi 
} 

bldHTMLftr(){
  catIt () {
    echo "$1" >> message.html
  }

  ## logit "Creating HTML Header file now" 
  catIt "</div>" 
  catIt "</body></html>"
}

bldHTMLmsgTableRow(){
  ### $1 = single column , typically "Component" 
  ### $2 = double column , typically "Value" 
  ### $3 = triple column, if exists is optimal value
  ### $4 = cellColor, if exists  
  
  ### default value   
  cellClass="e"

  catIt () {
    if [ "$PARONE_VAL" == "true" ];then 
      echo "$1" >> $MSGBODYTMPFILE
    fi 
  }

  if [ "$3" == "" ];then  
    catIt "<tr><td class=\"e\">$1</td><td class=\"v\">$2</td></tr>"
  elif [ "$3" == "ALERT" ];then 
    catIt "<tr><td class=\"e\">$1</td><td class=\"r\">$2</td></tr>"
  elif [ "$3" == "OK" ];then 
    if [ "$PARTWO_VAL" != "onlyerrors" ];then  
      catIt "<tr><td class=\"e\">$1</td><td class=\"g\">$2</td></tr>"
    fi 
  elif [ "$3" == "NOTE" ];then
    if [ "$PARTWO_VAL" != "onlyerrors" ];then  
      catIt "<tr><td class=\"e\">$1</td><td class=\"n\">$2</td></tr>"
    fi 
  fi 
}

bldHTMLmsgTableHdrFile(){
  # $1 Table Title 
  # $2 Col1 Heading 
  # $3 Col2 Heading 
  # $4 Col3 Heading 
  # $5 Col4 Heading 

  if [ "$PARTWO_VAL" == "verbose" ] || [[ "$PARTWO_VAL" == "onlyerrors" && "$4" == "ALERT" ]];then 
    catIt () {
      if [ "$PARONE_VAL" == "true" ];then
        echo "$1" >> $MSGBODYTMPFILE
      fi 
    } 

    ## if [ "$4" == "" ];then ## we only have passed in 3 parameters to function (2 rows in table)
      catIt "<h2>$1</h2>" 
      catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
      catIt "<tbody><tr class=\"h\"><th>$2</th><th>$3</th></tr>" 
    ## fi  
    ## elif [ "$5" != "" ];then
      ## catIt "<h2>$1</h2>"
      ## catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
      ## catIt "<tbody><tr class=\"h\"><th>$2</th><th>$3</th><th>$4</th><th>$5</th></tr>"
    ## fi 
  fi 
}

bldHTMLmsgTableFtrFile(){
  ## if [ "$PARTWO_VAL" == "verbose" ] || [[ "$PARTWO_VAL" == "onlyerrors" && "$4" == "ALERT" ]];then
    echo "</tbody></table><br>" >> $MSGBODYTMPFILE
  ## fi 
}

subHeader(){
  
  ### doing this to print header all of the time for this function only ... 
  OLD_PARTWO_VAL=$PARTWO_VAL 
  PARTWO_VAL="verbose"

  DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
  logit "----------------Caterpillar $ME Script Running----------------"
  logit "*** Script Version : $SCRIPT_VER"
  logit "*** Script filename : \"$ME\" "
  logit "*** Script logfile : \"$LOGFILE\" "
  logit "*** Script report file : \"$REPTFILE\" "
  logit "*** Script mode run : $PARONE $PARTWO"
  logit "*** Script date run : $DDMMYY2"

  logit "----------------Caterpillar $ME Script Running----------------"
  if [ "$REPORTMODE" == "true" ];then
    HOSTSYSDETAILS=$(uname -a|sed -e 's/Linux /Liunx <b>/g'|sed -e 's/ 2.6/<\/b> 2.6/g')
    DATEFMTREPORT=$(date '+%b %d %Y %H:%M:%S')
    bldHTMLmsgTableHdrFile "" "Component" "Values" 
    bldHTMLmsgTableRow "Host System Details" "$HOSTSYSDETAILS"
    bldHTMLmsgTableRow "Report Date" "$DATEFMTREPORT"
    bldHTMLmsgTableRow "./$ME $PARONE $PARTWO $PARTHREE" "Script Version : $SCRIPT_VER<br> Script filename : \"$ME\"<br> Script logfile : \"$LOGFILE\"<br> Script report file : \"$REPTFILE\"<br> Script mode run : $PARONE<br> Script date run : $DDMMYY2<br>"
    ### no bldHTMLmsgTableFtrFile, done in autoDiscBaseSystem function 
    bldHTMLmsgTableFtrFile 
  fi
  
  PARTWO_VAL=$OLD_PARTWO_VAL 

}

## header(){
  ## subHeader
## }

line () { 
  logit "-----------------------------------------------------" 
} 

sendTextMsgAlert() { 
  ### $1=servername $2=error 
  
  ### Only send if we have any errors and only if invoked by second parameter ... 
  if [[ "$GLOBALERR_FLAG" == "true" ]] && [[ "$PARTWO_VAL" == "onlyerrors" ]];then 
    logit "Sending txt message alert"  
    echo "$2 $3" | mail -s "$1 - ALERT" $ONCALLPHONE 
  else 
    logit "Txt message alert disabled or nothing to send"  
  fi 

} 

basehardware() {

  ### doing this to print header all of the time for this function only ...
  OLD_PARTWO_VAL=$PARTWO_VAL
  PARTWO_VAL="verbose"

  mem=$(free -m|grep Mem|awk '{print $2}')
  rootdiskspace=$(df -ha /|tail -1|awk '{print $2}')
  cpunum=$(cat /proc/cpuinfo|grep processor|wc -l)
  cputype=$(cat /proc/cpuinfo|grep "model name"|tail -1|awk -F: '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
  swapsize=$(free -g | grep Swap | awk '{print $2}') 

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableHdrFile "Basic Hardware Config" "Component" "Values" 
  fi 
 
  logit "Memory Installed:" "$mem MB" 
  logit "Root Disk space:" "$rootdiskspace" 
  logit "CPU cores:" "$cpunum" 
  logit "CPU type:" "$cputype" 
  logit "Swap size:" "$swapsize" 
  line  

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi

  PARTWO_VAL=$OLD_PARTWO_VAL

}

dmesg_mon(){

  checkFlag="true" 
  ### ... 1.) dmesg monitoring proto-type ...
  logit "Beginning dmesg check now..." 
  ##if [ "$REPORTMODE" == "true" ];then
    ##bldHTMLmsgTableHdrFile "Dmesg Error Checking" "Component" "Value"
  ##fi
  DMESG_ERR_PATTERN="err|bad"
  MYDMESG=$(/bin/dmesg|egrep -i $DMESG_ERR_PATTERN|egrep -v -i 'Interrupt|IRQ')
  if [ "$MYDMESG" == "" ];then 
    checkFlag="false"       
  else 
    for line5 in $MYDMESG
    do
      if [ "$MYDMESG" != "" ];then
 	GLOBALERR_FLAG="true" 
  	if [ "$REPORTMODE" == "true" ];then
    	  bldHTMLmsgTableHdrFile "Dmesg Error Checking" "Component" "Value" "ALERT" 
  	fi
        logit "dmesg found:" $line5 "ALERT" 
	logit "ACTION:" "Depending upon hardware error severity, component may need to be replaced" "NOTE" 
        sendTextMsgAlert $me "ALERT : dmesg found: $line5" "ACTION: Depending upon hardware error severity, component may need to be replaced" 
        checkFlag="true"
      fi
    done
  fi 

  if [ "$checkFlag" == "false" ];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Dmesg Error Checking" "Component" "Value"
    fi
    logit "dmesg found:" "No Errors" "OK" 
  fi 
  line

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

network_conn_mon_svc() {

  checkFlag="true"
  ### ... 2.) $1 as number of ESTABLISHED connect threshold, and $2 as process name
  logit "Beginning network connections for \"$2\" check now..."
  ## if [ "$REPORTMODE" == "true" ];then
    ## bldHTMLmsgTableHdrFile "Network Connection Checking" "Component" "Value"
  ## fi
  HADOOP_SVC_PID=$(ps -ef | grep -v grep | grep "$2" | awk '{print $2}')
  if [ "$HADOOP_SVC_PID" == "" ];then
    checkFlag="false"
  else
    for mypid in $HADOOP_SVC_PID
    do
      NET_COUNT=$(netstat -nap | grep $mypid | grep ESTABLISHED | wc -l)
      if [ "$NET_COUNT" -gt "$1" ];then
        GLOBALERR_FLAG="true"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableHdrFile "Network Connection Checking" "Component" "Value" "ALERT" 
        fi
        logit "netstat ESTABLISHED CONN for pid \"$2\" over threshold \"$1\": " "$NET_COUNT" "ALERT"
        logit "ACTION:" "Restart PID \"$2\" if possbile" "NOTE"
        sendTextMsgAlert $me "ALERT : netstat ESTABLISHED CONN for pid \"$2\" over threshold \"$1\": $NET_COUNT" "ACTION: Restart
PID \"$2\" if possbile"
      else
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableHdrFile "Network Connection Checking" "Component" "Value" 
	fi 
        logit "netstat ESTABLISHED CONN for pid \"$2\" under threshold \"$1\": " "$NET_COUNT" "OK"
      fi
    done
  fi
  if [ "$checkFlag" == "false" ];then
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Network Connection Checking" "Component" "Value" 
    fi 
    logit "Network connection process for \"$2\" NOT found:" "NA (Not Applicable)" "OK"
  fi 
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

ethtoolChk() {
  checkFlag="true"
  ### ... 2.) $1 as number of ESTABLISHED connect threshold, and $2 as process name
  logit "Beginning ethtool all interfaces checks now..."
  ## if [ "$REPORTMODE" == "true" ];then
    ## bldHTMLmsgTableHdrFile "Ethertool Interface Checking" "Component" "Value"
  ## fi
  for eth in $(ip link show|egrep -iv 'loopback|ether'|grep eth|awk '{print $2}'|awk -F: '{print $1}')
  do
    NICSPEED=$(ethtool $eth|grep Speed|awk '{print $2}')
    NICDUPLX=$(ethtool $eth|grep Duplex|awk '{print $1 $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
    NICTXERR=$(ethtool -S $eth|grep tx_err|awk '{print $2}')
    NICRXERR=$(ethtool -S $eth|grep rx_err|awk '{print $2}')
    if [ "$NICTXERR" == "" -a "$NICRXERR" == "" ];then
      checkFlag="false"
    else
      if [ "$NICTXERR" != "" ];then
        GLOBALERR_FLAG="true"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableHdrFile "Ethertool Interface Checking" "Component" "Value" "ALERT"
        fi
        logit "NIC \"$eth\" configured with speed :" "\"$NICSPEED\", and \"$NICDUPLX\""
        logit "transmitt errors found:" $NICTXERR "ALERT"
        logit "ACTION:" "Restart interface \"$eth\" if possbile" "NOTE"
        sendTextMsgAlert $me "ALERT : transmitt errors found: $NICTXERR" "ACTION: Restart interface \"$eth\" if possbile"
      fi
      if [ "$NICRXERR" != "" ];then
        GLOBALERR_FLAG="true"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableHdrFile "Ethertool Interface Checking" "Component" "Value" "ALERT"
        fi
        logit "NIC \"$eth\" configured with speed :" "\"$NICSPEED\", and \"$NICDUPLX\""
        logit "receive errors found:" $NICTXERR "ALERT"
        logit "ACTION:" "Restart interface \"$eth\" if possbile" "NOTE"
        sendTextMsgAlert $me "ALERT : receive errors found: $NICTXERR" "ACTION: Restart interface \"$eth\" if possbile"
      fi
    fi
  done

  if [ "$checkFlag" == "false" ];then
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Ethertool Interface Checking" "Component" "Value"
    fi
    logit "NIC \"$eth\" configured with speed :" "\"$NICSPEED\", and \"$NICDUPLX\""
    logit "Ethtool checks all interfaces NO errors found:" "No Errors" "OK"
  fi
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

sysload_mon () {
  checkFlag="true"
  logit "Beginning system load check now ..."
  ## if [ "$REPORTMODE" == "true" ];then
    ## bldHTMLmsgTableHdrFile "System Load Checking" "Component" "Value"
  ## fi
  MIN15_UPTIME_MAX=20
  MIN15_UPTIME_LOAD=$(uptime | awk '{print $NF}' | awk -F. '{print $1}')
  if [ "$MIN15_UPTIME_LOAD" -ge "$MIN15_UPTIME_MAX" ];then
    GLOBALERR_FLAG="true"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "System Load Checking" "Component" "Value" "ALERT"
    fi
    logit "Node Uptime 15 minute load avg exceeds threshold of \"$MIN15_UPTIME_MAX\":" "$MIN15_UPTIME_LOAD" "ALERT"
    logit "ACTION:" "Identify top PIDs consuming resources with \"top\", monitor, and restart if possible" "NOTE"
    sendTextMsgAlert $me "ALERT : Node Uptime 15 min load avg exceeds threshold \"$MIN15_UPTIME_MAX\": $MIN15_UPTIME_LOAD" "ACTION: Identify top PIDs consuming resources with \"top\", monitor, and restart if possible"
  else
    checkFlag="false"
  fi

  if [ "$checkFlag" == "false" ];then
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "System Load Checking" "Component" "Value" 
    fi 
    logit "System load on 15 min avg currently \"$MIN15_UPTIME_LOAD\" :" "System Managable" "OK"
  fi
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

vol_mon () { 
  ### par $1 is the volume or mount point to check ... 
  checkFlag="true"
  logit "Beginning volume \"$1\" space check now ..."
  ## if [ "$REPORTMODE" == "true" ];then
    ## bldHTMLmsgTableHdrFile "Volume Space Checking" "Component" "Value"
  ## fi
  VOL_MAX="80"	## this number is a percentage 
  VOL_FULL=$(df -ha $1 | tail -1 | awk '{print $5}'|awk -F\% '{print $1}')
  if [ "$VOL_FULL" -ge "$VOL_MAX" ];then
    GLOBALERR_FLAG="true"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Volume Space Checking" "Component" "Value" "ALERT" 
    fi
    logit "Volume \"$1\" exceeds threshold \"$VOL_MAX%\" at:" "$VOL_FULL%" "ALERT"  
    logit "ACTION:" "Remove un-neccessary files on the \"$1\" volume to free space" "NOTE" 
    sendTextMsgAlert $me "ALERT : Volume \"$1\" exceeds threshold \"$VOL_MAX%\" at: $VOL_FULL%" "ACTION: Remove un-neccessary files on the \"$1\" volume to free space"
  else
    checkFlag="false"
  fi
  if [ "$checkFlag" == "false" ];then
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Volume Space Checking" "Component" "Value"
      logit "Volume \"$1\" under threshold \"$VOL_MAX%\" at:" "$VOL_FULL%" "OK" 
    fi 
  fi
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

ntp_drift_mon(){
  checkFlag="true"
  logit "Beginning System Clock Drift check now ..."
  ##if [ "$REPORTMODE" == "true" ];then
    ##bldHTMLmsgTableHdrFile "System Clock Drift Check" "Component" "Value"
  ##fi
  NTPCLOCK_CHK=$(ntpq -p | tail -1 | awk '{print $9}' | sed -e s/-//g|awk -F. '{print $1}')
  NTP_DRIFT_MAX="15"
  if [ "$NTPCLOCK_CHK" -ge "$NTP_DRIFT_MAX" ];then
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "System Clock Drift Check" "Component" "Value" "ALERT"
    fi
    GLOBALERR_FLAG="true"
    logit "System Clock Drift Offset \"$NTPCLOCK_CHK\" exceeds limit \"$NTP_DRIFT_MAX\"" "ALERT"
    logit "ACTION:" "Re-adjust the system clock run\"ntpdate -u $(grep server /etc/ntp.conf|grep -v "#"|awk '{print $2}')\"" "NOTE"
    sendTextMsgAlert $me "ALERT : System Clock Drift Offset \"$NTPCLOCK_CHK\" exceeds limit \"$NTP_DRIFT_MAX\" " "ACTION: Re-adjust the system clock run\"ntpdate -u $(grep server /etc/ntp.conf|grep -v "#"|awk '{print $2}')\""
  else
    checkFlag="false"
  fi
  if [ "$checkFlag" == "false" ];then
   if [ "$REPORTMODE" == "true" ];then
     bldHTMLmsgTableHdrFile "System Clock Drift Check" "Component" "Value" 
   fi 
   logit "System Clock Drift Offset \"$NTPCLOCK_CHK\" within limit:" "\"$NTP_DRIFT_MAX\"" "OK"
  fi
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

packet_mon(){
  checkFlag="true"
  logit "Beginning NIC Packet Loss check now ..."
  ##if [ "$REPORTMODE" == "true" ];then
    ##bldHTMLmsgTableHdrFile "NIC Packet Loss Check" "Component" "Value"
  ##fi

  for eth in $(ip link show|egrep -iv 'loopback|ether'|grep eth|awk '{print $2}'|awk -F: '{print $1}')
  do
    PACKET_CHK_RX=$(ifconfig $eth|grep dropped|awk '{print $4}'|awk -F: '{print $2}'|head -1) 
    PACKET_CHK_TX=$(ifconfig $eth|grep dropped|awk '{print $4}'|awk -F: '{print $2}'|tail -1) 
    if [ "$PACKET_CHK_RX" != "0" ];then 
      GLOBALERR_FLAG="true"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableHdrFile "NIC Packet Loss Check" "Component" "Value" "ALERT" 
      fi
      logit "NIC $eth shows \"$PACKET_CHK_RX\" dropped RX packets:" "WARNING" "ALERT" 
      logit "ACTION:" "Recyle the NIC \"$eth\" by ifdown and ifup commands, or reboot node" "NOTE" 
      sendTextMsgAlert $me "ALERT : NIC $eth shows \"$PACKET_CHK_RX\" dropped packets" "ACTION: Recyle the NIC \"$eth\" by ifdown and ifup commands, or reboot node"
    else
      checkFlag="false"
    fi 
    if [ "$PACKET_CHK_TX" != "0" ];then
      GLOBALERR_FLAG="true"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableHdrFile "NIC Packet Loss Check" "Component" "Value" "ALERT" 
      fi
      logit "NIC $eth shows \"$PACKET_CHK_TX\" dropped RX packets:" "WARNING" "ALERT"
      logit "ACTION:" "Recyle the NIC \"$eth\" by ifdown and ifup commands, or reboot node" "NOTE"
      sendTextMsgAlert $me "ALERT : NIC $eth shows \"$PACKET_CHK_TX\" dropped packets" "ACTION: Recyle the NIC \"$eth\" by ifdown and ifup commands, or reboot node"
    else
      checkFlag="false"
    fi
  done 
  if [[ "$PACKET_CHK_RX" == "0" ]] && [[ "$PACKET_CHK_TX" == "0" ]];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "NIC Packet Loss Check" "Component" "Value"
    fi
    ## if [ "$checkFlag" == "false" ];then
    logit "NIC $eth shows \"0\" NO dropped RX packets" "0" "OK" 
  fi
  line
  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

#######################
### main line logic ### 
#######################

### Process the input parameters
if [ "$PARONE" != "" ];then
  PARONE_VAL=$(echo $PARONE|awk -F= '{print $2}')
  PARTWO_VAL=$(echo $PARTWO|awk -F= '{print $2}')

  ## if [ "$PARONE_VAL" == "true" ];then
  if [[ "$PARONE_VAL" == "true" ]];then
    if [[ "$PARTWO_VAL" == "verbose" ]] || [[ "$PARTWO_VAL" == "onlyerrors" ]];then
      logit "Report mode enabled [ OK ]"
      REPORTMODE="true"
    fi 
  else
    logit "Report mode off"
  fi
fi

clear 

logit "*** QA Server Hardware & OS monitoring checklist ***"
subHeader
## bldHTMLmsgTableFtrFile
basehardware

IFS=$'\n'

### hardware err checking via dmesg ... 
dmesg_mon

### volume space monitoring ... 
vol_mon "/var"
vol_mon "/opt"
## vol_mon "/usr"
## vol_mon "/"
vol_mon "/home"
vol_mon "/tmp"
## vol_mon "/home-extended"
## vol_mon "/etc"

### monitor packet drops on all interfaces found ...  
## packet_mon 

### ethtoolChk ...
ethtoolChk

### network_conn_mon_svc checking network connections for specific pids ... 
network_conn_mon_svc 40 HiveServer2
network_conn_mon_svc 40 Impala
network_conn_mon_svc 40 HBase

# check system load avg 15 min uptime value ... 
sysload_mon


IFS=$OLD_IFS

if [ "$PARTWO_VAL" == "verbose" ] || [[ "$REPORTMODE" == "true" && "$GLOBALERR_FLAG" != "false" ]];then 
  if [[ "$PARTWO_VAL" == "verbose" ]] || [[ "$PARTWO_VAL" == "onlyerrors" ]];then
    ## bldHTMLmsgTableFtrFile
    logit "Building and sending HTML Report [OK]"
    bldHTMLhdr 
    cat $MSGBODYTMPFILE >> message.html 
    bldHTMLftr  
    emailHTMLfile
  fi 
else 
  logit "System \"$me\" is clean, no errors found, no report needed [ OK ]" 
  rm -rf $MSGBODYTMPFILE
  rm -rf message.html 
fi

exit 0 
