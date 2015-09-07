#!/bin/sh
#
# chkconfig: 345 99 01
# description: Nagios network monitor
### BEGIN INIT INFO
# Provides:          nagios
# Required-Start:    $local_fs $remote_fs $syslog $named $network $time
# Required-Stop:     $local_fs $remote_fs $syslog $named $network
# Should-Start:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: start and stop Nagios monitoring daemon
# Description:       Nagios is a service monitoring system
### END INIT INFO
#
# File : nagios
#
# Author : unknown
#
# Changelog :
#
# 2012-10-24 Frederik Happel <mail@frederikhappel.de>
#  - Rewrote init script, as it was not working
#
#

servicename="nagios"
cfgddir="/etc/nagios/conf.d"
daemon_binary="/usr/bin/nagios"
pidfile="/var/run/nagios.pid"
cfgfile="/etc/nagios/nagios.cfg"
cfgtgz="/etc/nagios/config.tar.gz"
cfgmd5="/etc/nagios/config.md5"
daemon_user="nagios"
daemon_group="nagios"


if [ -d /var/lock/subsys ]; then
  # RedHat/CentOS/etc which use subsys
  lockfile="/var/lock/subsys/${servicename}"
else
  # The rest of them
  lockfile="/var/lock/${servicename}"
fi

# sanity checks
if [ ! -f "${daemon_binary}" ]; then
  # Check that ido2db exists.
  echo "Executable file ${daemon_binary} not found.  Exiting."
  exit 1
elif [ ! -f "${cfgfile}" ]; then
  # Check that ido2db.cfg exists.
  echo "Configuration file ${cfgfile} not found.  Exiting."
  exit 1
fi

# Source function library.
. /etc/init.d/functions

#add ocilib lib path to link at runtime if enabled
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:
export LD_LIBRARY_PATH

if [ -f "/etc/sysconfig/${servicename}" ]; then
  . "/etc/sysconfig/${servicename}"
fi

# Determine if we can use the -p option to daemon, killproc, and status.
# RHEL < 5 can't.
if status | grep -q -- '-p' 2>/dev/null; then
  daemonopts="--pidfile ${pidfile}"
  pidopts="-p ${pidfile}"
fi

start() {
  echo -n "Starting ${servicename}: "
  # Only try to start if not already started
  if ! rh_status_q; then
    touch ${pidfile}
    chown ${daemon_user}:${daemon_group} ${pidfile}
    daemon ${daemonopts} ${daemon_binary} -d ${cfgfile}
  fi
  # This will be 0 if daemon is already running
  RETVAL=$?
  if [ $RETVAL -eq 0 ] ; then
    touch ${lockfile}
    ps auxwww | grep -v grep | grep "${daemon_binary} -d ${cfgfile}" | awk '{ print $2 }' > ${pidfile}
    success
  else
    failure
  fi
  echo
  return $RETVAL
}

stop() {
  echo -n "Shutting down ${servicename}: "
  # If running, try to stop it
  if rh_status_q; then
    killproc ${pidopts} -d 10 ${daemon_binary}
  else
    # Non-zero status either means lockfile and pidfile need cleanup (1 and 2)
    # or the process is already stopped (3), so we can just call true to
    # trigger the cleanup that happens below.
    true
  fi
  RETVAL=$?
  if pgrep -f ${daemon_binary} &>/dev/null ; then
    pkill -9 -f ${daemon_binary} &>/dev/null
    RETVAL=$?
  fi
  echo
  rm -f ${lockfile} ${pidfile}
  return $RETVAL
}

reload() {
  echo -n "Reloading ${servicename}: "
  # If running, try to reload
  if rh_status_q; then
    # check if configuration changed
    if md5sum -c ${cfgmd5} &>/dev/null ; then
      echo -n "configuration unchanged"
      success
      RETVAL=0
    else
      find ${cfgddir} -type f | xargs md5sum >  ${cfgmd5}
      killproc ${pidopts} ${daemon_binary} -HUP
      success
      RETVAL=$?
    fi
  else
    echo -n "not running"
    failure
    RETVAL=1
  fi
  echo
  return $RETVAL
}

checkconfig() {
  show_errors=$1
  checkresults="/var/nagios/nagios.chk"

  echo -n "Running ${servicename} configuration check"
  ${daemon_binary} -v ${cfgfile} > ${checkresults} 2>&1
  RETVAL=$?
  if [ $RETVAL = 0 ] ; then
    rm -f ${checkresults}
    success
    echo
  else
    failure
    if [ "${show_errors}" == "true" ] ; then
      cat ${checkresults}
      echo "Result saved to ${checkresults}"
    else
      echo "CONFIG ERROR! See ${checkresults} for details."
    fi
  fi
  return $RETVAL
}

# function to test config and reload nagios
deploylocal() {
  RETVAL=0
  echo -n "Deploying new configuration "
  if [ ! -f ${cfgtgz} ] ; then
    RETVAL=1
    failure
    echo "Archive '${cfgtgz}' does not exist!"
  else
    # build test directory structure
    testdir=$(mktemp -d)
    chown ${daemon_user}:${daemon_group} ${cfgtgz}
    cp -au ${cfgddir}/* ${testdir}
    tar -C ${testdir} -xzf ${cfgtgz}

    # generate nagios.conf for testing the new config
    test_cfg="${testdir}/nagios-test.cfg"
    echo "# generated for testing purposes" > ${test_cfg}
    for cfg_dir in $(find ${testdir}/* -type d) ; do
      echo "cfg_dir=${cfg_dir}" >> ${test_cfg}
    done
    chown ${daemon_user}:${daemon_group} -R ${testdir}
    grep -v 'cfg_dir' ${cfgfile} >> ${test_cfg}
    if nagios -v ${test_cfg} ; then
      /bin/rm -f ${test_cfg}
      /bin/cp -a ${testdir}/* ${cfgddir} 2>/dev/null
      success
    else
      RETVAL=1
      failure
    fi
    /bin/rm -rf ${testdir}
    echo
  fi

  return $RETVAL
}

rh_status() {
  status ${pidopts} ${daemon_binary}
  RETVAL=$?
  return $RETVAL
}

rh_status_q() {
  rh_status >/dev/null 2>&1
}

# See how we were called.
case "$1" in
  start)
    checkconfig && start
    ;;
  stop)
    stop
    ;;
  restart)
    if checkconfig ; then
      stop
      sleep 5
      start
    fi
    ;;
  reload|force-reload)
    checkconfig && reload
    ;;
  status)
    rh_status
    ;;
  checkconfig)
    checkconfig
    ;;
  show-errors)
    checkconfig true
    ;;
  deploy-local)
    deploylocal && reload
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|reload|force-reload|status|checkconfig|show-errors|deploy-local}"
    RETVAL=2
    ;;
esac

exit $RETVAL
