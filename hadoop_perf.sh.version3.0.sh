#!/bin/bash 

# DATE : 04/17/2013
# AUTH : rhill x7643 
# DESC : Hadoop kernel tuning displays, deletes, adds, or modifies kernel level related hadoop parameters, as well as hadoop hdfs, mapreduce, zookeeper, 
# oozie, hbase, sqoop, flume, hive, and pig software settings, shows defaults as well . 

SHORTHOST=$(hostname --short)
PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
PARTHREE="$3"
COUNTER=0
ME=$(basename $0)
SCRIPT_VER="3.0"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
REPTFILE="$HOME/$ME.$DDMMYY.rpt"
OSTYPE=$(cat /etc/redhat-release|awk '{print $1" "$2}')
OSVER=$(cat /etc/redhat-release |awk '{print $7}')
KERNEL=$(uname -r)
SENDMAILCHK=$(rpm -qa|grep sendmail)
MAILRCPT="roger.hill@savvis.com"
MSGBODYTMPFILE="messagebody.tmp"
REPORTMODE="false"
optimizedVal="NO" 
RHVER=$(cat /etc/redhat-release|awk '{print $7}'|awk -F. '{print $1}')

### Global variables that help us determine hadoop vendor ahead of time 
CDH=$(rpm -qa | grep -i cloudera|wc -l)
HDP=$(rpm -qa | grep -i ambari|wc -l)

chkForComment() {
  FIRSTCHAR=$(echo $1|cut -c1)
  if [ "$FIRSTCHAR" != "#" ];then
    echo $1
  fi
}

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

optWarn() {

  chkHDFSrunning() {
    logit "Checking for HDFS service status ..."
    HDFSPS=$(ps -ef|grep java|grep org.apache.hadoop.hdfs|grep -v grep|wc -l)
    if [ $HDFSPS -ge 1 ];then
      logit "Warning, you need to stop the Hadoop HDFS Service before optimizing anything [ERROR]"
      exit 222
    else
      logit "System clean with HDFS service in shutdown state, proceeding with optimization [OK]"
    fi
  }

  logit "**************** Warning ****************"
  logit "**************** Warning ****************"
  logit ""
  logit "You have chosen to optimize \"$1\" group, if you continue with this process"
  logit "The \"$ME\" will make permanent changes to your system, which may require"
  logit "an application restart and or a reboot to take effect, these changes CANNOT"
  logit "be undone by this tool, but will be logged."
  logit ""
  logit "**************** Warning ****************"
  logit "**************** Warning ****************"
  logit ""
  echo -n "$DATEFMT $SHORTHOST Are you positive you really want to continue ? <Y/N>: " | tee -a $LOGFILE
  read ans
  if [ "$ans" == "y" -o "$ans" == "Y" ];then
    chkHDFSrunning
    logit "Optimizing group \"$1\" now ..."
  else
    logit "Exiting optimize mode without any changes [OK]"
    exit 666
  fi
}

lineSeparator() {
  logit "--------------------------------------------------------------------"
}

lineEndSub() {
  logit "----------------------------------"
}

header(){
  subHeader
}

findXMLCfgFile () { 
  ## function parameters below:
  ## $1=description, $2=filename, $3=starting path
  ## debug ... logit "Find \"$1\" config file \"$2\" within \"$3\" "
  FILESEARCH=""
  LOOKFORFILE="" 

  FILESEARCH=$(find $3 -name $2|grep -v templates)
  for i in $FILESEARCH
  do
    if [ "$(grep property $i|wc -l)" -ge "2" ];then 
      LOOKFORFILE="$i" 
    ## else 
      ## logit "File found \"$i\" but it probably empty" 
    fi 
  done 
   
  if [ "$LOOKFORFILE" != "" ];then 
    logit "Found \"$1\" XML Config file:$LOOKFORFILE [OK]"
    if [ "$REPORTMODE" == "true" -a "$DebugCHK" != "" ];then   
      bldHTMLmsgTableRow "Found \"$1\" XML Config file: " "$LOOKFORFILE" "NA" "NA" 
    else 
      bldHTMLmsgTableRow "Found \"$1\" XML Config file: " "$LOOKFORFILE" 
    fi 
    return 0
  else
    logit "Could not find \"$2\" XML Config file in \"$3\" , searching other paths ..."

    OPT="/opt"
    ETC="/etc"
    USR="/usr"
    VAR="/var"

    case $3 in
    "$OPT")
      logit "Searching dir /etc /usr /var"
      FILESEARCH=$(find /etc -name $2|tail -1)
      if [ "$FILESEARCH" != "" ];then
        LOOKFORFILE=$FILESEARCH
        logit "Found \"$1\" XML Config file:$LOOKFORFILE [OK]"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableRow "Found \"$1\" XML Config file: " "$LOOKFORFILE" 
        fi
        return 0
      elif [ "$(find /usr -name $2|tail -1)" != "" ];then 
        LOOKFORFILE=$(find /usr -name $2|tail -1)
        logit "Found \"$1\" XML Config file:$LOOKFORFILE [OK]"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableRow "Found \"$1\" XML Config file: " "$LOOKFORFILE"
        fi
        return 0
      elif [ "$(find /var -name $2|tail -1)" != "" ];then 
        LOOKFORFILE=$(find /var -name $2|tail -1)
        logit "Found \"$1\" XML Config file:$LOOKFORFILE [OK]"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableRow "Found \"$1\" XML Config file: " "$LOOKFORFILE"
        fi
        return 0
      else 
        logit "$1 XML Config file:$2 NOT found [NOTED]"
        if [ "$REPORTMODE" == "true" ];then
          bldHTMLmsgTableRow "$1 XML Config file:" "$2 NOT found [NOTED]"
        fi
        return 0
      fi 
    ;;
    "$ETC")
      logit "Lookin /opt /usr /var for file:$2"
    ;;
    "$USR")
      logit "Lookin /opt /etc /var file:$2"
    ;;
    "$VAR")
      logit "Lookin /opt /etc /usr file:$2"
    ;;
    *)
      logit "Lookin /opt /etc /usr /var file:$2"
    ;;
    esac
    logit "$1 XML Config file:$2 NOT found <NOTED>"
    return 2 
  fi  
}

findPROPfile () { 
  ## function parameters below:
  ## $1=description, $2=filename, $3=starting path
  ## debug ... logit "Find \"$1\" config file \"$2\" within \"$3\" "

  PFILESEARCH=$(find $3 -name $2)

  if [ "$PFILESEARCH" != "" ];then
    logit "Found \"$1\" Config file:$PFILESEARCH [OK]"
    return 0
  else 
    logit "$1 Config file:$2 NOT found ! <ERROR>"
    return 2
  fi 
}

parseXML() {
  FILE=$1
  TYPE=$2
  OLD_IFS=$IFS
  IFS=$'\n'
  logit " ->$TYPE \"$FILE\" found has configuration:" 
  for line in $(xmllint --format $FILE)
  do
    if [ "$line" != "" ];then
      PROPCHK=$(echo $line|grep '<name>')
      if [ "$PROPCHK" != "" ];then
        PROPNAME=$(echo $PROPCHK|awk -F\> '{print $2}'|awk -F\< '{print $1}')
        PROPFLAG="true"
      elif [ "$PROPFLAG" == "true" ];then
        XMLVALUE=$(echo $line|grep '<value>'|awk -F\> '{print $2}'|awk -F\< '{print $1}')
        PROPFLAG="false"
        logit "  ->property \"$PROPNAME\" = \"$XMLVALUE\" " 
        if [ "$REPORTMODE" == "true" -a "$DebugCHK" == "" ];then
          bldHTMLmsgTableRow "$PROPNAME" "$XMLVALUE"
        fi 
      fi
    fi
  done
  IFS=$OLD_IFS
}

parsePROPERTIES() { 

  PROPERTYFILE=$1
  TYPE=$2

  OLD_IFS=$IFS
  IFS=$'\n'
  logit " ->$TYPE Config \"$PROPERTYFILE\" found has contents:"

  ## Check for an empty file first 
  EMPTYCHK=$(cat $PROPERTYFILE|egrep -v '^$|#')

  if [ "$EMPTYCHK" == "" ];then 
    logit "Empty file, only comments <NOTED>"
  else 
    for line in $(cat $PROPERTYFILE|egrep -v '^$|#') 
    do 
      if [ "$line" != "" ];then
        ## PROP=$(echo $line|cut -d= -f1)
        ## VAL=$(echo $line|cut -d= -f2)
        ## logit "  ->property \"$PROP\" = \"$VAL\" "
        logit "  ->$line"
      fi 
    done 
  fi 

  IFS=$OLD_IFS
}

emailHTMLfile() {
  ## internal use function 
  /usr/sbin/sendmail -t < message.html
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
  catIt "Subject: SAVVIS hadoop_perf.sh report:$HOSTNAME:$descCHK" 
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
  catIt ".e {background-color: #ccffcc; font-weight: bold; color: #000000;}"
  catIt ".h {background-color: #66ff00; font-weight: bold; color: #000000;}"
  catIt ".b {background-color: #00ffff; font-weight: bold; color: #000000;}"
  catIt ".v {background-color: #cccccc; color: #000000;}"
  catIt ".r {background-color: red; color: #000000;}"
  catIt ".g {background-color: #66ff00; color: #000000;}"
  catIt ".vr {background-color: #cccccc; text-align: right; color: #000000;}"
  catIt ".desc {background-color: #cccccc; text-align: center; color: #000000;}"
  catIt "img {float: right; border: 0px;}" 
  catIt "hr {width: 600px; background-color: #cccccc; border: 0px; height: 1px; color: #000000;}" 
  catIt "</style>" 
  catIt "<title>hadoop_perf.sh report</title><meta name=\"ROBOTS\" content=\"NOINDEX,NOFOLLOW,NOARCHIVE\"></head>" 
  catIt "<body><div class="center">" 
  catIt "" 
  catIt "<table border=\"0\" cellpadding=\"3\" width=\"600\">"
  catIt "<tbody><tr class=\"h\"><td>"
  catIt "<h1 class=\"p\">SAVVIS \"hadoop_perf\" report</h1>"
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
  logit "----------------SAVVIS $ME Script Running----------------"
  logit "*** Script Version : $SCRIPT_VER"
  logit "*** Script filename : \"$ME\" "
  logit "*** Script logfile : \"$LOGFILE\" "
  logit "*** Script report file : \"$REPTFILE\" "
  logit "*** Script mode run : $PARONE"
  logit "*** Script date run : $DDMMYY2"

  HADOOPCHK=$(rpm -qa|grep -i hadoop-[1-2])
  ### HADOOPCHK="hadoop-1.0.3-1.x86_64"

  if [ "$HADOOPCHK" == "" ];then
    logit "Hadoop Server does not seem to be installed, exiting! <ERROR>"
    exit 2
  else
    logit "*** Hadoop Server package \"$HADOOPCHK\" detected [OK]"
  fi

  logit "----------------SAVVIS $ME Script Running----------------"

  if [ "$REPORTMODE" == "true" ];then
    HOSTSYSDETAILS=$(uname -a)
    DATEFMTREPORT=$(date '+%b %d %Y %H:%M:%S')
    bldHTMLmsgTableHdrFile "" "Component" "Values" 
    bldHTMLmsgTableRow "Host System Details" "$HOSTSYSDETAILS"
    bldHTMLmsgTableRow "Report Date" "$DATEFMTREPORT"
    bldHTMLmsgTableRow "./$ME $PARONE $PARTWO $PARTHREE" "Script Version : $SCRIPT_VER<br> Script filename : \"$ME\"<br> Script logfile : \"$LOGFILE\"<br> Script report file : \"$REPTFILE\"<br> Script mode run : $PARONE<br> Script date run : $DDMMYY2<br> Hadoop Server package \"$HADOOPCHK\" detected<br> "
    ### no bldHTMLmsgTableFtrFile, done in autoDiscBaseSystem function 
  fi

}

