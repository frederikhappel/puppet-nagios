# == Class: nagios::nrpe::common
#
# Setup common nrpe checks.
#
# === Parameters
#
# [*ensure*]
#   create or remove common nrpe checks (default "present")
#
# === Examples
#
# include nrpe::common
#
class nagios::nrpe::common (
  $ensure = present
) {
  # validate parameters
  validate_re($ensure, '^(present|absent)$')

  # sudoers
  nagios::nrpe::sudoer {
    'NETSTAT' :
      ensure => $ensure,
      command => '/bin/netstat' ;
  }

  # define check commands
  nagios::nrpe::check {
    'check_icmp' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_icmp.sh',
      commands => {
        check_icmp => '$ARG1$ $ARG2$ $ARG3$',
      } ;

    'check_procs_param' :
      ensure => $ensure,
      source => 'check_procs',
      commands => {
        check_procs_param => '-C $ARG1$ -c $ARG2$',
      } ;

    'check_tcp_param' :
      ensure => $ensure,
      source => 'check_tcp',
      commands => {
        check_tcp_param => '-H $ARG1$ -p $ARG2$',
      } ;

    'check_listen.sh' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_listen.sh',
      selctx => 'nagios_unconfined_plugin_exec_t',
      commands => {
        check_listen_tcp => 'tcp $ARG1$',
        check_listen_udp => 'udp $ARG1$',
      },
      require => Nagios::Nrpe::Sudoer['NETSTAT'] ;

    'check_tcp_multi.sh' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_tcp_multi.sh',
      selctx => 'nagios_unconfined_plugin_exec_t',
      commands => {
        check_tcp_multi => '$ARG1$ $ARG2$',
      } ;

    'check_open_files' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_open_files.sh',
      selctx => 'nagios_unconfined_plugin_exec_t',
      sudo => 'root',
      commands => {
        check_open_files => '85 95',
        check_open_files_param => '$ARG1$ $ARG2$ $ARG3$',
      } ;

    'check_connections' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_connections.sh',
      selctx => 'nagios_unconfined_plugin_exec_t',
      sudo => 'root',
      commands => {
        check_connections_param => '$ARG1$ $ARG2$ $ARG3$',
      },
      require => Nagios::Nrpe::Sudoer['NETSTAT'] ;
  }
  @activecheck::service::nrpe {
    'open_files' :
      ensure => $ensure,
      check_interval_in_seconds => 300,
      check_timeout_in_seconds => 120,
      max_check_attempts => 3,
      check_command => 'check_open_files' ;
  }
}
