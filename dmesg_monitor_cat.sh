#!/bin/bash 

# Author : Roger K. Hill  
# Date : 02/08/2017 
# Org : Yash Technologies / Caterpillar 
# Desc : qa basic check with advanced email and reporting capabilites  

SHORTHOST=$(hostname --short)
PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
PARTHREE="$3"
COUNTER=0
ME=$(basename $0)
SCRIPT_VER="3.5"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
REPTFILE="$HOME/$ME.$DDMMYY.rpt"
OSTYPE=$(cat /etc/redhat-release|awk '{print $1" "$2}')
OSVER=$(cat /etc/redhat-release |awk '{print $7}')
KERNEL=$(uname -r)
SENDMAILCHK=$(rpm -qa|grep sendmail)
MAILRCPT="roger.hill@yash.com"
MSGBODYTMPFILE="messagebody.tmp"
REPORTMODE="false"
optimizedVal="NO" 
OLD_IFS=$IFS

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

if [ "$PARONE" != "" ];then
  PARONE_VAL=$(echo $PARONE|awk -F= '{print $2}')

  if [ "$PARONE_VAL" == "true" ];then
    logit "Report mode enabled [ OK ]"
    REPORTMODE="true"
  else
    logit "Report mode off"
  fi

fi

emailHTMLfile() {
  ## internal use function 
  /usr/sbin/sendmail -t < message.html
  sleep 2 
  logit "Cleaning up the temporary files now [ NOTED ]"
  if [ -f $MSGBODYTMPFILE ];then 
    rm -rf $MSGBODYTMPFILE
  fi 
  if [ -f message.html ];then 
    rm -rf message.html
    logit "DEBUG remove message.html" 
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
    echo "$1" >> $MSGBODYTMPFILE
  }
  if [ "$4" == "YES" ];then 
    cellClass="e"
  elif [ "$4" == "NO" ];then
    cellClass="r"
  elif [ "$4" == "OPTIMIZE" ];then
    cellClass="b"
  fi 

  if [ "$3" == "" ];then  
    catIt "<tr><td class=\"e\">$1</td><td class=\"v\">$2</td></tr>"
  elif [ "$3" != "" ];then 
    catIt "<tr><td class=\"e\">$1</td><td class=\"v\">$2</td><td class=\"e\">$3</td><td class=\"$cellClass\">$4</td></tr>"
  fi 
}

bldHTMLmsgTableHdrFile(){
  # $1 Table Title 
  # $2 Col1 Heading 
  # $3 Col2 Heading 
  # $4 Col3 Heading 
  # $5 Col4 Heading 

  catIt () {
    echo "$1" >> $MSGBODYTMPFILE
  }

  if [ "$4" == "" ];then ## we only have passed in 3 parameters to function (2 rows in table)
    catIt "<h2>$1</h2>" 
    catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
    catIt "<tbody><tr class=\"h\"><th>$2</th><th>$3</th></tr>" 
  elif [ "$5" != "" ];then
    catIt "<h2>$1</h2>"
    catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
    catIt "<tbody><tr class=\"h\"><th>$2</th><th>$3</th><th>$4</th><th>$5</th></tr>"
  fi 
}

bldHTMLmsgTableFtrFile(){
  echo "</tbody></table><br>" >> $MSGBODYTMPFILE
}

subHeader(){

  DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
  logit "----------------Caterpillar $ME Script Running----------------"
  logit "*** Script Version : $SCRIPT_VER"
  logit "*** Script filename : \"$ME\" "
  logit "*** Script logfile : \"$LOGFILE\" "
  logit "*** Script report file : \"$REPTFILE\" "
  logit "*** Script mode run : $PARONE"
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
  fi

}

header(){
  subHeader
}

line () { 
  logit "-----------------------------------------------------" 
} 

basehardware() {
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

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi
}

clear 
# logit "*** QA Server Basic system checklist ***"

me=`uname -n`
mehosts=`grep $me /etc/hosts`

## subHeader
## bldHTMLmsgTableFtrFile
## basehardware

IFS=$'\n'

#######################
### main line logic ### 
#######################

### ... 1.) dmesg monitoring proto-type ... 
line 
if [ "$REPORTMODE" == "true" ];then
  bldHTMLmsgTableHdrFile "Dmesg Error Checking" "Component" "Value"
fi
DMESG_ERR_PATTERN="err|bad" 
MYDMESG=$(/bin/dmesg|egrep -i $DMESG_ERR_PATTERN) 
for line5 in $MYDMESG 
do 
  if [ "$MYDMESG" != "" ];then 
    logit "dmesg found" $line5 
  fi 
done  
if [ "$REPORTMODE" == "true" ];then
  bldHTMLmsgTableFtrFile
fi

IFS=$OLD_IFS

if [ "$REPORTMODE" == "true" ];then 
  bldHTMLmsgTableFtrFile
  logit "Building and sending HTML Report [OK]"
  bldHTMLhdr 
  cat $MSGBODYTMPFILE >> message.html 
  bldHTMLftr  
  emailHTMLfile
fi

exit 0 
