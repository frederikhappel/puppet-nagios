#!/bin/bash
export TERM=xterm
#
#

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

LINE=`/usr/sbin/asterisk -vr -x "show channels" | grep -a "SIP/test"`
#echo $LINE

if [ "$LINE" ]; then
        echo "CRITICAL: RHTec Leitung in Betrieb, PMX down? | oder nur ein anruf auf der alten nummer?"
        exit $STATE_CRITICAL

elif [ -z "$LINE" ]; then
        echo "OK: RHTec Leitung nicht in Betrieb"
        exit $STATE_OK

else
        exit $STATE_UNKNOWN
fi
exit $STATE_UNKNOWN

