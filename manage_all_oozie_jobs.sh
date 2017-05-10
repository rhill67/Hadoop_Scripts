#!/bin/bash

# Author : Roger K. Hill
# Date : 02/16/2017
# Org : Yash Technologies / Caterpillar
# Desc : manage_all_oozie_jobs.sh is a script for us to help manage all oozie jobs at once ... 

### Script global vars ...

SHORTHOST=$(hostname --short)
PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
ME=$(basename $0)
SCRIPT_VER="1.0"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
OLD_IFS=$IFS
MYSELF=$(uname -n) 
mehosts=`grep $MYSELF /etc/hosts`

### functions ... 
logit() {
  DATEFMT=$(date "+%b %d %H:%M:%S $SHORTHOST")
  # DATEFMT=$(date "+%c")
  echo "$DATEFMT : $1" | tee -a $LOGFILE
}

line(){
  logit "----------------------------------------" 
} 

helpMe() {
  line 
  logit "Help Menu : Script requires 2 parameters :" 
  logit "" 
  logit "	./$ME --action= [ suspend | resume | kill ] --oozie=URL_OF_OOZIE_SERVER"
  logit "" 
  logit "	Example:"
  logit "	./$ME --action=suspend --oozie=https://arlhsdatat05.lrd.cat.com:11443/oozie"  
  logit "" 
  logit "Help Menu : End" 
  line 
}

#######################
### main line logic ###
#######################

### Process the input parameters
if [[ "$PARONE" == "" ]] || [[ "$PARTWO" == ""  ]];then
  helpMe 
  exit 2  
fi 

PARONE_VAL=$(echo $PARONE|awk -F= '{print $2}')
PARTWO_VAL=$(echo $PARTWO|awk -F= '{print $2}')

## if [[ "$PARONE_VAL" != "suspend" ]] || [[ "$PARONE_VAL" != "resume" ]] || [[ "$PARONE_VAL" != "kill" ]];then 
if [[ "$PARONE_VAL" != "suspend" ]] && [[ "$PARONE_VAL" != "resume" ]] && [[ "$PARONE_VAL" != "kill" ]];then 
  ## logit "DEBUG=PARONE_VAL is $PARONE_VAL"
  helpMe 
  logit "  --> Parameter one \"MUST BE\" a value of either [ suspend | resume | kill ] <-- " 
  logit "" 
  exit 4 
fi 

if [[ "$PARONE_VAL" == "suspend" ]] || [[ "$PARONE_VAL" == "kill" ]];then 
  OOZIE_GREP_STATE="RUNNING" 
elif [ "$PARONE_VAL" == "resume" ];then 
  OOZIE_GREP_STATE="SUSPENDED" 
fi 

logit "Setting env variable for OOZIE_URL" 
export OOZIE_URL=$PARTWO_VAL 

echo "OOZIE_URL=$PARTWO_VAL" | tee -a $LOGFILE
logit "" 

## runningJobs=$(/usr/bin/oozie jobs -oozie $PARTWO_VAL -jobtype coordinator | grep -i $OOZIE_GREP_STATE | awk '{print $1}') 
runningJobs=$(/usr/bin/oozie jobs -oozie $PARTWO_VAL | grep -i $OOZIE_GREP_STATE | awk '{print $1}') 
for ojob in $runningJobs 
do 
  logit "ACTION: $PARONE_VAL on job $ojob" 
  ## logit " ---->>>> DEBUG /usr/bin/oozie job -oozie $PARTWO_VAL -$PARONE_VAL $ojob" 
  /usr/bin/oozie job -oozie $PARTWO_VAL -$PARONE_VAL $ojob
  ## /usr/bin/oozie job -doas hillrk -oozie $PARTWO_VAL -$PARONE_VAL $ojob
done 

exit 0 

