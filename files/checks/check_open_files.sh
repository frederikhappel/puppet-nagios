#!/bin/bash
# This file is managed by puppet! Do not change!
#
# Author: Frederik Happel
# Date: 02/21/14
# Purpose: Check for processes reaching their limit on open files
#
LANG=C

# get parameters
warn=${1:-85}
crit=${2:-95}
query=$3

# defaults
secs_start=$(date +%s)
dir_plugins=$(dirname $0)
me=$(whoami)
exclude_users="root|nagios"

# source nagios utils.sh
if ! . ${dir_plugins}/utils.sh ; then
  exit 3
fi
status=${STATE_OK}

# sanity checks
if ! echo "${warn}" | grep "^[1-9][0-9]*" >/dev/null || ! echo "${crit}" | grep "^[1-9][0-9]*" >/dev/null ; then
  echo "Usage: $0 [<warn_percent>] [<crit_percent>]"
  exit ${STATE_UNKNOWN}
elif [ ${warn} -lt 0 -o ${warn} -gt 100 ] ; then
  echo "Warning '${warn}' not a valid percent value"
  exit ${STATE_UNKNOWN}
elif [ ${crit} -lt 0 -o ${crit} -gt 100 ] ; then
  echo "Critical '${crit}' not a valid percent value"
  exit ${STATE_UNKNOWN}
elif [ ${crit} -lt ${warn} ] ; then
  echo "Value for critical '${crit}' has to be greater than warning '${warn}'"
  exit ${STATE_UNKNOWN}
elif [ "${me}" != "root" ] ; then
  echo "WARING - Running check as '${me}'. Should be root."
  status=${STATE_WARNING}
fi

# function to set status
function calculate_status {
  local new_status=$1
  if [ ${new_status} -gt ${status} ] ; then
    status=${new_status}
  fi
}

# main program
if [ -z "${query}" ] ; then
  lsof_uniq=$(ps -eF | egrep -v "(${exclude_users})" | awk '{print $2}')
else
  lsof_uniq=$(ps -eF | egrep -v "(${exclude_users})" | grep "${query}" | awk '{print $2}')
fi
for pid in ${lsof_uniq} ; do
  proc_cur=$(ls "/proc/${pid}/fd" 2>/dev/null | wc -w)
  proc_max=$(grep "open files" /proc/${pid}/limits 2>/dev/null | awk '{print $4}')
  if [ ${proc_cur} -gt 0 ] &&  [ ${proc_max} -gt 0 ] ; then
    proc_crit=$((proc_max*crit/100))
    proc_warn=$((proc_max*warn/100))
    proc_cmd=$(cat "/proc/${pid}/cmdline")

    if [ ${proc_cur} -gt ${proc_crit} ] ; then
      echo "CRITICAL - PID ${pid} (${proc_cmd}) has too many open files (${proc_cur}/${proc_crit})"
      calculate_status ${STATE_CRITICAL}
    elif [ ${proc_cur} -gt ${proc_warn} ] ; then
      echo "WARNING - PID ${pid} (${proc_cmd}) has too many open files (${proc_cur}/${proc_warn})"
      calculate_status ${STATE_WARNING}
    fi
  fi
done

exclude_users_clean=$(echo ${exclude_users} | tr '|' ',')
num_procs=$(echo "${lsof_uniq}" | wc -l)
if [ ${status} -eq ${STATE_OK} ] ; then
  echo "OK - all ${num_procs} running processes (not ${exclude_users_clean}) are within nominal parameters"
else
  echo "Found ${num_procs} running processes (not ${exclude_users_clean})"
fi
secs_end=$(date +%s)
echo "Time elapsed: $((secs_end - secs_start))s"

exit ${status}
