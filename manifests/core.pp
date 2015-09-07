class nagios::core (
  $type = 'hybrid',
  $nsca_enabled = false,
  $enable_environment_macros = false,
  $enable_notifications = true,
  $process_performance_data = false,
  $status_update_interval = 10,
  $max_concurrent_checks = 500,
  $check_result_reaper_frequency = 3,
  $max_check_result_reaper_time = 10,
  $user_comment = "Puppet ${name}",
  $deployment_domain = $::domain,
  $nrpe_ports = [5666, 12489],
  $allowed_zones = ['all'],
  $broker_modules = [],
  $standby_hosts = [],
  $runstyle = 'service',
  $version = 'latest',
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_array($nrpe_ports, $broker_modules, $standby_hosts, $allowed_zones)
  validate_bool(
    $nsca_enabled, $enable_environment_macros, $enable_notifications,
    $process_performance_data,
  )
  validate_integer(
    $status_update_interval,
    $max_concurrent_checks, $max_check_result_reaper_time,
    $check_result_reaper_frequency,
  )
  validate_string($user_comment, $deployment_domain, $version)
  validate_re($type, '^(active|passive|hybrid)$')
  validate_re($runstyle, '^(monit|service|daemon|off)$')
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $deployment_tag = "nagios_${deployment_domain}"
  $enable_notifications_real = member($standby_hosts, $::fqdn) ? { true => false, default => $enable_notifications }
  case $type {
    'passive' : {
      $execute_host_checks = false
      $execute_service_checks = false
      $check_host_freshness = true
      $check_service_freshness = true
      $use_retained_scheduling_info = false
    }

    'hybrid' : {
      $execute_host_checks = true
      $execute_service_checks = true
      $check_host_freshness = true
      $check_service_freshness = true
      $use_retained_scheduling_info = false
    }

    'active' : {
      $execute_host_checks = true
      $execute_service_checks = true
      $check_host_freshness = false
      $check_service_freshness = false
      $use_retained_scheduling_info = true
    }
  }

  # include classes
  include ::nagios
  User <| title == $user |> {
    comment => $user_comment,
  }
  class {
    'nagios::core::commands' : # define default commands
      ensure => $ensure ;

    'nagios::core::nagios' :
      ensure => $ensure ;



    'nagios::nsca' :
      ensure => $nsca_enabled ? { true => $ensure, default => absent },
      user => $user,
      group => $group,
      command_file => $command_file,
      require => $nsca_enabled ? { true => User[$user], default => undef } ;

    'nagios::core::failover' :
      ensure => empty($standby_hosts) ? { true => absent, default => $ensure },
      standby_hosts => $standby_hosts ;
  }

  # package management
  # TODO: yum repo ['monitoring']
  yum::versionedpackage {
    $package_name :
      ensure => $ensure,
      version => $version,
      require => User[$user] ;
  }

# add selinux module
#  selinux::module {
#    'nagios' :
#      ensure => $ensure,
#      source => 'puppet:///modules/nagios/selinux_nagios.te' ;
#  }

  # configure shorewall
  @shorewall::rule {
    'nagios_fw2nrpe' :
      action => 'ACCEPT',
      src => 'fw',
      dst => $allowed_zones,
      proto => 'tcp',
      dst_port => $nrpe_ports ;
  }
  @shorewall::policy {
    'nagios_fw2all' : # TODO: what for?
      action => 'ACCEPT',
      src => 'fw',
      dst => $allowed_zones ;
  }

  case $ensure {
    present : {
      # manage files and directories
      File {
        owner => $user,
        group => $group,
        require => Package[$package_name],
      }
      file {
        [$checkresultdir, $perfdatadir, $eventhandlerdir] :
          ensure => directory,
          mode => '0755',
          force => true ;

        $socketdir :
          ensure => directory,
          group => $group_cmd,
          mode => '06774' ;

        [$logdir, $logarchivedir] :
          ensure => directory,
          group => $group_cmd ;

        "${cfgdir}/config.tar.gz" :
          owner => undef,
          group => undef,
          mode => '0644',
          seltype => undef ;

        $cfgfile :
          mode => '0664',
          content => template('nagios/core/nagios.cfg.erb') ;

        $initscript :
          source => 'puppet:///modules/nagios/nagios.sh',
          owner => 0,
          group => 0,
          mode => '0755' ;
      }

      # virtual resources, defined on core only
      Nagios::Core::Resource::Check <||> {
        notify => Service[$service_name],
      }
      Nagios::Core::Resource::Eventhandler <||> {
        notify => Service[$service_name],
      }

      # setup public keys to allow configuration deployment
      if $deployment_domain != undef {
        $sshkeytag = "${name}_${deployment_tag}"
        if $::nagios_sshrsakey == '' {
          exec {
            'nagios_sshkeygen' :
              command => "ssh-keygen -f '${rundir}/.ssh/id_rsa' -N '' -C 'puppet generated key'",
              user => $user,
              creates => "${rundir}/.ssh/id_rsa",
              require => User[$user] ;
          }
        } else {
          @@ssh_authorized_key {
            "${user}@${::fqdn}" :
              tag => $sshkeytag,
              key => $::nagios_sshrsakey,
              type => 'ssh-rsa' ;
          }
          file {
            "${rundir}/.ssh/known_hosts" :
              owner => $user,
              group => $group,
              require => User[$user] ;
          }
          if $::sshrsakey != undef {
            @@sshkey {
              "${::fqdn}_${sshkeytag}" :
                tag => $sshkeytag,
                host_aliases => [$::fqdn, $::ipaddress],
                key => $::sshrsakey,
                type => 'ssh-rsa',
            }
          }
          Sshkey <<| tag == $sshkeytag |>> {
            ensure => $ensure,
            target => "${rundir}/.ssh/known_hosts",
          }
        }
        Ssh_authorized_key <<| tag == $sshkeytag |>> {
          ensure => $ensure,
          user => $user,
          require => User[$user],
        }
      }

      # determine start type
      case $runstyle {
        'monit' : { # run from monit
          @monit::service {
            $service_name :
              content => template('nagios/core/monit.conf.erb'),
              subscribe => [
                File[$cfgfile, $initscript],
                Package[$package_name],
              ],
              require => User[$user] ;
          }
        }

        /(service|daemon)/ : { # run as system service
          service {
            $service_name :
              ensure => $type ? { 'live' => undef, default => running },
              enable => true,
              restart => "service ${service_name} reload",
              hasstatus => true,
              subscribe => [
                File[$cfgfile, $initscript],
                Package[$package_name],
              ],
              before => $nsca_enabled ? { true => Class['nagios::nsca'], default => [] },
              require => User[$user] ;
          }
        }

        /off/ : { # disable service
          service {
            $service_name :
              enable => false,
              hasrestart => true,
              hasstatus => true,
              require => Package[$package_name] ;
          }
        }
      }
    }

    absent : {
      # delete everything
      file {
        [$cfgfile, $logdir, $rundir, $initscript] :
          ensure => absent,
          recurse => true,
          force => true,
          require => Package[$package_name] ;
      }
    }
  }
}