hadoopHelp(){ 
  clear 
  logit "===== $ME Help Menu =====" 
  logit "" 
  logit "Usage:  \"./$ME\" [parameters]" 
  logit "" 
  logit "Where parameters allowed include:"
  logit "" 
  logit "Parameter 1: (required)"
  logit "  show		display configurations only"  
  logit "  debug	display configurations and recommend threshold change if neccessary" 
  logit "  report       display configurations and recommend threshold change if neccessary, email report"    
  logit "  optimize     change configurations based on thresholds set in debug mode"    
  logit "" 
  logit "Parameter 2: (required)"
  logit "  system	show system, debug system, or optimize system"
  logit "  hardware	show hardware, debug hardware, or optimize hardware"
  logit "  kernel	show kernel, debug kernel, or optimize kernel"
  logit "  java		show java, debug java, optimize java" 
  logit "  hadoop	show hadoop, debug hadoop, optimize hadoop" 
  logit "  mapreduce	show mapreduce, debug mapreduce, optimize mapreduce" 
  logit "  pig		show pig, debug pig, optimize pig" 
  logit "  hive		show hive, debug hive, optimize hive" 
  logit "  hbase	show hbase, debug hbase, optimize hbase" 
  logit "  oozie	show oozie, debug oozie, optimize oozie" 
  logit "  zookeeper	show zookeeper, debug zookeeper, optimize zookeeper" 
  logit "  flume	show flume, debug flume, optimize flume" 
  logit "  sqoop	show sqoop, debug sqoop, optimize sqoop" 
  logit "  impala	show impala, debug impala, optimize impala" 
  logit "" 
  logit "Parameter 3: (optional)" 
  logit "  report	will send an HTML formatted email report to configured"
  logit "  		recepient of all of the same output to command line"
  logit "Parameter 4: (optional)"
  logit "  Description of the test run to be sent in the HTML report via email"
  logit "" 
  logit "Example :" 
  logit "./$ME report kernel,hadoop,hive,flume" 
  logit "" 
  logit "Command would run script in \"report\" mode, and only show reported info" 
  logit "for the \"kernel,hadoop,hive and flume\" components" 
  logit "" 
  logit "./$ME optimize system,oozie" 
  logit "" 
  logit "Command would run script in \"optimize\" mode, but only for the \"system and oozie\" components" 
  logit "" 
  logit "NOTE : You must be logged in as the \"root\" user account to run this script" 
  logit "" 
  logit "===== $ME Help Menu =====" 
}

autoDiscBaseSystem(){

  ## Only checking basic kernel version now in debug mode ... 

  if [ "$1" == "show" ];then 
    logit "** Auto Discovery base system environment..."
    logit "Hadoop host :" "$HOSTNAME" 
    logit "Operating System :" "$OSTYPE"
    logit "Operating System ver :" "$OSVER"
    logit "Linux kernel ver :" "$KERNEL"
    ## lineEndSub

    if [ "$REPORTMODE" == "true" ];then
      ### No bldHTMLmsgTableHdrFile call, done in subHeader function
      bldHTMLmsgTableFtrFile
    fi 
  elif [ "$1" == "debug" ];then
    logit "** Auto Discovery base system environment..."
    logit "Hadoop host :" "$HOSTNAME"
    logit "Operating System :" "$OSTYPE"
    logit "Operating System ver :" "$OSVER"

    if [ "$REPORTMODE" == "true" ];then
      ### No bldHTMLmsgTableHdrFile call, done in subHeader function
      bldHTMLmsgTableFtrFile
    fi

    KERNELSHORT=$(echo $KERNEL|awk -F. '{print $1"."$2"."$3}'|awk -F"-" '{print $1}') 
    KERNEL_HADOOP=2.6.30

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Linux Kernel Debugged" "Component" "Value" "Optimal Value" "Optimized"
      ### done only for debugging kernel 
    fi 

    if [[ "$KERNELSHORT" > "$KERNEL_HADOOP" || "$KERNELSHORT" == "$KERNEL_HADOOP" ]];then
      optimizedVal="YES"
      logit "Linux kernel ver" "$KERNEL" "$KERNEL_HADOOP" "$optimizedVal"
    else 
      optimizedVal="NO"
      logit "Linux kernel ver" "$KERNEL" "$KERNEL_HADOOP" "$optimizedVal"
    fi 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
      ### done only for debugging kernel 
    fi

  elif [ "$1" == "optimize" ];then

    logit "** Auto Discovery base system environment..."
    logit "Hadoop host :" "$HOSTNAME"
    logit "Operating System :" "$OSTYPE"
    logit "Operating System ver :" "$OSVER"

    if [ "$REPORTMODE" == "true" ];then
      ### No bldHTMLmsgTableHdrFile call, done in subHeader function
      bldHTMLmsgTableFtrFile
    fi

    KERNELSHORT=$(echo $KERNEL|awk -F. '{print $1"."$2"."$3}'|awk -F"-" '{print $1}')
    KERNEL_HADOOP=2.6.30

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Linux Kernel Optimization State" "Component" "Value" "Optimal Value" "Optimized"
      ### done only for debugging kernel
    fi

    if [[ "$KERNELSHORT" > "$KERNEL_HADOOP" || "$KERNELSHORT" == "$KERNEL_HADOOP" ]];then
      # optimizedVal="OPTIMIZED"
      optimizedVal="YES"
      logit "Linux kernel ver" "$KERNEL" "$KERNEL_HADOOP" "$optimizedVal"
    else
      optimizedVal="[NOTED]"
      logit "Linux kernel ver" "$KERNEL" "Please upgrade to:$KERNEL_HADOOP" "$optimizedVal"
    fi

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
      ### done only for debugging kernel
    fi

    ## logit "Optimize autoDiscBaseSystem [TBD]" 
  fi 
  lineEndSub
}

autoDiscJava(){
  logit "** Auto Discovery checking java environment..."
  WHICHJAVA=$(which java 2>/dev/null)
  if [ "$?" != "0" ];then
    logit "Java JDK not installed !<ERROR>"
    exit 2 
  fi 
  JAVAVER=$($WHICHJAVA -version 2>&1>/dev/null|head -1)
  JAVAJDKENV=$($WHICHJAVA -version 2>&1>/dev/null|head -2|tail -1)
  JAVAJDKARCH=$($WHICHJAVA -version 2>&1>/dev/null|head -3|tail -1)
  
  JAVAVER_HADOOP="\"1.6.0_31\""
  JAVAJDKENV_HADOOP="SE"
  JAVAJDKARCH_HADOOP=64

  if [ "$1" == "show" ];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Java Environment" "Component" "Values"
    fi 

    logit "Version :" "$JAVAVER"
    logit "JDK Build Details :" "$JAVAJDKENV"
    logit "JDK Arch Details :" "$JAVAJDKARCH"

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi 
  elif [ "$1" == "debug" ];then
    JAVAVER1=$(echo $JAVAVER|awk '{print $3}')
    JAVAJDKENV1=$(echo $JAVAJDKENV|awk '{print $2}')
    JAVAJDKARCH1=$(echo $JAVAJDKARCH|awk '{print $3}'|cut -c1-2)

    if [ "$REPORTMODE" == "true" ];then
       bldHTMLmsgTableHdrFile "Java Environment" "Component" "Values" "Optimal Value" "Optimized"
    fi 

    if [[ "$JAVAVER1" > "$JAVAVER_HADOOP" || "$JAVAVER1" == "$JAVAVER_HADOOP" ]];then
      logit "Java version $JAVAVER1 meets the minimum hadoop java standard version number $JAVAVER_HADOOP [OK]"
      optimizedVal="YES" 
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java version: " "$JAVAVER1" "$JAVAVER_HADOOP" "$optimizedVal" 
    else 
      logit "Java version $JAVAVER1 does NOT the minimum hadoop java standard version number $JAVAVER_HADOOP [DEBUG]"
      optimizedVal="NO" 
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java version: " "$JAVAVER1" "$JAVAVER_HADOOP" "$optimizedVal" 
    fi 

    if [ "$JAVAJDKENV1" == "$JAVAJDKENV_HADOOP" ];then 
      logit "Java envivonment \"$JAVAJDKENV1\" meets the minimum hadoop \"$JAVAJDKENV_HADOOP\" edition [OK]"
      optimizedVal="YES"
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java envivonment " "$JAVAJDKENV1" "$JAVAJDKENV_HADOOP" "$optimizedVal"
    else 
      logit "Java envivonment \"$JAVAJDKENV1\" does NOT meets minimum hadoop \"$JAVAJDKENV_HADOOP\" edition [DEBUG]"
      optimizedVal="NO"
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java envivonment " "$JAVAJDKENV1" "$JAVAJDKENV_HADOOP" "$optimizedVal" 
    fi 

    if [ "$JAVAJDKARCH1" -eq "$JAVAJDKARCH_HADOOP" ];then
      logit "Java architecture \"$JAVAJDKARCH1\" bit meets required hadoop \"$JAVAJDKARCH_HADOOP\" bit java arch [OK]"
      optimizedVal="YES"
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java architecture: " "$JAVAJDKARCH1 bit" "$JAVAJDKARCH_HADOOP bit" "$optimizedVal"
    else 
      logit "Java architecture \"$JAVAJDKARCH1\" bit does NOT meet required hadoop \"$JAVAJDKARCH_HADOOP\" bit java arch [DEBUG]"
      optimizedVal="NO"
      ## forcing this function call becasue logit above is so different 
      bldHTMLmsgTableRow "Java architecture: " "$JAVAJDKARCH1" "$JAVAJDKARCH_HADOOP" "$optimizedVal"
    fi 

    if [ "$REPORTMODE" == "true" ];then
       bldHTMLmsgTableFtrFile 
    fi
    
  fi 

  lineEndSub
}

