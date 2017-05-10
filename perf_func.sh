#!/bin/bash 

logit (){
  DATEFMT=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$DATEFMT : $1" 
}

logit "--------------------------------------------------------------" 
NUMCORES=$(grep 'model name' /proc/cpuinfo | wc -l) 
UPTIME_LASTFIELD=$(uptime|awk '{print NF}')
FIFTEENMIN_AVG=$(uptime | awk '{print $'$UPTIME_LASTFIELD'}'|awk -F, '{print $1}') 
logit "DEBUG : FIFTEENMIN_AVG = $FIFTEENMIN_AVG"

FIFTEENMIN_AVG_LOAD_LIMIT=$(expr $NUMCORES "*" 3) 
logit "DEBUG : FIFTEENMIN_AVG_LOAD_LIMIT = $FIFTEENMIN_AVG_LOAD_LIMIT" 

LOAD_SCORE=$(echo "scale=2;($FIFTEENMIN_AVG/$FIFTEENMIN_AVG_LOAD_LIMIT)*100"|bc) 
logit "DEBUG Load avg score : $LOAD_SCORE (out of 100%)" 
logit "--------------------------------------------------------------" 

IOWAIT_AVG=$(iostat | grep -A1 avg-cpu | tail -1 |awk '{print $4}')
logit "DEBUG IOWAIT_AVG =$IOWAIT_AVG (out of 100%)" 

IOWAIT_AVG_THRES="10" 
IOWAIT_SCORE=$(echo "scale=2;($IOWAIT_AVG/$IOWAIT_AVG_THRES)*100"|bc)
logit "DEBUG IOWAIT_SCORE=$IOWAIT_SCORE (out of 100%)" 
logit "--------------------------------------------------------------" 

MEMORY_INST=$(free -g|grep Mem|awk '{print $2}')
MEMORY_USED_BUF_CACH=$(free -g|grep buffers|tail -1|awk '{print $3}')
MEMORY_SCORE=$(echo "scale=2;($MEMORY_USED_BUF_CACH/$MEMORY_INST)*100"|bc)
logit "MEMORY_INST = $MEMORY_INST Gb" 
logit "MEMORY_USED_BUF_CACH = $MEMORY_USED_BUF_CACH Gb" 
logit "MEMORY_SCORE = $MEMORY_SCORE (out of 100%)" 
logit "--------------------------------------------------------------" 

CPU_IDLE=$(mpstat -P ALL|grep all|awk '{print $12}')
CPU_BUSY=$(echo "scale=2;100 - $CPU_IDLE"|bc)
logit "CPU_BUSY = $CPU_BUSY (out of 100%)" 
logit "--------------------------------------------------------------" 

ACTIVE_NIC=$(ip addr show|egrep -i -v 'LOOPBACK|127.0.0.1'|grep UP|awk '{print $2}'|awk -F: '{print $1}')

NET_DSTAT_RAW=$(dstat -n -N $ACTIVE_NIC --noheaders --nocolor 2 1|egrep -v 'net|0     0|recv')
NET_RECV=$(echo $NET_DSTAT_RAW|awk '{print $1}')
NET_SEND=$(echo $NET_DSTAT_RAW|awk '{print $2}') 

