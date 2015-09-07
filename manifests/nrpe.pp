# == Class: nagios::nrpe
#
# Setup nagios basics and nrpe service.
#
# What it does:
# - manage package "nagios-nrpe"
# - manage file $nrpecfg (default "/etc/nagios/nrpe.cfg")
# - manage directory $confddir (default "/etc/nagios/conf.d")
# - manage directory $plugindir (default "/usr/lib(64)/nagios/plugins")
# - manage selinux policiy for centos 5
# - manage nrpe system service
# - manage shorewall rules if needed
# - include common checks from nrpe::common
# - realize all defined nrpe::check resources
#
# === Parameters
#
# [*allowed_hosts*]
#   hosts that are allowed to connect to the nrpe daemon (default "undef", means no host is allowed)
#
# [*port*]
#   port to listen for connections (default "5666")
#
# [*ensure*]
#   create or remove nrpe configuration (default "present")
#
# === Examples
#
# class {
#   "nrpe" :
#     allowed_hosts => ["10.10.0.13", "192.168.23.45"] ;
# }
#
# This will setup nrpe to
# - listen on port 5666
# - allow connections only from "10.10.0.13" and "192.168.23.45"
# - setup puppet packages
# - manage directories and files
#
class nagios::nrpe (
  $command_timeout_in_seconds = 30,
  $allowed_hosts = [],
  $port = $nagios::nrpe::params::default_port,
  $ensure = present
) inherits nagios::nrpe::params {
  # validate parameters
  validate_array($allowed_hosts)
  validate_ip_port($port)
  validate_integer($command_timeout_in_seconds)
  validate_re($ensure, '^(present|absent)$')

  # include baseclass
  include ::nagios
  realize User[$user]

  # package management
  # TODO: yum repo ['dag', 'fedora-epel']
  package {
    "nagios-nrpe.${::hardwaremodel}" :
      ensure => $ensure, # repo dag
      require => User[$user],
      alias => 'nagios-nrpe' ;

    'nagios-plugins' :
      ensure => ensure_latest($ensure) ; # repo dag
  }
  @package {
    'nagios-plugin-perl' : # repo fedora-epel
      name => 'perl-Nagios-Plugin' ;
  }

  # configure shorewall if needed
  @shorewall::rule {
    'nrpe_all2fw' :
      ensure => $ensure,
      action => 'ACCEPT',
      src => shorewall_zonehost('all', $allowed_hosts),
      dst => 'fw',
      proto => 'tcp',
      dst_port => $port ;
  }

  # configure mcollective if needed
  @mcollective::server::plugin {
    'nrpe' :
      ensure => $ensure,
      type => 'agent',
      ddl => true,
      application => true,
      config => template('nagios/mcollective/agent_nrpe.cfg.erb') ;
  }

  # add selinux module
  selinux::module {
    'nagiosNrpeAllowAll' :
      ensure => $::operatingsystemmajrelease ? { 5 => absent, default => $ensure },
      source => 'puppet:///modules/nagios/selinux_nagiosNrpeAllowAll.te' ;
  }

  case $ensure {
    present: {
      File {
          owner => 0,
          group => 0,
          mode => '0644',
          require => Package['nagios-nrpe', 'nagios-plugins'],
      }
      file {
        $nrpeddir: # manage config directory
          ensure => directory,
          recurse => true,
          purge => true ;

        "${nrpeddir}/default-commands.cfg" :
          content => template('nagios/nrpe/default-commands.cfg.erb') ;

        $plugindir : # add default check scripts
          source => 'puppet:///modules/nagios/common',
          recurse => true,
          mode => '0755' ;

        $cfgfile : # create configuration
          content => template('nagios/nrpe/nrpe.cfg.erb') ;
      }

      # define service
      service {
        $service_name :
          ensure => running,
          enable => true,
          hasrestart => true,
          hasstatus => true,
          subscribe => [
            File[$cfgfile, $nrpeddir, "${nrpeddir}/default-commands.cfg"],
            Selinux::Module['nagiosNrpeAllowAll']
          ],
          require => User[$user] ;
      }

      # add self check
      @nagios::nrpe::check {
        'check_nrpe_process' :
          ensure => $ensure,
          source => 'check_procs',
          commands => {
            check_nrpe_process => '-C nrpe -c 1:',
          },
          manage_script => false ;
      }
      @activecheck::service::nrpe {
        'nrpe_process' :
          ensure => $ensure,
          check_interval_in_seconds => 10,
          check_command => 'check_nrpe_process',
          dependent_service_description => '' ; # This is important to avoid dependency circles
      }

      # realize all defined nagios checks
      class {
        'nagios::nrpe::common' :
          require => File[$cfgfile, $nrpeddir],
      }
      Nagios::Nrpe::Check <||> {
        require => File[$cfgfile, $nrpeddir],
      }
      Nagios::Nrpe::Sudoer <||>
    }

    absent: {
      # delete config file
      file {
        [$nrpeddir, $plugindir, $cfgfile] :
          ensure => absent,
          recurse => true,
          force => true,
          require => Package['nagios-nrpe'] ;
      }
    }
  }
}
