class nagios::nrpe::params inherits nagios::params {
  # define variables
  $service_name = 'nrpe'
  $default_env = ['LANG=C']
  $default_port = 5666

  # files and directories
  $nrpeddir = "${cfgdir}/nrpe.d"
  $cfgfile = "${cfgdir}/nrpe.cfg"
}