autoDiscHadoop(){ 
  logit "** Auto Discovery Hadoop config running..."

  if [ "$1" == "show" ];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop HDFS Settings" "Component" "Value"
    fi
    
    WHICHHADOOP=$(which hadoop)
    if [ "$WHICHHADOOP" != "" ];then 
      logit "Hadoop binary location : $WHICHHADOOP"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "Hadoop binary location :" "$WHICHHADOOP"
      fi 
      OLD_IFS=$IFS
      IFS=$'\n'
      CTR=1
      for i in $($WHICHHADOOP version)
      do 
        logit "$i"
        if [ "$REPORTMODE" == "true" ];then
          if [ "$CTR" == "1" ];then 
	    bldHTMLmsgTableRow "Hadoop Version" "$i"
          elif [ "$CTR" == "2" ];then
	    bldHTMLmsgTableRow "Subversion Info" "$i"
          elif [ "$CTR" == "3" ];then
	    bldHTMLmsgTableRow "Vendor Info" "$i"
          fi 
        fi 
        CTR=$(expr $CTR + 1)
      done 
      IFS=$OLD_IFS
    else 
      logit "Hadoop binary not located ! <ERROR>"
      if [ "$REPORTMODE" == "true" ];then
         bldHTMLmsgTableRow "Hadoop binary location :" "Hadoop binary not located ! **ERROR**"
      fi 
    fi 

    HADOOPSTATUS=$(ps -ef|egrep -v 'grep|hadoop_perf.sh'|grep -i hadoop|wc -l)
    if [ $HADOOPSTATUS -ge 1 ];then 
      logit "Hadoop status : running"
      if [ "$REPORTMODE" == "true" ];then
         bldHTMLmsgTableRow "Hadoop status :" "running"
      fi 
    else 
      logit "Hadoop status : stopped"
      if [ "$REPORTMODE" == "true" ];then
         bldHTMLmsgTableRow "Hadoop status :" "stopped"
      fi
    fi 
    getUsrDetails "Hadoop HDFS" "HDFS"

    lineEndSub

    ##findXMLCfgFile "hadoop" "core-site.xml" "/etc/hadoop/conf.cloudera.hdfs1" 
    findXMLCfgFile "hadoop" "core-site.xml" "/etc/hadoop" 
    if [ "$?" == "0" ];then 
      parseXML $LOOKFORFILE "hadoop"
    fi 

    ### we know that the hdfs-site.xml contains the value 'dfs.namenode.name.dir'
    ##DIR1=$(dirname $(find /etc/hadoop -name hdfs-site.xml |xargs grep dfs.namenode.name.dir|awk '{print $1}'|awk -F: '{print $1}'))
    findXMLCfgFile "hadoop" "hdfs-site.xml" "/etc/hadoop" 
    if [ "$?" == "0" ];then
      parseXML $LOOKFORFILE "hadoop"
    fi 
    lineEndSub

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "debug" ];then 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop HDFS Settings Debugged" "Component" "Value" "Optimal Value" "Optimized"
    fi

    ### we know that the hdfs-site.xml contains the value 'dfs.namenode.name.dir'
    ##DIR1=$(dirname $(find /etc/hadoop -name hdfs-site.xml |xargs grep dfs.namenode.name.dir|awk '{print $1}'|awk -F: '{print $1}'))
    findXMLCfgFile "hadoop" "hdfs-site.xml" "/etc/hadoop" 
    if [ "$?" == "0" ];then
      parseXML $LOOKFORFILE "hadoop"
    fi

    dfs_replication_HADOOP=3
    dfs_replication_CURRENT=$(grep -A1 dfs.replication $LOOKFORFILE|grep '<value>'|awk -F\> '{print $2}'|awk -F\< '{print $1}'|tail -1)

    if [ "$dfs_replication_CURRENT" != "" ];then 
      if [ $dfs_replication_CURRENT -ge $dfs_replication_HADOOP ];then 
        optimizedVal="YES" 
      else 
        optimizedVal="NO" 
      fi 
      logit "File:$LOOKFORFILE variable \"dfs.replication\"" "$dfs_replication_CURRENT" "$dfs_replication_HADOOP" "$optimizedVal"
    else 
      logit "File:$LOOKFORFILE variable \"dfs.replication\"" "was not found[NOTED]" "NA" "NA"
    fi 

    lineEndSub

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "optimize" ];then 
    logit "Hadoop Optmize" 
  fi 
 
}

autoDiscMapReduce(){
  logit "** Auto Discovery MapReduce Configuration..." 
  MAPREDSTATUS=$(ps -ef|egrep -v 'grep|hadoop_perf.sh'|grep -i mapred|wc -l)

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableHdrFile "MapReduce Settings" "Component" "Value"
  fi

  if [ $MAPREDSTATUS -ge 1 ];then
    logit "MapReduce status : running"
  else
    logit "MapReduce status : stopped"
  fi

  getUsrDetails "Hadoop MapReduce" "MapReduce"

  findXMLCfgFile "mapreduce" "mapred-site.xml" "/etc" 
  if [ "$?" == "0" ];then
    parseXML $LOOKFORFILE "mapreduce"
  fi 

  findXMLCfgFile "mapreduce" "mapred-queue-acls.xml" "/etc" 
  if [ "$?" == "0" ];then
    parseXML $LOOKFORFILE "mapreduce"
  fi

  if [ "$REPORTMODE" == "true" ];then
    bldHTMLmsgTableFtrFile
  fi

  lineEndSub
}

createHadoopReportFile(){
  logit "Creating Hadoop Env Report file" 
  lineEndSub
}

emailHadoopReport(){
  logit "Creating and sending Hadoop email report"
  lineEndSub
} 

chkCfgExist(){
  logit "Checking existing configuration"
}

