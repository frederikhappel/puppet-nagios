#!/bin/bash
#echo "doing sudo $@"

if [ "$USER" != "root" ] ; then
  sudo /home/sshnag/sshnag $@
else
  #echo "running as $USER"
  HOSTNAME=$1
  NAME=$2 # "masterslave" "replication"
  code=$3 # 0 1 2 3
  shift 3
  message=$@
  printfcmd="/usr/bin/printf"
  CommandFile="/var/nagios/rw/nagios.cmd"
  datetime=`date +%s`
  #echo "[%i] PROCESS_SERVICE_CHECK_RESULT;${HOSTNAME};${NAME};$code;$message\n" $datetime
  DATA=$($printfcmd "[%i] PROCESS_SERVICE_CHECK_RESULT;${HOSTNAME};${NAME};$code;$message\n" $datetime)
  /bin/echo $DATA >> $CommandFile
  #echo "($DATA)"
fi
