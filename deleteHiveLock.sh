#!/bin/bash

# Author : Roger K. Hill
# Date : 04/04/2017
# Org : Yash Technologies / Caterpillar
# Desc : Fix for bug HIVE-14799: Query ops not thread safe during its cancel Cloudera Case # 133462
#        To remove bad locks from a Hive table to allow queries to complete successfully ...
# 	 Tool only for olga Hive database "hbolgb44_impala" ONLY ... work around ... 

PARAMETERS="$@"
NUMPARAMETERS="$#"
ME=$(basename $0)
SCRIPT_VER="1.3"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
PARONE=$(echo $1|awk -F= '{print $2}') ## HiveDatabase Name 
PARTWO=$(echo $2|awk -F= '{print $2}') ## HiveTable Name 

OLD_IFS=$IFS

logit() {
  DATEFMT=$(date "+%b %d %H:%M:%S")
  if [ "$2" == "prompt" ];then
    echo -n "$DATEFMT : $1" | tee -a $LOGFILE
  else
    echo "$DATEFMT : $1" | tee -a $LOGFILE
  fi
}

helpMenu() { 
  logit "*** Help Menu ***" 
  logit "" 
  logit "Please enter Hive database name as parameter one, Hive table name as parameter two on lock to remove [ OK ]" 
  logit "Example : " 
  logit "" 
  logit "	------------------------------------------------------------" 
  logit "	./$ME --hiveDB=hbolgb44_impala --hiveTBL=cat_builder_file" 
  logit "	------------------------------------------------------------" 
  logit "" 
}

if [ "$NUMPARAMETERS" -lt "2" ];then 
  helpMenu
  exit 2
fi 

if [ "$PARONE" == "" -o "$PARTWO" == "" ];then 
  helpMenu 
  exit 4 
fi 

### main line logic ...

logit "Checking for Hive Database table locks on \"$PARONE/$PARTWO\" in ZK ..." 

HIVE_LOCK_CHK=$(/usr/bin/zookeeper-client ls /hive_zookeeper_namespace_hive/$PARONE/$PARTWO|tail -1|grep -i lock)

if [ "$HIVE_LOCK_CHK" != "" ];then 
  ### echo -n "Requesting to remove lock for Hive DB \"hbolgb44_impala\" table \"$1\" [ Y / N ]:" ### for PROD 
  echo -n "Requesting to remove lock for Hive DB \"$PARONE\" table \"$PARTWO\" in ZK [ Y / N ]:"
  read ans
  if [ "$ans" == "Y" -o "$ans" == "y" ];then 
    logit "Proceeding to remove lock for Hive Table \"$PARONE.$PARTWO\" ..." 
    ### DEBUG ### /usr/bin/zookeeper-client ls /hive_zookeeper_namespace_hive/$PARONE/$PARTWO | tail -1 
    /usr/bin/zookeeper-client rmr /hive_zookeeper_namespace_hive/$PARONE/$PARTWO 
    if [ "$?" -eq "0" ];then 
      logit "Successfully removed Hive table lock in ZK /hive_zookeeper_namespace_hive/$PARONE/$PARTWO" 
    else  
      logit "Could NOT remove Hive table lock in ZK /hive_zookeeper_namespace_hive/$PARONE/$PARTWO" 
    fi 
  else 
    logit "Exiting without completion ..." 
    exit 6 
  fi 
else 
  logit "No LOCKS found for \"$PARONE.$PARTWO\" exiting without execution ..." 
fi 

exit 0