NET_RECV_NC=${#NET_RECV} 
NET_RECV_VAL=$(echo $NET_RECV|cut -c 1-$(expr $NET_RECV_NC - 1))

NET_SEND_NC=${#NET_SEND}
NET_SEND_VAL=$(echo $NET_SEND|cut -c 1-$(expr $NET_SEND_NC - 1))

logit "DEBUG NET_RECV = $NET_RECV" 
logit "DEBUG NET_SEND = $NET_SEND" 

### Convert to highest unit ... 
LASTCHAR_RECV=$(echo $NET_RECV|awk '{print substr($0,length,1)}')
LASTCHAR_SEND=$(echo $NET_SEND|awk '{print substr($0,length,1)}')

logit "DEBUG : LASTCHAR_RECV = $LASTCHAR_RECV : LASTCHAR_SEND = $LASTCHAR_SEND"

if [ "$LASTCHAR_RECV" == "$LASTCHAR_SEND" ];then
  NET_TRAFF_TOTAL=$(expr $NET_RECV_VAL + $NET_SEND_VAL)  
  logit "DEBUG $NET_RECV_VAL + $NET_SEND_VAL == $NET_TRAFF_TOTAL $LASTCHAR_RECV" 
  NET_FORMAT="$LASTCHAR_RECV" 
else 
  if [ "$LASTCHAR_RECV" == "B" ] && [ "$LASTCHAR_SEND" == "k" ];then 
    logit "Split condition 1 detected [ OK ]"     
    NET_RECV_VAL=$(echo "scale=2;$NET_RECV_VAL/1024"|bc) # conv B to k 
    NET_RECV_VAL=$(expr $(echo $NET_RECV_VAL|awk -F. '{print $1}') + 1) # round up 
    NET_TRAFF_TOTAL=$(expr $NET_RECV_VAL + $NET_SEND_VAL)
    logit "DEBUG : Adjusted NET_RECV_VAL = $NET_RECV_VAL" 
    NET_FORMAT="$LASTCHAR_SEND" 
  elif [ "$LASTCHAR_RECV" == "k" ] && [ "$LASTCHAR_SEND" == "B" ];then 
    logit "Split condition 2 detected [ OK ]"     
    NET_SEND_VAL=$(echo "scale=2;$NET_SEND_VAL/1024"|bc) # conv B to k 
    NET_SEND_VAL=$(expr $(echo $NET_SEND_VAL|awk -F. '{print $1}') + 1) # round up 
    NET_TRAFF_TOTAL=$(expr $NET_RECV_VAL + $NET_SEND_VAL)
    logit "DEBUG : Adjusted NET_SEND_VAL = $NET_SEND_VAL" 
    NET_FORMAT="$LASTCHAR_RECV" 
  elif [ "$LASTCHAR_RECV" == "k" ] && [ "$LASTCHAR_SEND" == "M" ];then
    logit "Split condition 3 detected [ OK ]"
    NET_RECV_VAL=$(echo "scale=2;$NET_RECV_VAL/1024"|bc) # con k to M 
    NET_RECV_VAL=$(expr $(echo $NET_RECV_VAL|awk -F. '{print $1}') + 1) # round up 
    NET_TRAFF_TOTAL=$(expr $NET_RECV_VAL + $NET_SEND_VAL)
    logit "DEBUG : Adjusted NET_RECV_VAL = $NET_RECV_VAL"
    NET_FORMAT="$LASTCHAR_SEND"
  elif [ "$LASTCHAR_RECV" == "M" ] && [ "$LASTCHAR_SEND" == "k" ];then
    logit "Split condition 4 detected [ OK ]"
    NET_SEND_VAL=$(echo "scale=2;$NET_SEND_VAL/1024"|bc) # conv k to M
    NET_SEND_VAL=$(expr $(echo $NET_SEND_VAL|awk -F. '{print $1}') + 1) # round up
    NET_TRAFF_TOTAL=$(expr $NET_RECV_VAL + $NET_SEND_VAL)
    logit "DEBUG : Adjusted NET_SEND_VAL = $NET_SEND_VAL"
    NET_FORMAT="$LASTCHAR_RECV"
  fi  
fi 

# For a 1 Gb (Gigabit) Network Connection ...  

case $NET_FORMAT in 
B)
  DIV_VAL="134217728";; # Bytes 
k) 
  DIV_VAL="1048576";; # Kilobits 
K) 
  DIV_VAL="131072";; # KiloBytes  
m) 
  DIV_VAL="1024";; # Megabits 
M) 
  DIV_VAL="128";; # MegaBytes 
esac 

if [ "$NET_TRAFF_TOTAL" != "" ];then 
  NET_BANDW_SCORE=$(echo "scale=2;($NET_TRAFF_TOTAL/$DIV_VAL)*100"|bc) 
  logit "Network Bandwidth Score: $NET_BANDW_SCORE(out of 100%) $NET_TRAFF_TOTAL / $DIV_VAL $NET_FORMAT" 
fi 

logit "--------------------------------------------------------------" 

exit 99 

exit 0 
