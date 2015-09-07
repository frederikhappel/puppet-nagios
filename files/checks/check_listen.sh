#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Nagios plugin to check if a process is listening on specified address and port
#

# get params
proto=$1
bind=$2
daemon=$3

# defaults
dir_plugins=$(dirname $0)
bind=$(echo ${bind} | sed "s/0\.0\.0\.0://")

# source nagios utils.sh
if [ "${proto}" != "udp" -a "${proto}" != "tcp" ] || [ -z "${bind}" ] ; then
  echo "UNKNOWN - parameter missing"
  echo "usage: $0 <protocol> <address:port>"
  exit 3
elif ! . ${dir_plugins}/utils.sh ; then
  echo "UNKNOWN - missing nagios utils.sh"
  exit 3
fi

# main program
LANG=C
LC_ALL=C
process=$(sudo /bin/netstat -pln --${proto} 2>/dev/null | grep ${bind} | cut -d'/' -f2  | sed "s/[[:blank:]]*//g")
if [ ! -z "${process}" ] ; then
  if [ ! -z "${daemon}" -a "${daemon}" != "${process}" ] ; then
    echo "WARNING - found '${process}' instead of '${daemon}' listening on ${bind}/${proto}"
    exit ${STATE_WARNING}
  else
    echo "OK - found '${process}' listening on ${bind}/${proto}"
    exit ${STATE_OK}
  fi
fi

echo "CRITICAL - found no process listening on ${bind}/${proto}"
exit ${STATE_CRITICAL}
