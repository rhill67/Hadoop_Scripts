#!/bin/bash

# DATE : 02/08/2014
# AUTH : rhill x7643
# DESC : Hadoop QA script to be run after initial cluster build , run simple wordcount job and return 0 or 1 . 

PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
ME=$(basename $0)
SCRIPT_VER="2.5b"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
HOSTNAME=$(hostname -f)
RESULTFLAG="false" 

MAPREDJOBNAME="wordcount"
whichCDHvers=""
HADOOPISV=""

logit() {
  DATEFMT=$(date "+%m/%d/%y %H:%M")
  echo "$DATEFMT : $1" | tee -a $LOGFILE
}

scriptHeader (){

  DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
  logit "################ Unisys $ME Script Running ################" 
  logit "  *** Script Version : $SCRIPT_VER"
  logit "  *** Script filename : \"$ME\" "
  logit "  *** Script logfile : \"$LOGFILE\" "
  logit "  *** Script date run : $DDMMYY2"
}

scriptSummary(){
  logit "################ Unisys $ME Script Summary ################"
  if [ "$RESULTFLAG" == "true" ];then
    logit "Result of the \"$MAPREDJOBNAME\" job was [ SUCCESS ]"
  else 
    logit "Result of the \"$MAPREDJOBNAME\" job was [ FAILURE ]"
  fi 
}

line(){
  logit "--------------------------------------------------------------------------" 
}

detectHadoopISV(){

  chkMapR=$(rpm -qa|grep mapr|grep -v mapreduce|wc -l)
  chkCloudera=$(rpm -qa|egrep 'cdh|cloudera'|wc -l)
  chkHortonworks=$(rpm -qa|grep ambari|wc -l)
  chkOther=$(rpm -qa|grep hadoop|wc -l)
  cdhParcelBasDir="/opt/cloudera/parcels"

  if [ "$chkMapR" != "0" -a "$chkCloudera" == "0" -a "$chkHortonworks" == "0" ];then
    HADOOPISV="MapR"
    logit "Hadoop ISV is \"$HADOOPISV\""
  elif [ "$chkMapR" == "0" -a "$chkCloudera" != "0" -a "$chkHortonworks" == "0" ];then
    HADOOPISV="Cloudera"
    whichCDHvers=$(rpm -qa|egrep 'cdh|cloudera'|grep hdfs|egrep -i -v 'fuse|libhdfs|nfs'|awk -Fcdh '{print $2}'|awk -F. '{print $1}')
    if [ "$whichCDHvers" == "" ];then 
      if [ -d "$cdhParcelBasDir" ];then 
	whichCDHvers=$(find $cdhParcelBasDir -name CDH -type l |xargs readlink) 
	if [ "$whichCDHvers" != "" ];then 
          logit "Hadoop ISV is \"$HADOOPISV\" and CDH version \"$whichCDHvers\" "
	else 
          logit "Hadoop ISV is \"$HADOOPISV\" and CDH version \"undetermined\" "
	fi 
      else 
        logit "Hadoop ISV is \"$HADOOPISV\" and CDH version \"undetermined\" "
      fi 
      
    fi 

  elif [ "$chkMapR" == "0" -a "$chkCloudera" == "0" -a "$chkHortonworks" != "0" ];then
    HADOOPISV="Hortonworks"
    logit "Hadoop ISV is \"$HADOOPISV\""
  elif [ "$chkMapR" == "0" -a "$chkCloudera" == "0" -a "$chkHortonworks" == "0" -a "$chkOther" != "0" ];then
    HADOOPISV="Unknown"
    logit "Hadoop ISV is \"$HADOOPISV\""
  fi
}

hadoopPreChecks(){
  logit "Running hadoop pre-checks to determine if possbile to run a \"$MAPREDJOBNAME\" mapreduce job ..." 

  HADOOPRUNCHK=$(ps -ef | grep -i hadoop | grep -v grep | wc -l)
  if [ $HADOOPRUNCHK -ge 2 ];then
    logit "Hadoop processes found in a run state within PID table [ OK ]"
  else
    logit "Hadoop must be in a \"running state\" before $ME can configure, exit now ... [ ERROR ]"
    exit 2
  fi

  NAMENODECHK=$(ps -ef|grep -i namenode | wc -l)
  if [ $NAMENODECHK -ge 2 ];then
    logit "This node is the hadoop namenode, proceeding with \"$MAPREDJOBNAME\" job [ OK ]" 
  else
    logit "This node is not the hadoop namenode, cannot continue with \"$MAPREDJOBNAME\" job [ ERROR ]" 
    exit 2
  fi
}

