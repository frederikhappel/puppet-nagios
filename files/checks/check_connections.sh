#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Author:  Frederik Happel
# Date:    10/31/2014
# Purpose: Check number of active connections for a specific command
#

# defaults
LANG=C
command=$1
dir_plugins=$(dirname $0)

# get parameters
warn=$2
crit=${3:-$warn}
warn=$((warn * 1))
crit=$((crit * 1))

# source nagios utils.sh
if ! . ${dir_plugins}/utils.sh ; then
  echo "UNKNOWN - missing nagios utils.sh"
  exit 3
elif [ -z "$1" ] ; then
  echo "UNKNOWN - Usage: $0 <command> <warning> [<critical>]"
  exit ${STATE_UNKNOWN}
elif [ ${warn} -le 0 ] ; then
  echo "UNKNOWN - warning=${warn} must be greater than 0"
  exit ${STATE_UNKNOWN}
elif [ ${crit} -le 0 ] ; then
  echo "UNKNOWN - critical=${crit} must be greater than 0"
  exit ${STATE_UNKNOWN}
elif [ ${crit} -lt ${warn} ] ; then
  echo "UNKNOWN - critical=${crit} must be greater or equal than warning=${warn}"
  exit ${STATE_UNKNOWN}
fi

# get number of current conections
if ! listen_ports=$(nice -n 10 sudo netstat -plnt 2>/dev/null | grep ${command} | awk '{print $4}' | grep -o "[0-9]*") ; then
  echo "CRITICAL - cannot run netstat"
  exit ${STATE_CRITICAL}
fi
listen_ports_egrep=$(echo ${listen_ports} | sed "s/[[:blank:]]/|/g")
if ! num_connections=$(nice -n 10 sudo netstat -pnt 2>/dev/null | egrep ":(${listen_ports_egrep})" | grep ${command} | wc -l) ; then
  echo "CRITICAL - cannot run netstat"
  exit ${STATE_CRITICAL}
fi

# caculate status and return message
message="${command} is serving ${num_connections} connections | connections=${num_connections};${warn};${crit}"
if [ ${num_connections} -gt ${crit} ] ; then
  echo "CRITICAL - ${message}"
  exit ${STATE_CRITICAL}
elif [ ${num_connections} -gt ${warn} ] ; then
  echo "WARNING - ${message}"
  exit ${STATE_WARNING}
fi

echo "OK - ${message}"
exit ${STATE_OK}
