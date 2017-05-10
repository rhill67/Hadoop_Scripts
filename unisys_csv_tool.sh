BDAaaS-Sandbox-Data-Integration-Service

 sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'

 
 [dell@ip-10-8-1-24 ~]$ cat unisys_csv_tool.sh
#!/bin/bash

# DATE : 06/23/2014
# AUTH : rhill 314-884-2054
# DESC : designed to take a fixed width file and dump to a clean CSV file ...

PARAMETERS="$@"
NUMPARAMETERS="$#"
PARONE="$1"
PARTWO="$2"
PARTHREE="$3"
ME=$(basename $0)
SCRIPT_VER="1.2"
DDMMYY=$(date +%m%d%y%H%M%S)
LOGFILE="$HOME/$ME.$DDMMYY.log"
REPTFILE="$HOME/$ME.$DDMMYY.rpt"
SHORTHOST=$(uname -n|awk -F. '{print $1}')
FQDN=$(uname -n)


logit() {
  DATEFMT=$(date "+%b %d %H:%M:%S $SHORTHOST")
  echo "$DATEFMT : $1" | tee -a log/$LOGFILE
}

smallLine() {
  logit "--------------------"
}

line() {
  logit "------------------------------------------------------------"
}

starline(){
  logit "***************************************"
}

header() {

  DDMMYY2=$(date +%m-%d-%y:%H:%M:%S)
  logit "################ Unisys $ME Script Running ################"
  logit "  *** Script Version : $SCRIPT_VER"
  logit "  *** Script filename : \"$ME\" "
  logit "  *** Script logfile : \"$LOGFILE\" "
  logit "  *** Script date run : $DDMMYY2"
  logit "  *** Parameter One (Input File): \"$PARONE\" "
  logit "  *** Parameter Two (Single Delimeter): \"$PARTWO\" "
  logit "  *** Parameter Three (Number of Columns): \"$PARTHREE\" "
  logit "################ Unisys $ME Script Running ################"

}

trimWhiteSpace() {


  if [ "$1" != "" ];then
    ## remove white space before and after data field ...
    TEMP_STR=$(echo $1|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    ## And add delimeter at the end of data field  ...
    TEMP_STR=$TEMP_STR"$PARTWO"
  fi

}

### mainline logic

OLD_IFS=$IFS
IFS=$'\n'

header

if [ -f $PARONE.CSV ];then
  rm -rf $PARONE.CSV
  logit "   Cleaning up old file \"$PARONE.CSV\" - [ OK ]"
fi

LINECTR=1
ARRCTR=1
CUTBEG=1
CUTEND=50

## myFieldsArray=( "nul", "nul", "nul" )

for line in $(cat $PARONE)
do
  logit "DEBUG : CTR=$LINECTR : RAW Line : $line "

  while [ $ARRCTR -lt $PARTHREE ]
  do
    rawFIELD=$(echo $line|cut -c$CUTBEG-$CUTEND)
    trimWhiteSpace "$rawFIELD"
    myFieldsArray[$ARRCTR]=$TEMP_STR

    NEWFIELD=$(echo ${myFieldsArray[$ARRCTR]})
    logit "  DEBUG Single Field = \"$NEWFIELD\" - CUTBEG = $CUTBEG && CUTEND = $CUTEND [ OK ]  "

    ARRCTR=$(expr $ARRCTR + 1)
    CUTBEG=$(expr $CUTBEG + 50)
    CUTEND=$(expr $CUTEND + 50)

  done

  logit "   -> Writing newline into \"$PARTWO\" Delimeted field [ OK ]"

  echo ${myFieldsArray[*]} >> $PARONE.CSV

  line

  ## one line of data in the array ...

  LINECTR=$(expr $LINECTR + 1)
  ARRCTR=1
  CUTBEG=1
  CUTEND=50

done

IFS=$OLD_IFS

exit 0