displayHardwareConfig(){

  ## network
  enableJumboFramesMTUeth0 () {
    mtuExistVal=$(ifconfig -a |grep MTU | grep -i -v loopback|awk '{print $5}'|cut -d: -f2)
    mtuExistFileVal=$(grep MTU /etc/sysconfig/network-scripts/ifcfg-eth0|awk -F= '{print $2}'|sed 's/"//g')
    mtuExistVal_HADOOP=9000
    if [ "$1" == "show" ];then
      logit "Existing MTU for eth0 :" "\"$mtuExistVal\""
    elif [ "$1" == "debug" ];then
      if [ "$mtuExistVal" == "$mtuExistVal_HADOOP" ];then
        optimizedVal="YES"
        logit "Existing MTU for eth0 " "$mtuExistVal" "$mtuExistVal_HADOOP" "$optimizedVal" 
      else
        optimizedVal="NO"
        logit "Existing MTU for eth0 " "$mtuExistVal" "$mtuExistVal_HADOOP" "$optimizedVal" 
      fi
    elif [ "$1" == "optimize" ];then
      if [ "$mtuExistVal" == "$mtuExistVal_HADOOP" ];then
        optimizedVal="YES"
        logit "Existing MTU for eth0 " "$mtuExistVal" "$mtuExistVal_HADOOP" "$optimizedVal" 
      else
        optimizedVal="YES"
        logit "Existing MTU for eth0 " "$mtuExistVal" "$mtuExistVal_HADOOP" "$optimizedVal"
	/sbin/ifconfig eth0 mtu $mtuExistVal_HADOOP up
 	if [ "$mtuExistFileVal" != "" ];then 
          # Enable Jumbo Frames - MTU = 9000
          /bin/sed -i 's/^MTU=\"1500\"/MTU=\"'"$mtuExistVal_HADOOP"'\"/g' /etc/sysconfig/network-scripts/ifcfg-eth0
        else 
          # Enable Jumbo Frames - MTU = 9000
	  echo "MTU=9000" >> /etc/sysconfig/network-scripts/ifcfg-eth0
        fi 
      fi
    fi
  }

  enableReadAheadBuffers() {
    diskRA_HADOOP=8192
    diskDevs=$(ls /dev/sd?)
    if [ "$1" == "show" ];then
      for dev in $diskDevs
      do
        diskRa=$(blockdev --report $dev|tail -1|awk '{print $2}')
        logit "Disk \"$dev\" read ahead value :" \"$diskRa\"
      done
    elif [ "$1" == "debug" ];then
      for dev in $diskDevs
      do
        diskRa=$(blockdev --report $dev|tail -1|awk '{print $2}')
        if [ "$diskRa" == "$diskRA_HADOOP" ];then
          optimizedVal="YES"
          logit "Disk \"$dev\" read ahead value"  "$diskRa" "$diskRA_HADOOP" "$optimizedVal"
        else
          optimizedVal="NO"
          logit "Disk \"$dev\" read ahead value"  "$diskRa" "$diskRA_HADOOP" "$optimizedVal"
        fi
      done
    elif [ "$1" == "optimize" ];then
      for dev in $diskDevs
      do
        diskRa=$(blockdev --report $dev|tail -1|awk '{print $2}')
        if [ "$diskRa" == "$diskRA_HADOOP" ];then
          optimizedVal="YES"
          logit "Disk \"$dev\" read ahead value"  "$diskRa" "$diskRA_HADOOP" "$optimizedVal"
        else
          optimizedVal="YES"
          logit "Disk \"$dev\" read ahead value"  "$diskRa" "$diskRA_HADOOP" "$optimizedVal"
          blockdev --setra 8192 $dev
        fi
      done
    fi
  }

  logit "** Auto Discovery Hardware Configuration for Hadoop Node..."
  HOSTNAME=$(uname -n)
  CPUCOUNT=$(cat /proc/cpuinfo | grep processor |wc -l)
  CPUTYPE=$(cat /proc/cpuinfo|grep "model name"|awk -F: '{print $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
  MEMTOTGB=$(free -g -t|grep 'Total'|awk '{print $2}'|tr -d ' ')
  MEMFREEGB=$(free -g -t|grep 'Total'|awk '{print $4}'|tr -d ' ')
  SWAPUSED=$(free -g|grep Swap|awk '{print $3}')

  # Hadoop Optimal Hardware Settings ...
  CPUCOUNT_HADOOP=2
  MEMTOTGB_HADOOP=4
  SWAPUSED_HADOOP=4

  ## $1 show or debug 
  if [ "$1" == "show" ];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Hardware Settings" "Hardware Component" "Values"
    fi

    logit "CPU Cores Installed :" "$CPUCOUNT"
    logit "CPU Type :" "$CPUTYPE"
    logit "Memory Installed :" "$MEMTOTGB GB"
    logit "Memory Currently Free :" "$MEMFREEGB GB"
    logit "Swap Used :" "$SWAPUSED"

    for mnt in $(ls /|grep data)
    do  
      DATAMNT=$(mount|grep $mnt|awk '{print $3}')
      if [ "$DATAMNT" != "" ];then 
        MNTTYPE=$(mount|grep data|awk '{print $5}')
        DISKTOT=$(df -h $DATAMNT|tail -1|awk '{print $1}'|tr -d ' ') 
        DISKFREE=$(df -h $DATAMNT|tail -1|awk '{print $3}'|tr -d ' ') 
        logit "Mount \"$DATAMNT\" is type :"  "\"$MNTTYPE\", size \"$DISKTOT\", has \"$DISKFREE\" free space"
      fi 
    done

    for eth in $(ip link show|egrep -iv 'loopback|ether'|grep eth|awk '{print $2}'|awk -F: '{print $1}')
    do 
      NICSPEED=$(ethtool $eth|grep Speed|awk '{print $2}')
      NICDUPLX=$(ethtool $eth|grep Duplex|awk '{print $1 $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
      # NICTXERR=$(ethtool -S $eth|grep "pkts tx err:"|awk '{print $4}')
      NICTXERR=$(ethtool -S $eth|grep tx_err|awk '{print $2}')
      # NICRXERR=$(ethtool -S $eth|grep "pkts rx err:"|awk '{print $4}')
      NICRXERR=$(ethtool -S $eth|grep rx_err|awk '{print $2}')
      logit "NIC \"$eth\" configured with speed :" "\"$NICSPEED\", and \"$NICDUPLX\""
      logit "NIC \"$eth\" err check :" "transmitt errors = \"$NICTXERR\", receive errors = \"$NICRXERR\""
    done 

    lineEndSub

    enableJumboFramesMTUeth0 show 

    lineEndSub

    enableReadAheadBuffers show 

    bldHTMLmsgTableFtrFile

    lineEndSub
  elif [ "$1" == "debug" ];then 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Hardware Settings" "Hardware Component" "Values" "Optimal Value" "Optimized"
    fi

    if [ "$CPUCOUNT" -ge "$CPUCOUNT_HADOOP" ];then
      logit "CPU Cores Installed : $CPUCOUNT is already at or above optimal number [OK]"
      optimizedVal="YES"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "CPU Cores Installed :" "$CPUCOUNT" "$CPUCOUNT_HADOOP" "$optimizedVal"
      fi 
    else
      logit "CPU Cores Installed : $CPUCOUNT NOT optimal, \"$CPUCOUNT_HADOOP\" is optimal value [DEBUG]"
      optimizedVal="NO"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "CPU Cores Installed :" "$CPUCOUNT" "$CPUCOUNT_HADOOP" "$optimizedVal"
      fi 
    fi

    logit "CPU Type : $CPUTYPE"
    if [ "$REPORTMODE" == "true" ];then
      optimizedVal="NO"
      bldHTMLmsgTableRow "CPU Type :" "$CPUTYPE" "NA" "NA"
    fi

    if [ "$MEMTOTGB" -ge "$MEMTOTGB_HADOOP" ];then
      logit "Memory Installed : $MEMTOTGB GB is already at or above optimal amount [OK]"
      optimizedVal="YES"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "Memory Installed :" "$MEMTOTGB" "$MEMTOTGB_HADOOP" "$optimizedVal"
      fi 
    else
      logit "Memory Installed : $MEMTOTGB GB NOT optimal, \"$MEMTOTGB_HADOOP\" is optimal amount [DEBUG]"
      optimizedVal="NO"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "Memory Installed :" "$MEMTOTGB" "$MEMTOTGB_HADOOP" "$optimizedVal"
      fi 
    fi

    logit "Memory Currently Free : $MEMFREEGB GB"
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "Memory Currently Free :" "$MEMFREEGB" "NA" "NA"
    fi

    if [ "$SWAPUSED" -le "$SWAPUSED_HADOOP" ];then
      logit "Swap Used : $SWAPUSED GB is already at or less than optimal amount [OK]"
      optimizedVal="YES"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "Swap Used :" "$SWAPUSED" "$SWAPUSED_HADOOP" "$optimizedVal"
      fi 
    else
      logit "Swap Used : $SWAPUSED GB NOT optimal, \"$SWAPUSED_HADOOP\" is optimal amount [DEBUG]"
      optimizedVal="NO"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "Swap Used :" "$SWAPUSED" "$SWAPUSED_HADOOP" "$optimizedVal"
      fi 
    fi

    DISKFREE_HADOOP="10" 
    for mnt in $(ls /|grep data)
    do
      DATAMNT=$(mount|grep $mnt|awk '{print $3}')
      if [ "$DATAMNT" != "" ];then
        MNTTYPE=$(mount|grep data|awk '{print $5}')
        DISKTOT=$(df -h $DATAMNT|tail -1|awk '{print $1}'|tr -d ' ')
        DISKFREE=$(df -h $DATAMNT|tail -1|awk '{print $3}'|tr -d ' ')
        DISKFREE=$(echo $DISKFREE|awk -F"G" '{print $1}'|awk -F. '{print $1}')
        if [ $DISKFREE -gt $DISKFREE_HADOOP ];then 
	  optimizedVal="YES"
          logit "Mount \"$DATAMNT\" is type \"$MNTTYPE\" " "$DISKFREE GB free space" "$DISKFREE_HADOOP GB required" "$optimizedVal" 
        else 
	  optimizedVal="NO"
          logit "Mount \"$DATAMNT\" is type \"$MNTTYPE\" " "$DISKFREE GB free space" "$DISKFREE_HADOOP GB required" "$optimizedVal" 
	fi 
      fi 
    done

    for eth in $(ip link show|egrep -iv 'loopback|ether'|grep eth|awk '{print $2}'|awk -F: '{print $1}')
    do
      NICSPEED=$(ethtool $eth|grep Speed|awk '{print $2}')
      NICDUPLX=$(ethtool $eth|grep Duplex|awk '{print $1 $2}'|sed -e 's/^ *//g' -e 's/ *$//g')
      # NICTXERR=$(ethtool -S $eth|grep "pkts tx err:"|awk '{print $4}')
      NICTXERR=$(ethtool -S $eth|grep tx_err|awk '{print $2}')
      # NICRXERR=$(ethtool -S $eth|grep "pkts rx err:"|awk '{print $4}')
      NICRXERR=$(ethtool -S $eth|grep rx_err|awk '{print $2}')
      logit "NIC \"$eth\" configured with \"$NICSPEED\", and \"$NICDUPLX\" "
      logit "NIC \"$eth\" transmitt errors = \"$NICTXERR\", receive errors = \"$NICRXERR\" "
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "NIC \"$eth\" configured with :" "\"$NICSPEED\", and \"$NICDUPLX\"" "NA" "NA" 
        bldHTMLmsgTableRow "NIC \"$eth\" err check :" "transmitt errors = \"$NICTXERR\", receive errors = \"$NICRXERR\"" "NA" "NA"
      fi
    done

    lineEndSub

    enableJumboFramesMTUeth0 debug

    lineEndSub

    enableReadAheadBuffers debug

    bldHTMLmsgTableFtrFile

    lineEndSub

  elif [ "$1" == "optimize" ];then

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Hardware Settings" "Hardware Component" "Values" "Optimal Value" "Optimized"
    fi
   
    enableJumboFramesMTUeth0 optimize

    lineEndSub

    enableReadAheadBuffers optimize

    bldHTMLmsgTableFtrFile

    lineEndSub
  fi 
}

### internal function used by displayLinuxKernelParm
showCurrentKernVal() { 
  ## $1 is the name of the kernel parmater 
  ## $2 == if force, display EMPTY
  currentKernVal=$(sysctl -a|grep -a $1|awk -F= '{print $2}'|tr -d ' ')
  if [ "$currentKernVal" != "" ];then 
    logit "$1 :" "$currentKernVal" 
  else 
   if [ "$2" == "force" ];then
      logit "$1" "EMPTY" 
    else
      logit "$1 :" "NOT Found ! <NOTED>"
    fi 
  fi 
} 

getCurrentKernVal() {
  ## $1 is the name of the kernel parmater
  currentKernVal=$(sysctl -a|grep -a $1|awk -F= '{print $2}'|tr -d ' ')

  if [ "$1" == "kernel.sem" ];then 
    currentKernVal=$(sysctl -a|grep -a $1|awk -F= '{print $2}'|tr -d ' '|sed 's/,/\ /g')
  fi 
}

debugCurrentKernVal() {
  ## paramter $1 = name of the kernel parmater
  ## param $2 = kernel param optimal value 
  ## param $3 = if exists, force to show as value 'EMPTY'  
  
  getCurrentKernVal "$1" 
  currentValraw=$(echo $currentKernVal|tr -d ' ')
  optValraw=$(echo $2|tr -d ' ')
  
  if [ "$currentValraw" == "$optValraw" ];then
    optimizedVal="YES"
    logit "$1" "$currentKernVal" "$2" "$optimizedVal"
  elif [ "$currentKernVal" == "" ];then
    if [ "$3" == "force" ];then 
      logit "$1" "EMPTY" "$2" "NO"
    else 
      logit "$1" "NOT Found ! <NOTED>" "NA" "NA"
    fi 
  else
    optimizedVal="NO" 
    logit "$1" "$currentKernVal" "$2" "$optimizedVal"
  fi
}

optimKern(){
  # $1 will be the kernel parameter name (exactly as defined by 'sysctl -a')
  # $2 will be the optimal value to set it too

  getCurrentKernVal "$1"
  currentValraw=$(echo $currentKernVal|tr -d ' ')
  optValraw=$(echo $2|tr -d ' ')
  #DATEFMT2=$(date '+%m%d%y.%H%M%S')
  DATEFMT2=$(date '+%m-%d-%y.%H%M')

  if [ "$currentValraw" == "$optValraw" ];then
    optimizedVal="YES"
    ## logit "Kernel parameter \"$1\" = $currentKernVal, already optimal value [OK]"
    logit "$1" "$currentKernVal" "$2" "$optimizedVal"
  elif [ "$currentKernVal" == "" ];then
    logit "$1 :" "NOT Found ! <NOTED>" "NA" "NA"
    if [ "$3" == "force" ];then 
      backUpConfigFile "/etc/sysctl.conf"
      echo "### Modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /etc/sysctl.conf
      echo "$1=$2" >> /etc/sysctl.conf
      /sbin/sysctl -n -e -q -p
      optimizedVal="OPTIMIZE"
      logit "$1" "$currentKernVal" "$2" "$optimizedVal"
    fi 
  else
    backUpConfigFile "/etc/sysctl.conf"
    echo "### Modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /etc/sysctl.conf
    echo "$1=$2" >> /etc/sysctl.conf
    /sbin/sysctl -n -e -q -p
    optimizedVal="OPTIMIZE"
    ## logit "Kernel parameter \"$1\" = $currentKernVal, changed to \"$2\" [$optimizedVal]"
    logit "$1" "$currentKernVal" "$2" "$optimizedVal"
  fi
}

displayLinuxKernelParm(){

  ### internal function only 
  sysTransparentPages() {

    if [ "$RHVER" == "6" ];then

      hugepage_enab_status=$(cat /sys/kernel/mm/redhat_transparent_hugepage/enabled|awk -F[ '{print $2}'|awk -F] '{print $1}')
      hugepage_defrag_status=$(cat /sys/kernel/mm/redhat_transparent_hugepage/defrag|awk -F[ '{print $2}'|awk -F] '{print $1}')
      khugepaged_status=$(cat /sys/kernel/mm/redhat_transparent_hugepage/khugepaged/defrag|awk -F[ '{print $2}'|awk -F] '{print $1}')

      hugepage_enab_status_HADOOP=never
      hugepage_defrag_status_HADOOP=never
      khugepaged_status_HADOOP=no

      if [ "$1" == "show" ];then
        logit "RHEL6 Kernel parameter hugepage enabled status:" "$hugepage_enab_status"
        logit "RHEL6 Kernel parameter hugepage defrag status:" "$hugepage_defrag_status"
        logit "RHEL6 Kernel parameter khugepaged_status status:" "$khugepaged_status"
      elif [ "$1" == "debug" ];then
        if [ "$hugepage_enab_status" == "$hugepage_enab_status_HADOOP" ];then
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage enabled\"" "$hugepage_enab_status" "$hugepage_enab_status_HADOOP" "YES"
        else
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage enabled\"" "$hugepage_enab_status" "$hugepage_enab_status_HADOOP" "NO"
        fi

        if [ "$hugepage_defrag_status" == "$hugepage_defrag_status_HADOOP" ];then
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage defrag\"" "$hugepage_defrag_status" "$hugepage_defrag_status_HADOOP" "YES"
        else
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage defrag\"" "$hugepage_defrag_status" "$hugepage_defrag_status_HADOOP" "NO"
        fi

        if [ "$khugepaged_status" == "$khugepaged_status_HADOOP" ];then
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage khugepaged\"" "$khugepaged_status" "$khugepaged_status_HADOOP" "YES"
        else
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage khugepaged\"" "$khugepaged_status" "$khugepaged_status_HADOOP" "NO"
        fi

      elif [ "$1" == "optimize" ];then

        if [ "$hugepage_enab_status" == "$hugepage_enab_status_HADOOP" ];then
          optimizedVal="YES"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage enabled\"" "$hugepage_enab_status" "$hugepage_enab_status_HADOOP" "$optimizedVal" 
        else
	  optimizedVal="OPTIMIZE"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage enabled\"" "$hugepage_enab_status" "$hugepage_enab_status_HADOOP" "$optimizedVal" 
          echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
        fi

        if [ "$hugepage_defrag_status" == "$hugepage_defrag_status_HADOOP" ];then
          optimizedVal="YES"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage defrag\"" "$hugepage_defrag_status" "$hugepage_defrag_status_HADOOP" "$optimizedVal"
        else
	  optimizedVal="OPTIMIZE"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage defrag\"" "$hugepage_defrag_status" "$hugepage_defrag_status_HADOOP" "$optimizedVal"
          echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag
        fi

        if [ "$khugepaged_status" == "$khugepaged_status_HADOOP" ];then
          optimizedVal="YES"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage khugepaged\"" "$khugepaged_status" "$khugepaged_status_HADOOP" "$optimizedVal"
        else
	  optimizedVal="OPTIMIZE"
          logit "RHEL6 Kernel parameter \"redhat_transparent_hugepage khugepaged\"" "$khugepaged_status" "$khugepaged_status_HADOOP" "$optimizedVal"
          echo no > /sys/kernel/mm/redhat_transparent_hugepage/khugepaged/defrag
        fi
      fi
    fi 
  }

  logit "** Auto Discovery Hadoop related linux kernel values..."
  ## $1 = show, debug or optimize 
  ## $2 = report or "" 

  ## these are the best practice hadoop settings *_HADOOP 
  net_ipv4_ip_forward_HADOOP=0
  net_ipv4_conf_default_rp_filter_HADOOP=1
  net_ipv4_conf_default_accept_source_route_HADOOP=0
  kernel_sysrq_HADOOP=0
  kernel_core_uses_pid_HADOOP=1
  kernel_msgmnb_HADOOP=65536
  kernel_msgmax_HADOOP=65536
  kernel_shmmax_HADOOP=68719476736
  kernel_shmall_HADOOP=4294967296
  net_core_rmem_default_HADOOP=262144
  net_core_rmem_max_HADOOP=16777216
  net_core_wmem_default_HADOOP=262144
  net_core_wmem_max_HADOOP=16777216
  net_core_somaxconn_HADOOP=1000
  fs_file_max_HADOOP=6815744
  net_ipv4_tcp_timestamps_HADOOP=0
  net_ipv4_tcp_sack_HADOOP=1
  net_ipv4_tcp_window_scaling_HADOOP=1
  kernel_shmmni_HADOOP=4096
  # kernel_sem_HADOOP='250 32000 100 128'
  kernel_sem_HADOOP='250 32000 32 128'
  fs_aio_max_nr_HADOOP=1048576
  net_ipv4_tcp_rmem_HADOOP='4096 262144 16777216'
  net_ipv4_tcp_wmem_HADOOP='4096 262144 16777216'
  net_ipv4_tcp_syncookies_HADOOP=0
  sunrpc_tcp_slot_table_entries_HADOOP=128
  vm_dirty_background_ratio_HADOOP=1
  fs_inotify_max_user_instances_HADOOP=8192
  fs_epoll_max_user_instances_HADOOP=4096 # RHEL6 Only 
  
  if [ "$1" == "show" ];then 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Kernel Parameters" "Kernel Parameters" "Values"
    fi 

    ### net.ipv4.ip_forward
    showCurrentKernVal net.ipv4.ip_forward

    ### net.ipv4.conf.default.rp_filter  
    showCurrentKernVal net.ipv4.conf.default.rp_filter

    ### net.ipv4.conf.default.accept_source_route
    showCurrentKernVal net.ipv4.conf.default.accept_source_route

    ### kernel.sysrq
    showCurrentKernVal kernel.sysrq

    ### kernel.core_uses_pid 
    showCurrentKernVal kernel.core_uses_pid

    ### kernel.msgmnb
    showCurrentKernVal kernel.msgmnb

    ### kernel.msgmax
    showCurrentKernVal kernel.msgmax

    ### kernel.shmmax
    showCurrentKernVal kernel.shmmax 

    ### kernel.shmall
    showCurrentKernVal kernel.shmall

    ### net.core.rmem_default 
    showCurrentKernVal net.core.rmem_default 

    ### net.core.rmem_max 
    showCurrentKernVal net.core.rmem_max

    ### net.core.wmem_default
    showCurrentKernVal net.core.wmem_default

    ### net.core.wmem_max 
    showCurrentKernVal net.core.wmem_max 

    ### net.core.somaxconn 
    showCurrentKernVal net.core.somaxconn 

    ### fs.file-max 
    showCurrentKernVal fs.file-max

    ### net.ipv4.tcp_timestamps
    showCurrentKernVal net.ipv4.tcp_timestamps

    ### net.ipv4.tcp_sack 
    showCurrentKernVal net.ipv4.tcp_sack

    ### net.ipv4.tcp_window_scaling 
    showCurrentKernVal net.ipv4.tcp_window_scaling

    ### kernel.shmmni
    showCurrentKernVal kernel.shmmni

    ### kernel.sem
    showCurrentKernVal kernel.sem

    ### fs.aio-max-nr 
    showCurrentKernVal fs.aio-max-nr

    ### net.ipv4.tcp_rmem
    showCurrentKernVal net.ipv4.tcp_rmem

    ### net.ipv4.tcp_wmem
    showCurrentKernVal net.ipv4.tcp_wmem

    ### net.ipv4.tcp_syncookies
    showCurrentKernVal net.ipv4.tcp_syncookies

    ### sunrpc.tcp_slot_table_entries
    showCurrentKernVal sunrpc.tcp_slot_table_entries 

    ### vm.dirty_background_ratio
    showCurrentKernVal vm.dirty_background_ratio

    ### fs.inotify.max_user_instances
    showCurrentKernVal fs.inotify.max_user_instances

    ### RHEL6 only, transparent pages
    sysTransparentPages show 

    if [ "$RHVER" == "6" ];then
      showCurrentKernVal fs.epoll.max_user_instances force
    fi 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "debug" ];then

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Kernel Parameters Debugged" "Kernel Parameters" "Values" "Optimal Value" "Optimized"
    fi

    debugCurrentKernVal net.ipv4.ip_forward $net_ipv4_ip_forward_HADOOP

    debugCurrentKernVal net.ipv4.conf.default.rp_filter $net_ipv4_conf_default_rp_filter_HADOOP

    debugCurrentKernVal net.ipv4.conf.default.accept_source_route $net_ipv4_conf_default_accept_source_route_HADOOP

    debugCurrentKernVal kernel.sysrq $kernel_sysrq_HADOOP

    debugCurrentKernVal kernel.core_uses_pid $kernel_core_uses_pid_HADOOP
  
    debugCurrentKernVal kernel.msgmnb $kernel_msgmnb_HADOOP

    debugCurrentKernVal kernel.msgmax $kernel_msgmax_HADOOP
    
    debugCurrentKernVal kernel.shmmax $kernel_shmmax_HADOOP

    debugCurrentKernVal kernel.shmall $kernel_shmall_HADOOP

    debugCurrentKernVal net.core.rmem_default $net_core_rmem_default_HADOOP

    debugCurrentKernVal net.core.rmem_max $net_core_rmem_max_HADOOP

    debugCurrentKernVal net.core.wmem_default $net_core_wmem_default_HADOOP

    debugCurrentKernVal net.core.wmem_max $net_core_wmem_max_HADOOP

    debugCurrentKernVal net.core.somaxconn $net_core_somaxconn_HADOOP
  
    debugCurrentKernVal fs.file-max $fs_file_max_HADOOP

    debugCurrentKernVal net.ipv4.tcp_timestamps $net_ipv4_tcp_timestamps_HADOOP

    debugCurrentKernVal net.ipv4.tcp_sack $net_ipv4_tcp_sack_HADOOP

    debugCurrentKernVal net.ipv4.tcp_window_scaling $net_ipv4_tcp_window_scaling_HADOOP

    debugCurrentKernVal kernel.shmmni $kernel_shmmni_HADOOP

    debugCurrentKernVal kernel.sem "$kernel_sem_HADOOP" 

    debugCurrentKernVal fs.aio-max-nr $fs_aio_max_nr_HADOOP

    debugCurrentKernVal net.ipv4.tcp_rmem "$net_ipv4_tcp_rmem_HADOOP"

    debugCurrentKernVal net.ipv4.tcp_wmem "$net_ipv4_tcp_wmem_HADOOP"

    debugCurrentKernVal net.ipv4.tcp_syncookies $net_ipv4_tcp_syncookies_HADOOP

    debugCurrentKernVal sunrpc.tcp_slot_table_entries $sunrpc_tcp_slot_table_entries_HADOOP

    debugCurrentKernVal vm.dirty_background_ratio $vm_dirty_background_ratio_HADOOP

    debugCurrentKernVal fs.inotify.max_user_instances $fs_inotify_max_user_instances_HADOOP

    ### RHEL6 only, transparent pages
    sysTransparentPages debug

    if [ "$RHVER" == "6" ];then
      debugCurrentKernVal fs.epoll.max_user_instances $fs_epoll_max_user_instances_HADOOP force 
    fi

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "optimize" ];then

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related Kernel Parameters" "Component" "Value" "Optimal Value" "Optimization"
    fi

    optimKern net.ipv4.ip_forward $net_ipv4_ip_forward_HADOOP

    optimKern net.ipv4.conf.default.rp_filter $net_ipv4_conf_default_rp_filter_HADOOP

    optimKern net.ipv4.conf.default.accept_source_route $net_ipv4_conf_default_accept_source_route_HADOOP

    optimKern kernel.sysrq $kernel_sysrq_HADOOP

    optimKern kernel.core_uses_pid $kernel_core_uses_pid_HADOOP

    optimKern kernel.msgmnb $kernel_msgmnb_HADOOP

    optimKern kernel.msgmax $kernel_msgmax_HADOOP

    optimKern kernel.shmmax $kernel_shmmax_HADOOP

    optimKern kernel.shmall $kernel_shmall_HADOOP

    optimKern net.core.rmem_default $net_core_rmem_default_HADOOP

    optimKern net.core.rmem_max $net_core_rmem_max_HADOOP

    optimKern net.core.wmem_default $net_core_wmem_default_HADOOP

    optimKern net.core.wmem_max $net_core_wmem_max_HADOOP

    optimKern net.core.somaxconn $net_core_somaxconn_HADOOP

    optimKern fs.file-max $fs_file_max_HADOOP

    optimKern net.ipv4.tcp_timestamps $net_ipv4_tcp_timestamps_HADOOP

    optimKern net.ipv4.tcp_sack $net_ipv4_tcp_sack_HADOOP

    optimKern net.ipv4.tcp_window_scaling $net_ipv4_tcp_window_scaling_HADOOP

    optimKern kernel.shmmni $kernel_shmmni_HADOOP

    optimKern kernel.sem "$kernel_sem_HADOOP"

    optimKern fs.aio-max-nr $fs_aio_max_nr_HADOOP

    optimKern net.ipv4.tcp_rmem "$net_ipv4_tcp_rmem_HADOOP"

    optimKern net.ipv4.tcp_wmem "$net_ipv4_tcp_wmem_HADOOP"

    optimKern net.ipv4.tcp_syncookies $net_ipv4_tcp_syncookies_HADOOP

    optimKern sunrpc.tcp_slot_table_entries $sunrpc_tcp_slot_table_entries_HADOOP

    optimKern vm.dirty_background_ratio $vm_dirty_background_ratio_HADOOP

    optimKern fs.inotify.max_user_instances $fs_inotify_max_user_instances_HADOOP

    ### RHEL6 only, transparent pages
    sysTransparentPages optimize

    if [ "$RHVER" == "6" ];then
      optimKern fs.epoll.max_user_instances $fs_epoll_max_user_instances_HADOOP force
    fi

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  fi 
  
  lineEndSub
}

