class nagios::core::failover (
  $standby_hosts,
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_array($standby_hosts)
  validate_re($ensure, '^(present|absent)$')

  users::sudoer {
    'NAGIOS_SUDO' :
      ensure => $ensure,
      host => 'ALL',
      command => 'ALL',
      tag => 'NOPASSWD',
      runas => 'root',
      user => $user ;
  }

  # configure failover
  @nagios::core::resource::eventhandler {
    'handle-master-host-event' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/eventhandlers/handle-master-host-event.sh',
      commands => {
        handle-master-host-event => '$HOSTSTATE$ $HOSTSTATETYPE$',
      },
      require => Package[$package_name] ;

    'handle-master-proc-event' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/eventhandlers/handle-master-proc-event.sh',
      commands => {
        handle-master-proc-event => '$SERVICESTATE$ $SERVICESTATETYPE$',
      },
      require => Package[$package_name] ;
  }

  # manage nagios checks
  @nagios::nrpe::check {
    'check_nagios_failover' :
      ensure => $ensure,
      source => 'check_nagios',
      commands => {
        check_nagios_failover => "-e 5 -F ${rundir}/status.dat -C /usr/bin/nagios",
      },
      manage_script => false ;
  }
  @activecheck::service::nrpe {
    'nagios_failover' :
      ensure => $ensure,
      check_interval_in_seconds => 20,
      check_command => 'check_nagios_failover',
      event_handler => 'handle-master-proc-event',
      only_on_collector => $standby_hosts,
      require => Nagios::Core::Resource::Eventhandler['handle-master-proc-event'] ;
  }
}