setupWC() {
  logit "Setting up a \"$MAPREDJOBNAME\" job now ..." 
  su - hdfs -c "hadoop fs -mkdir /user/qa" | tee -a $LOGFILE
  su - hdfs -c "hadoop fs -mkdir /user/qa/wordcount /user/qa/wordcount/input" | tee -a $LOGFILE

  logit "Attempting to download gutenberg data files now for wordcount job" 
  mkdir /tmp/gutenberg 
  wget http://www.gutenberg.org/files/4300/4300.zip -O /tmp/gutenberg/4300.zip 
  wget http://www.gutenberg.org/files/20417/20417.zip -O /tmp/gutenberg/20417.zip
  wget http://www.gutenberg.org/cache/epub/2265/pg2265.txt -O /tmp/gutenberg/2265.txt 
  cd /tmp/gutenberg 
  test /tmp/gutenberg/4300.zip && unzip /tmp/gutenberg/4300.zip
  test /tmp/gutenberg/20417.zip && unzip /tmp/gutenberg/20417.zip
  rm -rf /tmp/gutenberg/4300.zip /tmp/gutenberg/20417.zip 

  # if [ -f /tmp/gutenberg/4300.txt && -f /tmp/gutenberg/20417.txt && -f /tmp/gutenberg/pg2265.txt ];then 
  if [ -f /tmp/gutenberg/4300.txt ] && [ -f /tmp/gutenberg/20417.txt ] && [ -f /tmp/gutenberg/2265.txt ];then 
    logit "Loading downloaded gutenberg data files into HDFS filesystem at /user/qa/wordcount/input" 
  else 
    wget ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NVSS/cmf/mort6878.zip -O /tmp/gutenberg/mort6878.zip
    wget ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NVSS/cmf/pop6878.zip -O /tmp/gutenberg/pop6878.zip 
    test /tmp/gutenberg/mort6878.zip && unzip /tmp/gutenberg/mort6878.zip
    test /tmp/gutenberg/pop6878.zip && unzip /tmp/gutenberg/pop6878.zip  
  fi 

  su - hdfs -c "hadoop dfs -copyFromLocal /tmp/gutenberg/*.txt /user/qa/wordcount/input" | tee -a $LOGFILE 
  su - hdfs -c "hadoop fs -chown -R hdfs:hdfs /user/qa" | tee -a $LOGFILE
  su - hdfs -c "hadoop fs -ls -R /user/qa/wordcount/input" | tee -a $LOGFILE
}

runWC(){
  logit "Running a \"$MAPREDJOBNAME\" job now ..." 

  #HADOOPEXAMPLEJAR=$(find /usr/lib/hadoop-0.20-mapreduce/ -name hadoop-examples.jar)
  HADOOPEXAMPLEJAR=$(find / -name "hadoop*examples*.jar" | xargs ls -rt | grep mapreduce | tail -n 1) 
  logit "DEBUG : $HADOOPEXAMPLEJAR" 
  if [ "$HADOOPEXAMPLEJAR" == "" ];then 
    HADOOPEXAMPLEJAR=$(find /opt/cloudera/ -name hadoop-examples.jar|egrep -v 'share|oozie|hue')
  fi 
  # su - hdfs -c "hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-examples.jar wordcount /user/cloudera/wordcount/input /user/cloudera/wordcount/output" | tee -a $LOGFILE
  su - hdfs -c "hadoop jar $HADOOPEXAMPLEJAR wordcount /user/qa/wordcount/input /user/qa/wordcount/output" | tee -a $LOGFILE
}

checkResultWC(){
  logit "Running the \"$MAPREDJOBNAME\" job results now ..."
  su - hdfs -c "hadoop fs -ls /user/qa/wordcount/output/" | tee -a $LOGFILE
  RESULT=$(su - hdfs -c "hadoop fs -ls /user/qa/wordcount/output/" | grep SUCCESS)
  if [ "$RESULT" != "" ];then 
    logit "The hadoop \"$MAPREDJOBNAME\" job has run SUCCESSFULLY [ OK ]" 
    RESULTFLAG="true" 
  else 
    logit "The hadoop \"$MAPREDJOBNAME\" job has FAILED [ ERROR ]" 
    RESULTFLAG="false" 
  fi 
}

cleanUpWC(){
  logit "Cleaning up HDFS after the \"$MAPREDJOBNAME\" job now ..."
  su - hdfs -c "hadoop fs -rm -r /user/qa"  | tee -a $LOGFILE
  su - hdfs -c "hadoop fs -expunge" | tee -a $LOGFILE
  ## su - hdfs -c "hadoop fs -ls -R /user" | tee -a $LOGFILE
  rm -rf /tmp/gutenberg 
}


#################################################
################ main line logic ################
#################################################

scriptHeader
line 
hadoopPreChecks
line 
detectHadoopISV
line
setupWC
line 
runWC
line 
checkResultWC
line 
cleanUpWC
line
scriptSummary

exit 0 
