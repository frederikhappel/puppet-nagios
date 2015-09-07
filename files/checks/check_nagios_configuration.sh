#!/bin/bash
# This file is managed by puppet! Do not change!

# defaults
LANG=C
CFGFILE="/etc/nagios/nagios.cfg"
CHKFILE="/var/nagios/nagios.chk"
dir_plugins=$(dirname $0)

# source nagios utils.sh
if ! . ${dir_plugins}/utils.sh ; then
  echo "UNKNOWN - missing nagios utils.sh"
  exit 3
fi

if sudo -u nagios /usr/bin/nagios -v ${CFGFILE} >/dev/null 2>/dev/null ; then
  echo "OK - Configuration valid"
  exit ${STATE_OK}
fi

error=$(grep -i error ${CHKFILE})
echo -e "CRITICAL - Configuration invalid\n${error}"
exit ${STATE_CRITICAL}
