class nagios::nsca (
  $port = 5667,
  $allowed_hosts = [],
  $user = $nagios::params::user,
  $group = $nagios::params::group,
  $command_file = $nagios::params::command_file,
  $aggregate_writes = true,
  $max_packet_age_in_seconds = 15,
  $ensure = present
) inherits nagios::params {
  # validate parameters
  validate_ip_port($port)
  validate_array($allowed_hosts)
  validate_string($user, $group)
  validate_absolute_path($command_file)
  validate_bool($aggregate_writes)
  validate_integer($max_packet_age_in_seconds)
  validate_re($ensure, '^(present|absent)$')

  # include baseclass
  include ::nagios

  # define variables
  $cfgfile = "${cfgdir}/nsca.cfg"

  # package management
  # TODO: yum repo ['monitoring']
  package {
    'nagios-nsca' :
      ensure => $ensure ; # repo mponitoring
  }

  # configure shorewall if needed
  @shorewall::rule {
    'nsca_all2fw' :
      ensure => $ensure,
      action => 'ACCEPT',
      src => shorewall_zonehost('all', $allowed_hosts),
      dst => '$FW',
      proto => 'tcp',
      dst_port => $port ;
  }

  # manage nagios checks
  $nagios_procs_warn = sprintf('%i', 30 * $::processorcount)
  $nagios_procs_crit = sprintf('%i', 45 * $::processorcount)
  @nagios::nrpe::check {
    'check_nagios_nsca' :
      ensure => $ensure,
      source => 'check_procs',
      commands => {
        check_nagios_nsca => "-C nsca -c 1:${nagios_procs_crit} -w 1:${nagios_procs_warn}",
      },
      manage_script => false ;
  }
  @activecheck::service::nrpe {
    'nagios_nsca' :
      ensure => $ensure,
      check_interval_in_seconds => 60,
      check_command => 'check_nagios_nsca' ;
  }

  case $ensure {
    present: {
      file {
        $cfgfile : # create configuration
          content => template('nagios/nsca.cfg.erb'),
          owner => 0,
          group => 0,
          mode => '0644',
          require => Package['nagios-nsca'] ;
      }

      # define service
      service {
        'nsca' :
          ensure => running,
          enable => true,
          hasrestart => true,
          hasstatus => true,
          subscribe => File[$cfgfile],
          require => Package['nagios-nsca'] ;
      }
    }

    absent: {
      # delete config file
      file {
        [$cfgfile] :
          ensure => absent,
          recurse => true,
          force => true,
          require => Package['nagios-nsca'] ;
      }
    }
  }
}