sysCfgSettings() {
  ## $1 = show, debug or optimize
  ## $2 = report or ""
  ### If it's anything general, but not a kernel tuning paramter, and not hadoop software specific...

  ## internal only functions... 
  showSysMisc(){
    ## $1 is the switch passed to ulimit(i.e. "-c")
    if [ "$1" == "-t" ];then 
      ULIMITDESC=$(ulimit -a|grep \\"$1"|tail -1|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
      ULIMITDESC2=$(ulimit -a|grep \\"$1"|tail -1|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
      ULIMITVAL=$(ulimit -a|grep \\"$1"|tail -1|awk -F")" '{print $2}'|tr -d ' ')
    else 
      ULIMITDESC=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
      ULIMITDESC2=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
      ULIMITVAL=$(ulimit -a|grep \\"$1"|awk -F")" '{print $2}'|tr -d ' ')
    fi 
    logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" is \"$ULIMITVAL\" "
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "ulimit setting: $ULIMITDESC ($ULIMITDESC2) :" "$ULIMITVAL" 
    fi
  }

  ## internal only functions... 
  debugSysMisc(){ 
    ## $1 is the switch passed to ulimit 
    ## $2 is the optmial value to compare against 
    ULIMITDESC=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITDESC2=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITVAL=$(ulimit -a|grep \\"$1"|awk -F")" '{print $2}'|tr -d ' ')
    
    if [ $ULIMITVAL -ge $2 ];then 
      logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" at \"$ULIMITVAL\" already optimized [OK]"
      optimizedVal="YES" 
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "$ULIMITDESC ($ULIMITDESC2):" "$ULIMITVAL" "$2" "$optimizedVal"
      fi 
    else 
      logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" = \"$ULIMITVAL\" NOT optimized, \"$2\" is optimal value [DEBUG]"
      optimizedVal="NO"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "$ULIMITDESC ($ULIMITDESC2)" "$ULIMITVAL" "$2" "$optimizedVal"
      fi
    fi 
  }

  ## internal only functions...
  disableAttribonRootDisk() {
    ## Id the root device ...
    rootMount=$(mount | grep "/ "|awk '{print $1}')
    rootAttribs=$(grep $rootMount /etc/fstab |awk '{print $4}')
    rootAttribs_HADOOP="noatime,nodiratime"

    if [ "$1" == "show" ];then
      logit "Root blk dev: \"$rootMount\" with attribs :" "\"$rootAttribs\""
    elif [ "$1" == "debug" ];then
      if [ "$rootAttribs" == "$rootAttribs_HADOOP" ];then
	optimizedVal="YES"
        logit "Root blk dev: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal" 
      else
	optimizedVal="NO"
        logit "Root blk dev: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal"
      fi
    elif [ "$1" == "optimize" ];then
      if [ ! -e /dev/sda3 ];then
        logit "Root partition not found on /dev/sda3 [NOTED]"
      else
        if [ "$rootAttribs" == "$rootAttribs_HADOOP" ];then
	  optimizedVal="YES"
          logit "Root blk dev: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal" 
          /bin/sed -i 's:\(.*\)\(\s/\s\s*\)\(\w*\s*\)\(\w*\s*\)\(.*\):\1\2\3noatime,nodiratime\t\5:' /etc/fstab
        else
  	  optimizedVal="NO"
          logit "Root blk dev: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal" 
        fi
      fi

      if [ ! -e /dev/mapper/vg_root-lv_root ];then
        logit "Root partition not found on /dev/mapper/vg_root-lv_root [NOTED]"
      else
        if [ "$rootAttribs" == "$rootAttribs_HADOOP" ];then
          optimizedVal="YES"
          logit "Root blk dev7: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal"
          /bin/sed -i 's:\(.*\)\(\s/\s\s*\)\(\w*\s*\)\(\w*\s*\)\(.*\):\1\2\3noatime,nodiratime\t\5:' /etc/fstab
        else
          optimizedVal="NO"
          logit "Root blk dev8: \"$rootMount\"" "$rootAttribs" "$rootAttribs_HADOOP" "$optimizedVal"
        fi
      fi
    fi
  }

  enableDeadlineSched() {
    ## find the correct location for the 'scheduler' file
    SCHEDFILE=$(find /sys/block/sd?/ -name scheduler|head -1)
    scheduler_HADOOP="deadline"

    if [ "$1" == "show" ];then
      if [ -e /dev/sda ];then
        CURRENTSCHED=$(cat /sys/block/sda/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        logit "I/O Scheduler for device \"/dev/sda\" set to :" " \"$CURRENTSCHED\" "
      fi

      if [ -e /dev/sdb ];then
        CURRENTSCHED=$(cat /sys/block/sdb/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        logit "I/O Scheduler for device \"/dev/sdb\" set to :" " \"$CURRENTSCHED\" "
      fi

    elif [ "$1" == "debug" ];then
      if [ -e /dev/sda ];then
        CURRENTSCHED=$(cat /sys/block/sda/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        if [ "$CURRENTSCHED" != "$scheduler_HADOOP" ];then
          logit "I/O Scheduler for device \"/dev/sda\" " "$CURRENTSCHED" "$scheduler_HADOOP" "NO"
        else
          logit "I/O Scheduler for device \"/dev/sda\" " "$CURRENTSCHED" "$scheduler_HADOOP" "YES"
        fi
      fi
      if [ -e /dev/sdb ];then
        CURRENTSCHED=$(cat /sys/block/sdb/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        if [ "$CURRENTSCHED" != "$scheduler_HADOOP" ];then
          logit "I/O Scheduler for device \"/dev/sdb\" " "$CURRENTSCHED" "$scheduler_HADOOP" "NO"
        else
          logit "I/O Scheduler for device \"/dev/sdb\" " "$CURRENTSCHED" "$scheduler_HADOOP" "YES"
        fi
      fi
    elif [ "$1" == "optimize" ];then
      if [ -e /dev/sda ];then
        CURRENTSCHED=$(cat /sys/block/sda/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        if [ "$CURRENTSCHED" != "deadline" ];then
          echo deadline > /sys/block/sda/queue/scheduler
          logit "I/O Scheduler for device \"/dev/sda\" " "$CURRENTSCHED" "$scheduler_HADOOP" "OPTIMIZE" 
        else
          logit "I/O Scheduler for device \"/dev/sda\" " "$CURRENTSCHED" "$scheduler_HADOOP" "YES" 
        fi
      fi

      if [ -e /dev/sdb ];then
        CURRENTSCHED=$(cat /sys/block/sdb/queue/scheduler|awk -F[ '{print $2}'|awk -F] '{print $1}')
        if [ "$CURRENTSCHED" != "deadline" ];then
          echo deadline > /sys/block/sdb/queue/scheduler
          logit "I/O Scheduler for device \"/dev/sdb\" " "$CURRENTSCHED" "$scheduler_HADOOP" "OPTIMIZE" 
        else
          logit "I/O Scheduler for device \"/dev/sdb\" " "$CURRENTSCHED" "$scheduler_HADOOP" "YES" 
        fi
      fi
    fi
  }

  optimSysMisc(){
    ### only does ulimit settings at this point ... 
    DATEFMT2=$(date '+%m-%d-%y.%H%M')
    ## $1 is the switch passed to ulimit 
    ## $2 is the optmial value to compare against
    ULIMITDESC=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITDESC2=$(ulimit -a|grep \\"$1"|awk -F"(" '{print $2}'|awk -F")" '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
    ULIMITVAL=$(ulimit -a|grep \\"$1"|awk -F")" '{print $2}'|tr -d ' ')
   
    if [ "$1" == "-n" ];then 
      SECLIMITCHK=$(grep nofile /etc/security/limits.conf|grep -v "#"|tail -1)
    elif [ "$1" == "-u" ];then  
      SECLIMITCHK=$(grep nproc /etc/security/limits.conf|grep -v "#"|tail -1)
    fi 

    if [ $ULIMITVAL -ge $2 -o "$SECLIMITCHK" != "" ];then
      logit "ulimit setting \"$ULIMITDESC\" \"($ULIMITDESC2)\" at \"$ULIMITVAL\" already optimized [OPTIMIZED]"
      optimizedVal="YES"
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "$ULIMITDESC ($ULIMITDESC2)" "$ULIMITVAL" "$2" "$optimizedVal"
      fi
    else
      ## optimizedVal="NO"
      if [ "$1" == "-n" ];then
        backUpConfigFile "/etc/security/limits.conf" 
        echo "### Modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /etc/security/limits.conf
        echo "*         -       nofile  32768" >> /etc/security/limits.conf 
        ### also set it in the current shell
  	ulimit -n $2
      elif [ "$1" == "-u" ];then
        backUpConfigFile "/etc/security/limits.conf" 
        echo "### Modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /etc/security/limits.conf
	echo "* 	  - 	  nproc   65536" >> /etc/security/limits.conf
        ### also set it in the current shell
  	ulimit -u $2
      fi 
      optimizedVal="OPTIMIZE"
      logit "ulimit $1" "$ULIMITVAL" "$2" "$optimizedVal"
    fi
  } 

  modUmaskInBashRCfile() {
    UMASKCHK1=$(grep umask /etc/bashrc|grep -v "#"|head -1|awk '{print $2}'|tr -d ' ')
    UMASKCHK2=$(grep umask /etc/bashrc|grep -v "#"|tail -1|awk '{print $2}'|tr -d ' ')

    if [ "$UMASKCHK1" == "0022" -a "$UMASKCHK2" == "0022" ];then
      logit "Umask creation setting in /etc/bashrc of \"$UMASKCHK1\" and \"$UMASKCHK2\" is already optimized [OPTIMIZED]"
    else
      backUpConfigFile "/etc/bashrc"
      echo "### Umask Setting modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /etc/bashrc
      logit "Modifying Umask creation \"$UMASKCHK1\" and \"$UMASKCHK2\" setting in /etc/bashrc changing [OPTIMIZE]"
      sed -i 's/0027/0022/g' /etc/bashrc
    fi
  }

  ### sub-main ... 
  logit "** Auto Discovery system configuation settings being checked..."

  MYUMASK=$(umask)
  HDSFUSER=$(id hdfs 2>&1>/dev/null;echo $?)
  MASK_HADOOP="0022"

  if [ "$1" == "show" ];then
    ## logit "File descriptor limits(ulimit -n) currently:$FDLIMITS"
    ## logit "System umask set to : $MYUMASK" 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related System Config Settings" "System Settings" "Values"
    fi

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
    lineEndSub

    logit "User root umask : \"$MYUMASK\" "
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "User root umask :" "$MYUMASK"   
    fi 

    if [ "$HDSFUSER" != "0" ];then 
      logit "Could not find valid \"hdfs\" user <NOTED>" 
    else 
      HDFSUSRUMASK=$(su - hdfs -c 'umask')
      logit "User hdfs umask set to : \"$HDFSUSRUMASK\" " 
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "User hdfs umask :" "$HDFSUSRUMASK"   
      fi 
    fi 
    lineEndSub

    disableAttribonRootDisk show 

    lineEndSub

    enableDeadlineSched show 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "debug" ];then

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related System Config Settings" "System Settings" "Values" "Optimal Value" "Optimized"
    fi

    FDLIMITS_HADOOP='32768'	#nofile or ulimit -n or 'open files' 
    debugSysMisc "-n" $FDLIMITS_HADOOP

    NPROC_HADOOP='65536'	#nproc or ulimit -u or 'max user processes' 
    debugSysMisc "-u" $NPROC_HADOOP

    lineEndSub

    if [ "$MYUMASK" == "$MASK_HADOOP" ];then 
      logit "User root umask(current shell) : \"$MYUMASK\" is already optimized [OK]"
      optimizedVal=YES
    else 
      logit "User root umask(current shell) NOT optmized at \"$MYUMASK\", optimal value is \"$MASK_HADOOP\" [DEBUG]"
      optimizedVal=NO
    fi 

    if [ "$REPORTMODE" == "true" ];then 
      bldHTMLmsgTableRow "User root umask(current shell) :" $MYUMASK $MASK_HADOOP "$optimizedVal" 
    fi 

    if [ "$HDSFUSER" != "0" ];then
      logit "Could not find valid \"hdfs\" user <NOTED>"
    else
      HDFSUSRUMASK=$(su - hdfs -c 'umask')
      if [ "$HDFSUSRUMASK" == "$MASK_HADOOP" ];then 
        logit "User hdfs umask(current shell) already optmized at \"$HDFSUSRUMASK\" [OK]"
        optimizedVal=YES
      else 
        logit "User hdfs umask(current shell) NOT optmized at \"$HDFSUSRUMASK\", optimal value is \"$MASK_HADOOP\" [DEBUG]"
        optimizedVal=NO
      fi 
      if [ "$REPORTMODE" == "true" ];then
        bldHTMLmsgTableRow "User hdfs umask(current shell) :" $HDFSUSRUMASK $MASK_HADOOP "$optimizedVal"
      fi
    fi
    
    lineEndSub

    disableAttribonRootDisk debug

    lineEndSub
  
    enableDeadlineSched debug 

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  elif [ "$1" == "optimize" ];then

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableHdrFile "Hadoop Related System Config Settings" "System Settings" "Values" "Optimal Value" "Optimized"
    fi

    FDLIMITS_HADOOP='32768'     #nofile or ulimit -n or 'open files'
    optimSysMisc "-n" $FDLIMITS_HADOOP

    NPROC_HADOOP='65536'        #nproc or ulimit -u or 'max user processes'
    optimSysMisc "-u" $NPROC_HADOOP
    logit "Reboot for these changes may be required [NOTED]"

    lineEndSub

    if [ "$MYUMASK" == "$MASK_HADOOP" ];then
      logit "User root umask(current shell) : \"$MYUMASK\" is already optimized [OK]"
      optimizedVal=YES
    else
      logit "User root umask(current shell) NOT optmized at : \"$MYUMASK\", changing to optimal value \"$MASK_HADOOP\" [OPTIMIZE]"
      UMASKCHK=$(grep umask /root/.bash_profile|awk '{print $2}')
      if [ "$UMASKCHK" != "$MASK_HADOOP" ];then
	backUpConfigFile "/root/.bash_profile" 
    	echo "### Modified by script \"$ME\" on $DATEFMT2 for parameter $1" >> /root/.bash_profile
 	echo "umask 0022" >> /root/.bash_profile
	umask 0022
      fi 
      optimizedVal="OPTIMIZE"
      logit "root umask(/root/.bash_profile)" "$MYUMASK" "$MASK_HADOOP" "$optimizedVal"
    fi

    if [ "$HDSFUSER" != "0" ];then
      logit "Could not find valid \"hdfs\" user [NOTED]"
    else
      HDFSUSRUMASK=$(su - hdfs -c 'umask'|tr -d ' ')
      if [ "$HDFSUSRUMASK" == "$MASK_HADOOP" ];then
        logit "User hdfs umask(current shell) already optmized at \"$HDFSUSRUMASK\" [OK]"
        optimizedVal=YES
      else
	modUmaskInBashRCfile
	umask 0022
      fi
      optimizedVal="OPTIMIZE"
      logit "hdfs umask changed by inheritance from /etc/bashrc" "$HDFSUSRUMASK" "$MASK_HADOOP" "$optimizedVal"
    fi

    lineEndSub

    disableAttribonRootDisk optimize

    lineEndSub

    enableDeadlineSched optimize

    logit "Reboot for these changes IS required [NOTED]"

    lineEndSub

    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableFtrFile
    fi

  fi 
}

getUsrDetails() { 
  USERPASSDESC=$1
  USERDESC=$2

  USRCFG=$(grep -i $USERDESC /etc/passwd)
  USR=$(grep -i $USERDESC /etc/passwd|awk '{print $1}'|awk -F: '{print $1}')
  if [ "$USRCFG" == "" -a "$USR" == "" ];then 
    logit "$USERDESC user account was not found <NOTED>" 
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "$USERDESC user account:" "Not Found **Error**"
    fi 
  else 
    USERID=$(groups $USR)
    USRDETAILS=$(id $USR)

    logit "$USERDESC user : $USRCFG"
    logit "$USERDESC user groups : $USERID"
    logit "$USERDESC user details : $USRDETAILS"
   
    if [ "$REPORTMODE" == "true" ];then
      bldHTMLmsgTableRow "$USERDESC user :" "$USRCFG"
      bldHTMLmsgTableRow "$USERDESC user groups :" "$USERID"
      bldHTMLmsgTableRow "$USERDESC user details :" "$USRDETAILS"
    fi 
  fi 
}

### displayCfgHDFS(){
  ## logit "Auto Discovery HDFS Configuration..."
##}

autoDiscZookeeper(){
  logit "Auto Discovery ZooKeeper Configuration..." 
  lineEndSub
}

autoDiscOozie(){
  logit "Auto Discovery Oozie Configuration..."
  lineEndSub
}

autoDiscHbase(){
  logit "Auto Discovery Hbase Configuration..."
  lineEndSub
}

autoDiscSqoop(){
  logit "Auto Discovery Sqoop Configuration..." 
  lineEndSub
}

autoDiscFlume(){
  logit "Auto Discovery Flume Configuration..." 
  lineEndSub
}

autoDiscImpala(){
  logit "Auto Discovery Impala Configuration..."
  lineEndSub
}


autoDiscHive(){
  logit "** Auto Discovery Hive Configuration..."
  WHICHHIVE=$(which hive 2>/dev/null)
  if [ "$?" != "0" ];then
    logit "Hive binary not found <NOTED>"
    BINFLAG="false"
  else
    logit "Hive binary : $WHICHHIVE"
    BINFLAG="true"
  fi

  HIVEPKG=$(rpm -qa|grep hive|grep -v -i perl)
  if [ "$HIVEPKG" != "" ];then
    logit "Hive package : $HIVEPKG"
    PKGFLAG="true"
  else
    logit "Hive package not found <NOTED>"
    PKGFLAG="false"
  fi

  if [ "$BINFLAG" == "false" -a "$PKGFLAG" == "false" ];then
    logit "Hive is likely not configured with this hadoop installation <NOTED>"
  else
    getUsrDetails "hive" "Hive"
  fi

  findXMLCfgFile "hive" "hive-default.xml" "/usr"
  if [ "$?" == "0" ];then
    parseXML $LOOKFORFILE "Hive"
  fi

  findXMLCfgFile "hive" "hive-site.xml" "/opt"
  if [ "$?" == "0" ];then
    parseXML $LOOKFORFILE "Hive"
  fi

  findPROPfile "hive" "hive-log4j.properties" "/usr"
  if [ "$?" == "0" ];then
    parsePROPERTIES $PFILESEARCH
  fi
  lineEndSub
}

autoDiscPig(){
  logit "** Auto Discovery Pig Configuration..."
  WHICHPIG=$(which pig 2>/dev/null)
  if [ "$?" != "0" ];then
    logit "Pig binary not found <NOTED>"
    BINFLAG="false"
  else
    logit "Pig binary : $WHICHPIG"
    BINFLAG="true"
  fi

  PIGPKG=$(rpm -qa|grep pig)
  if [ "$PIGPKG" != "" ];then
    logit "Pig package : $PIGPKG"
    PKGFLAG="true"
  else
    logit "Pig package not found <NOTED>"
    PKGFLAG="false"
  fi

  if [ "$BINFLAG" == "false" -a "$PKGFLAG" == "false" ];then 
    logit "Pig is likely not configured with this hadoop installation <NOTED>" 
  else 
    getUsrDetails "pig" "Pig"
  fi 

  findPROPfile "pig" "pig.properties" "/etc"
  if [ "$?" == "0" ];then
    parsePROPERTIES $PFILESEARCH
  fi

  findPROPfile "pig" "pig.properties.roger" "/etc"
  if [ "$?" == "0" ];then
    parsePROPERTIES $PFILESEARCH
  fi
  lineEndSub
}

backUpConfigFile(){
  ## $1 is the fullpath of the file to be backed up 
  DATEFMT2=$(date '+%m-%d-%y.%H%M')

  if [ ! -e $1.$DATEFMT2.bak ];then
    logit "Creating a backup copy of \"$1\" file to $1.$DATEFMT2.bak"
    /bin/cp -f -p $1 $1.$DATEFMT2.bak
  else 
    logit "No new backup file was needed, file \"$1.bak\" exists [OK]"
  fi
}

htmlReport(){
  logit "Formatting report file for HTML Emailed Report" 
  lineEndSub
}

#######################
### Main line logic ###
#######################

MYUSER=$(/usr/bin/whoami)

if [ "$MYUSER" != "root" ];then 
  logit "Cannot run this script unless you are \"root\" user account ! <ERROR>"
  sleep 3 
  hadoopHelp
  exit 2 
fi 

if [ "$SENDMAILCHK" == "" ];then 
  logit "Sendmail package not installed ! <ERROR>" 
  sleep 3 
  hadoopHelp
  exit 2 
fi 

### check parameters $1, $2, and $3, and decide what to do from there 
if [ "$PARONE" == "" -o $NUMPARAMETERS -ge 5 ];then 
  hadoopHelp
  exit 2
fi 

## Debug Check ...
showCHK=$(echo "$PARONE"|grep -i show)     ### Display configuration only 
DebugCHK=$(echo "$PARONE"|grep -i debug)   ### Display conf and display hadoop optimized values 
optimizeCHK=$(echo "$PARONE"|grep -i optimize) ### Make changes shown by debug mode 
reportCHK=$(echo "$PARTHREE"|grep -i report) ### Show,Display, or Optimize mode, but formatted with report and email sent 
descCHK=$(echo "$4")

if [ "$reportCHK" != "" ];then 
  logit "REPORT Mode Enabled [OK]"
  ### Set the global flag for functons to check here after ... 
  REPORTMODE="true"
  
  if [ -f message.html ];then
    rm -rf message.html
    logit "Removing old message.html file ...[OK]"
  fi

  if [ -e "$MSGBODYTMPFILE" ];then
    logit "Cleaning up old \"$MSGBODYTMPFILE\" file ...[OK]"
    rm -rf $MSGBODYTMPFILE
  fi
fi

if [ "$showCHK" != "" ];then
  logit "SHOW Mode Enabled, no config changes will be made [OK]"

  if [ "$PARTWO" != "" ];then 
    # logit "Running \"$ME\" in \"$PARONE $PARTWO\" mode [OK]"
    NF=$(echo $PARTWO|awk -F, '{print NF}')
    PARTWOLIST=$(echo $PARTWO|sed 's/,/\ /g') 
    PARTWOVALIDCHOICES="system hardware kernel java hadoop mapreduce pig hive hbase oozie zookeeper flume sqoop impala"

    ## always show these 2 basic functions 
    header
    autoDiscBaseSystem show 

    for p in $PARTWOLIST
    do 
      P2FOUND="false"
      ## logit "Validating parameter 2 \"$p\" "
      for v in $PARTWOVALIDCHOICES 
      do 
        if [ "$p" == "$v" ];then 
          ## logit "Parameter 2:$p is good [OK]" 
	  P2FOUND="true"
	## else 
          ## logit "Parameter 2:$p is not found ! <ERROR>" 
        fi 
      done 
      if [ "$P2FOUND" == "true" ];then 
        ## logit "Parameter 2:$p is good [OK]" 
        case $p in
	system)
	sysCfgSettings show
	;;
	kernel)
	displayLinuxKernelParm show 
	;;
        hardware)
	displayHardwareConfig show 
	;;
	java)
	autoDiscJava show
	;;
	hadoop)
	autoDiscHadoop show
	;;
	mapreduce)
	autoDiscMapReduce show
	;;
	pig)
	autoDiscPig
	;;
	hive)
	autoDiscHive
	;;
	hbase)
	autoDiscHbase
	;;
	zookeeper)
	autoDiscZookeeper
	;;
	oozie)
	autoDiscOozie
	;;
	flume)
	autoDiscFlume
	;;
	sqoop)
	autoDiscSqoop
	;;
	impala)
	autoDiscImpala
	;;
	esac
      else 
        logit "Parameter 2:$p NOT found ! <ERROR>" 
        P2FOUND="false"
   	exit 4
      fi 
    done 
    ### exit 21
  fi 

  ### if only show parameter passed in, show "everything" 
  ## header
  ## autoDiscBaseSystem
  
  ## sysCfgSettings
  ## displayLinuxKernelParm show 
  ## displayHardwareConfig
  ## autoDiscJava
  ## autoDiscHadoop
  ## autoDiscMapReduce
  ## autoDiscPig
  ## autoDiscHive
  ## autoDiscHbase
  ## autoDiscZookeeper
  ## autoDiscOozie
  ## autoDiscFlume
  ## autoDiscSqoop
  ## autoDiscImpala

