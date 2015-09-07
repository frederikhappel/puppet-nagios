#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Nagios plugin to check hops to host
#

# get params
host=$1
max_hops=$(echo ${2:-1} | awk '{print $1*1}')
num_probes=$(echo ${3:-3} | awk '{print $1*1}')

# defaults
dir_plugins=$(dirname $0)

# source nagios utils.sh
if [ -z "${host}" ] ; then
  echo "UNKNOWN - parameter missing"
  echo "usage: $0 <host> [<max_hops> <num_probes>]"
  exit 3
elif ! . ${dir_plugins}/utils.sh ; then
  echo "UNKNOWN - missing nagios utils.sh"
  exit 3
fi

# main program
LANG=C
LC_ALL=C
ping_output=$(ping -q -c ${num_probes} -t ${max_hops} ${host} 2>&1)
if [ $? -le 1 ] ; then
  num_received=$(echo ${ping_output} | grep '[0-9][0-9]*\W*received' | awk -F',' '{print $2*1}')
  if [ ${num_received} -lt 1 ] ; then
    echo "CRITICAL - no answer"
    exit ${STATE_CRTICAL}
  elif [ ${num_received} -lt ${num_probes} ] ; then
    echo "WARNING - partial answer (received ${num_received} of ${num_probes})"
    exit ${STATE_WARNING}
  elif [ ${num_received} -eq ${num_probes} ] ; then
    echo "OK - received answer to all packets"
    exit ${STATE_OK}
  fi
fi

echo "UNKNOWN - ${ping_output}"
exit ${STATE_UNKNOWN}
