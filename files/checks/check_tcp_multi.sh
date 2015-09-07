#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Author: Frederik Happel
# Date: 10/18/13
# Purpose: Check tcp connection to multiple server
#
LANG=C

PROGNAME=$(basename $0)
dir_plugins=$(dirname $0)
default_port=$1
server_list=${2//,/ }
params=${@: 3}

# source nagios utils.sh and do sanity checks
if ! . ${dir_plugins}/utils.sh ; then
  exit 3
elif [ -z "${default_port}" ] || [ -z "${server_list}" ] ; then
  echo "Usage: ${PROGNAME} <default_port> <address[:port]>[,<address[:port]>]*"
  exit ${STATE_UNKNOWN}
fi

# iterate over given addresses
exit_code=${STATE_OK}
message=""
for server in ${server_list} ; do
  address=$(echo ${server} | awk -F':' '{print $1}' | sed "s/^.*\///")
  port=$(echo ${server} | awk -F':' '{print $2}')
  port=${port:-${default_port}}
  msg=$(${dir_plugins}/check_tcp -t 3 -p ${port} -H ${address} ${params} 2>&1)
  rc=$?
  if [ ${rc} -gt ${exit_code} ] ; then
    exit_code=${rc}
  fi
  msg=$(echo ${msg} | sed "s/|.*//")
  message="${message}${address}:${port} - ${msg}\n"
done

echo -n -e "${message}"
exit ${exit_code}
