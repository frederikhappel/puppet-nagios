class nagios::params {
  # files and directories
  $cfgdir = '/etc/nagios'
  $cfgddir = "${cfgdir}/conf.d"
  $libdir = $::hardwaremodel ? { /64$/ => '/usr/lib64', default => '/usr/lib' }
  $libexecdir = "${libdir}/nagios"
  $plugindir = "${libexecdir}/plugins"
  $rundir = '/var/nagios'
  $socketdir = "${rundir}/rw"
  $datadir = "/usr/share/nagios"
  $logdir = '/var/log/nagios'

  $command_file = "${socketdir}/nagios.cmd"

  # user and group
  $user = 'nagios'
  $group = 'nagios'
  $group_cmd = 'nagioscmd'
}
