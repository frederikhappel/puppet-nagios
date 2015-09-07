#!/bin/bash
export TERM=xterm
#
#

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

ACTIVE=`ip addr|grep  "192.168.100.1/24"`

if [ -z "$ACTIVE" ]
then
	echo "OK: backup TK"
	exit $STATE_OK
else

	LINE=`cat /proc/zaptel/* | grep  "singleE1" | grep -c "NO SYNC"`

#	echo $LINE
	if [ $LINE -gt 0 ]
	then
		echo "CRITICAL: PMX Problem? | auf ${HOSTNAME} einloggen und nachgucken"
		exit $STATE_CRITICAL
	else
		echo "OK: PMX on ${HOSTNAME} is up"
		exit $STATE_OK
	fi
fi
	exit $STATE_UNKNOWN