elif [ "$DebugCHK" != "" ];then
  logit "DEBUG Mode Enabled, no config changes to be made, recommendations only [OK]"

  if [ "$PARTWO" != "" ];then
    # logit "Running \"$ME\" in \"$PARONE $PARTWO\" mode [OK]"
    NF=$(echo $PARTWO|awk -F, '{print NF}')
    PARTWOLIST=$(echo $PARTWO|sed 's/,/\ /g')
    PARTWOVALIDCHOICES="system hardware kernel java hadoop mapreduce pig hive hbase oozie zookeeper flume sqoop impala"
    ## always show these 2 basic functions
    header
    autoDiscBaseSystem debug

    for p in $PARTWOLIST
    do
      P2FOUND="false"
      ## logit "Validating parameter 2 \"$p\" "
      for v in $PARTWOVALIDCHOICES
      do
        if [ "$p" == "$v" ];then
          ## logit "Parameter 2:$p is good [OK]"
          P2FOUND="true"
        ## else
          ## logit "Parameter 2:$p is not found ! <ERROR>"
        fi
      done
      if [ "$P2FOUND" == "true" ];then
        ## logit "Parameter 2:$p is good [OK]"
        case $p in
        system)
        sysCfgSettings debug
        ;;
        kernel)
        displayLinuxKernelParm debug
        ;;
        hardware)
        displayHardwareConfig debug
        ;;
        java)
        autoDiscJava debug
        ;;
        hadoop)
        autoDiscHadoop debug
        ;;
        mapreduce)
        autoDiscMapReduce debug
        ;;
        pig)
        autoDiscPig debug
        ;;
        hive)
        autoDiscHive debug
        ;;
        hbase)
        autoDiscHbase debug
        ;;
        zookeeper)
        autoDiscZookeeper debug
        ;;
        oozie)
        autoDiscOozie debug
        ;;
        flume)
        autoDiscFlume debug
        ;;
        sqoop)
        autoDiscSqoop debug
        ;;
        impala)
        autoDiscImpala debug
        ;;
        esac
      else
        logit "Parameter 2:$p NOT found ! <ERROR>"
        P2FOUND="false"
        exit 4
      fi
    done
    ### exit 23
  fi
