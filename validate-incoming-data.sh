#!/bin/bash

# DATE : 09/17/2015
# AUTH : roger.hill2@unisys.com
# DESC : This is a simple script to validate data files that are being uploaded each day to a certain directory ...

PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
PARTHREE="$3"
ME=$(basename $0)
SCRIPT_VER="1.1"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/SMS800_Scripts/logs/$ME.$DDMMYY.log"
HOSTNAME=$(uname -n)
EMAIL_RECP="$PARTWO"
EMAIL_CC="$PARTHREE"
DATELONG_FMT=$(date "+%b %d %Y - %H:%M:%S")

#SMS800_INCOMING_DIR=/home/sms800/SMS800_OLD/20150917

### functions def
logit() {
  DATEFMT=$(date "+%m/%d/%y %H:%M:%S")
  echo "$DATEFMT $HOSTNAME $1" | tee -a $LOGFILE
}

scriptHeader (){
  DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
  logit "################ Unisys $ME Script Running ################"
  logit "  *** Script Version : $SCRIPT_VER"
  logit "  *** Script filename : \"$ME\" "
  logit "  *** Script logfile : \"$LOGFILE\" "
  logit "  *** Script date run : $DDMMYY2"
  logit "  *** Parameter One (Target Dir): \"$PARONE\" "
}

line(){
  logit "--------------------------------------------------------------------------"
}

scriptSummary(){
  logit "################ Unisys $ME Script Summary ################"
  if [ "$RESULTFLAG" == "true" ];then
    logit "Result of the \"$MAPREDJOBNAME\" job was [ SUCCESS ]"
  else
    logit "Result of the \"$MAPREDJOBNAME\" job was [ FAILURE ]"
  fi
}

emailLog() {
  cat $LOGFILE | mail -s "$ME SMS 800 Incoming file data validation report on $DATELONG_FMT" -c $EMAIL_CC $EMAIL_RECP
}

### mainline logic
scriptHeader

if [ "$PARONE" != "" ];then
  if [ -d $PARONE ] ;then
    logit "Parameter One \"$PARONE\" is a valid directory [ OK ]"
  else
    logit "Parameter One \"$PARONE\" is NOT a valid directory [ ERROR ]"
    exit 2
  fi
else
  logit "Parameter One does NOT contain a valid directory [ ERROR ]"
  exit 4
fi

line
logit "Report on SMS800 incoming data files received in directory \"$PARONE\" on $DATELONG_FMT : "

NUMFILES=$(find $PARONE -type f |wc -l)
logit "Directory \"$PARONE\" contains \"$NUMFILES\" files :"
line

DATA_FILES=$(ls $PARONE/)
for file in $DATA_FILES
do
  logit "File found : $PARONE/$file"
  NUM_RECORDS=$(cat $PARONE/$file|wc -l)
  logit "  - Tot records in \"$file\" is \"$NUM_RECORDS\" "
  FILE_SIZE=$(stat $PARONE/$file|grep Size|awk -F: '{print $2}'|awk '{print $1}'|sed -e 's/^ *//g' -e 's/ *$//g')
  logit "  - File size for \"$file\" is \"$FILE_SIZE\" bytes"
  FILE_DATE=$(stat $PARONE/$file|grep Modify|awk '{print $2" "$3}')
  logit "  - File date for \"$file\" is \"$FILE_DATE\" "
  FILE_MD5SUM=$(md5sum $PARONE/$file|awk '{print $1}')
  logit "  - File MD5 checksum for \"$file\" is \"$FILE_MD5SUM\" "
  line
done

sleep 2
emailLog

# scriptSummary

exit 0
