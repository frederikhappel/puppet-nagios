#!/bin/sh
# This file is managed by puppet! Do not change!
#
# Author:  Chris Freeman (cfree6223@gmail.com)
#          Frederik Happel (mail@frederikhappel.de)
# Date:    10/30/13
# Purpose: Nagios script to check website is up and responding in a timely manner
#
# Version 1.1
# (c) GPLv2 2011
#
# Special thanks to dkwiebe and Konstantine Vinogradov for suggestions and feedback
#
LANG=C

# Print usage statement
usage(){
  error=$1
  echo "RESPONSE: UNKNOWN - Error: ${error}"
  echo "Usage: check_website_response.sh -w <warning milliseconds> -c <critical milliseconds> -u <url> [ -nocert ]"
  exit 3
}

# Output statement and exit
output() {
	echo "RESPONSE: ${STATUS} - ${OUTMSG}""|Response="${TIMEDIFF}"ms;"${WARN}";"${CRIT}";0" 
	if [ "${STATUS}" = "OK" ]; then
	  exit 0
	elif [ "${STATUS}" = "WARNING" ]; then
	  exit 1
	elif [ "${STATUS}" = "CRITICAL" ]; then
	  exit 2
	fi
	exit 3
}

### Main
# Input variables
while getopts w:c:u:n: option
  do case "$option" in
    w) WARN=$OPTARG;;
    c) CRIT=$OPTARG;;
    u) URL=$OPTARG;;
    n) NOCERT=$OPTARG;;
    *) ERROR="Illegal option used"
      usage;;
  esac
done

# sanity checks
for cmd in nc date wget echo awk tr ; do 
if ! which ${cmd} &>/dev/null ; then
    STATUS="UNKNOWN"
    OUTMSG="ERROR: command '${cmd}' does not exist"
    output
  fi
done

if [ ! -n "${WARN}" ] ; then
  usage "Warning not set"
elif [ ! -n "${CRIT}" ] ; then
  usage "Critical not set"
elif [ "${CRIT}" -lt "${WARN}" ] ; then
  usage "Critical must be greater than Warning"
elif [ ! -n "${URL}" ] ; then
  usage "URL not set"
fi
case ${WARN} in
  *[!0-9]*)
    usage "Warning must be an integer in milliseconds"
esac
case ${CRIT} in
  *[!0-9]*)
    usage "Critical must be an integer in milliseconds"
esac

# Check page response time
TIME=$(wget -q ${URL} -O - | grep -i "This page was served from .* in" | sed -e 's/.*in \(.*\) s.*/\1/')
EXITSTATUS=$?
if [ "${EXITSTATUS}" != 0 ]; then
  STATUS="CRITICAL"
else
  TIMEDIFF=$(echo "${TIME} 1000" | awk '{print int( ($1*$2) + 1 )}')
  if [ "${TIMEDIFF}" -lt "${WARN}" ] ; then
    STATUS="OK"
  elif [ "${TIMEDIFF}" -ge "${WARN}" ] && [ "${TIMEDIFF}" -lt "${CRIT}" ]; then
    STATUS="WARNING"
  elif [ "${TIMEDIFF}" -ge "${CRIT}" ]; then
    STATUS="CRITICAL"
  fi
  OUTMSG="${TIMEDIFF} ms"
fi

output