elif [ "$optimizeCHK" != "" ];then  
  logit "OPTIMIZE Mode Enabled [OK]"
  if [ "$PARTWO" != "" ];then
    # logit "Running \"$ME\" in \"$PARONE $PARTWO\" mode [OK]"
    optWarn "$PARTWO" 
    NF=$(echo $PARTWO|awk -F, '{print NF}')
    PARTWOLIST=$(echo $PARTWO|sed 's/,/\ /g')
    PARTWOVALIDCHOICES="system hardware kernel java hadoop mapreduce pig hive hbase oozie zookeeper flume sqoop impala"
    ## always show these 2 basic functions
    header
    autoDiscBaseSystem optimize
    for p in $PARTWOLIST
    do
      P2FOUND="false"
      ## logit "Validating parameter 2 \"$p\" "
      for v in $PARTWOVALIDCHOICES
      do
        if [ "$p" == "$v" ];then
          ## logit "Parameter 2:$p is good [OK]"
          P2FOUND="true"
        ## else
          ## logit "Parameter 2:$p is not found ! <ERROR>"
        fi
      done
      if [ "$P2FOUND" == "true" ];then
        ## logit "Parameter 2:$p is good [OK]"
        case $p in
        system)
        sysCfgSettings optimize
        ;;
        kernel)
        displayLinuxKernelParm optimize
        ;;
        hardware)
        displayHardwareConfig optimize
        ;;
        java)
        autoDiscJava optimize
        ;;
        hadoop)
        autoDiscHadoop optimize
        ;;
        mapreduce)
        autoDiscMapReduce optimize
        ;;
        pig)
        autoDiscPig optimize
        ;;
        hive)
        autoDiscHive optimize
        ;;
        hbase)
        autoDiscHbase optimize
        ;;
        zookeeper)
        autoDiscZookeeper optimize
        ;;
        oozie)
        autoDiscOozie optimize
        ;;
        flume)
        autoDiscFlume optimize
        ;;
        sqoop)
        autoDiscSqoop optimize
        ;;
        impala)
        autoDiscImpala optimize
        ;;
        esac
      else
        logit "Parameter 2:$p NOT found ! <ERROR>"
        P2FOUND="false"
        exit 4
      fi
    done
  fi
else 
  hadoopHelp
  exit 2
fi

if [ "$REPORTMODE" == "true" ];then 
  logit "Building and sending HTML Report [OK]"
  bldHTMLhdr 
  cat $MSGBODYTMPFILE >> message.html 
  bldHTMLftr  
  emailHTMLfile
fi 

exit 0 
