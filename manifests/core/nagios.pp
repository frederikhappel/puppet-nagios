class nagios::core::nagios (
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_re($ensure, '^(present|absent)$')

  # sudoers
  @nagios::nrpe::sudoer {
    'NAGIOS_CONFIGCHECK' :
      ensure => $ensure,
      runas => $user,
      command => "/usr/bin/nagios -v ${cfgfile}",
  }

  # manage nagios checks
  @nagios::nrpe::check {
    'check_nagios_process' :
      ensure => $ensure,
      source => 'check_procs',
      commands => {
        check_nagios_process => '-C nagios -c 1:100 -w 1:80',
      },
      manage_script => false ;

    'check_nagios_configuration' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_nagios_configuration.sh',
      selctx => 'nagios_unconfined_plugin_exec_t',
      commands => {
        check_nagios_configuration => '',
      },
      require => Nagios::Nrpe::Sudoer['NAGIOS_CONFIGCHECK'] ;
  }
  @activecheck::service::nrpe {
    'nagios_process' :
      ensure => $ensure,
      check_interval_in_seconds => 60,
      check_command => 'check_nagios_process' ;

    'nagios_configuration' :
      ensure => $ensure,
      check_interval_in_seconds => 60,
      check_command => 'check_nagios_configuration' ;
  }
}
