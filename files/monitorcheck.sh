#!/bin/bash
# This file is managed by puppet! Do not change!

# defaults
status_file="/var/nagios/status.dat"
pidfile="/var/nagios/nagios.pid"

# main program
echo "Content-type: text/html"
echo
if ! ps -p $(head -n 1 ${pidfile}) &>/dev/null ; then
  echo "NAGIOS NOT RUNNING"
elif grep 'enable_notifications=1' ${status_file} &>/dev/null ; then
  echo "ALL OK"
else
  echo "NOT MASTER"
fi

exit 0
