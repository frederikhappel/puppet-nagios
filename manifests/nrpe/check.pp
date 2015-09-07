# == Define: nagios::nrpe::check
#
# Setup a nrpe check.
#
# What it does:
# - manage the check script including selinux permissions
# - manage the check command definition ("${nrpe::confddir}/${name}.cfg")
#
# === Parameters
#
# [*source*]
#   source for the check file. This can be a puppet source or a path.
#   If the path is not absolute it will be prepended with ${nrpe::plugindir}
#
# [*selctx*]
#   selinux context for the check file (default "nagios_services_plugin_exec_t")
#
# [*commands*]
#   the name of the command (default "undef", means none)
#
# [*ensure*]
#   create or remove nrpe check configuration (default "present")
#
# === Examples
#
# nrpe::check {
#   'check_cpu_usage':
#     source   => 'puppet:///modules/nagios/check_linux_procstat.pl',
#     commands => {
#       check_cpu_usage => "-w \$ARG1\$ -c \$ARG2\$",
#     };
# }
#
# This will setup a nrpe check
# - with name checkscript 'puppet:///modules/nagios/check_linux_procstat.pl'
# - defining internal nagios/nrpe check command name check_cpu_usage
#
define nagios::nrpe::check (
  $script_name = $name,
  $source = undef,
  $content = undef,
  $selctx = 'nagios_services_plugin_exec_t',
  $commands = undef,
  $manage_script = true,
  $keep_ownership = false,
  $sudo = undef,
  $env = [],
  $ensure = present
) {
  # validate parameters
  validate_string($script_name, $source, $content, $selctx)
  if $commands != undef {
    validate_hash($commands)
  }
  validate_bool($manage_script, $keep_ownership)
  validate_array($env)
  validate_re($ensure, '^(present|absent)$')

  # determine source of check
  if is_puppet_source($source) {
    # install nrpe check script from puppet fileserver
    if $script_name == $name {
      $source_parts = split($source, '/')
      $checkscript = "${nagios::params::plugindir}/${source_parts[-1]}"
    } else {
      $checkscript = "${nagios::params::plugindir}/${script_name}"
    }
    File[$checkscript] {
      ensure => $ensure,
      source => $source,
    }
  } elsif $source != undef {
    # check script already there
    if is_absolute_path($source) {
      $checkscript = $source
    } else {
      $checkscript = "${nagios::params::plugindir}/${source}"
    }
  } elsif ($content != undef) {
    # define check script from template
    $checkscript = "${nagios::params::plugindir}/${script_name}"
    File[$checkscript] {
      ensure => $ensure,
      content => $content,
    }
  } else {
    fail('You have to specify either content or source')
  }

  # create sudoer entry
  $sudoer_name = upcase($name)
  nagios::nrpe::sudoer {
    $sudoer_name :
      ensure => $sudo ? { undef => absent, default => $ensure },
      command => $checkscript,
      runas => $sudo ;
  }

  # manage check script
  if ($manage_script) {
    file {
      $checkscript :
        mode => '0755',
        seltype => $::operatingsystemmajrelease ? { 5 => undef, default => $selctx },
        owner => $keep_ownership ? { true => [], default => 0 },
        group => $keep_ownership ? { true => [], default => 0 },
        require => File[$nagios::params::plugindir] ;
    }
    # set selinux permissions
    # TODO: $::operatingsystemmajrelease ? { 5 => $manage_script, default => false }
    selinux::setsefileperm {
      $checkscript :
        ensure => $ensure,
        context => $selctx,
        require => File[$checkscript] ;
    }
  }

  if $commands != undef {
    # install nrpe check command configurations
    file {
      "${nagios::nrpe::params::nrpeddir}/${name}.cfg" :
        ensure => $ensure,
        content => template('nagios/nrpe/check_command.cfg.erb'),
        mode => '0600',
        owner => $nagios::params::user,
        group => $nagios::params::group,
        notify => Service[$nagios::nrpe::params::service_name],
        require => [
          Nagios::Nrpe::Sudoer[$sudoer_name],
          File[$nagios::nrpe::params::nrpeddir],
        ] ;
    }
  }
}
