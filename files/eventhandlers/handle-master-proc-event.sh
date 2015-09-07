#!/bin/sh
# This file is managed by puppet! Do not change!

PROGPATH=$(echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,')

# Only take action on hard service states...
case "$2" in
  HARD)
    case "$1" in
      CRITICAL)
        # The master process is not running!
        # We should now become the master host and
        # take over the responsibility of monitoring
        # the network, so enable notifications...
        sudo ${PROGPATH}/enable_notifications
        ;;

      WARNING|UNKNOWN)
        # The master process may or may not
        # be running.. We won't do anything here, but
        # to be on the safe side you may decide you
        # want the slave host to become the master in
        # these situations...
        ;;

      OK)
        # The master process running again!
        # We should go back to being the slave host,
        # so disable notifications...
        sudo ${PROGPATH}/disable_notifications
        ;;
    esac
  ;;
esac

exit 0
