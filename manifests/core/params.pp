class nagios::core::params inherits nagios::params {
  # define variables
  $service_name = 'nagios'
  $package_name = 'nagios'

  # files and directories
  $tempdir = "/tmp"
  $checkresultdir = "${rundir}/checkresults"
  $perfdatadir = "${rundir}/perfdata"
  $logarchivedir = "${logdir}/archives"
  $resourcesdir = "${cfgddir}/puppet"
  $eventhandlerdir = "${libexecdir}/eventhandlers"
  $plugindir = "${libexecdir}/plugins"

  $cfgfile = "${cfgdir}/nagios.cfg"
  $pidfile = "${rundir}/nagios.pid"
  $initscript = "/etc/init.d/${service_name}"
}
