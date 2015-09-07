# == Define: nagios::core::resource::check
#
# Setup a check command.
#
# What it does:
# - manage the check script including selinux permissions
# - manage the check command definition
#
define nagios::core::resource::check (
  $commands,
  $script_name = $name,
  $source = undef,
  $content = undef,
  $selctx = 'nagios_services_plugin_exec_t',
  $keep_ownership = false,
  $ensure = present
) {
  # validate parameters
  validate_hash($commands)
  validate_string($script_name, $source, $content, $selctx)
  validate_bool($keep_ownership)
  validate_re($ensure, '^(present|absent)$')

  # determine source of check
  if is_puppet_source($source) {
    # install script from puppet fileserver
    $manage_script = true
    if $script_name == $name {
      $source_parts = split($source, '/')
      $checkscript = "${nagios::core::params::plugindir}/${source_parts[-1]}"
    } else {
      $checkscript = "${nagios::core::params::plugindir}/${script_name}"
    }
    File[$checkscript] {
      ensure => $ensure,
      source => $source,
    }
  } elsif $source != undef {
    # script already there
    $manage_script = false
    if is_absolute_path($source) {
      $checkscript = $source
    } else {
      $checkscript = "${nagios::core::params::plugindir}/${source}"
    }
  } elsif ($content != undef) {
    # define script from template
    $manage_script = true
    $checkscript = "${nagios::core::params::plugindir}/${script_name}"
    File[$checkscript] {
      ensure => $ensure,
      content => $content,
    }
  } else {
    fail('You have to specify either content or source')
  }

  # manage script
  if ($manage_script) {
    file {
      $checkscript :
        mode => '0755',
        seltype => $::operatingsystemmajrelease ? { 5 => undef, default => $selctx },
        owner => $keep_ownership ? { true => [], default => 0 },
        group => $keep_ownership ? { true => [], default => 0 } ;
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
    # install command configurations
    file {
      "${nagios::core::params::resourcesdir}/command_${name}.cfg" :
        ensure => $ensure,
        content => template('nagios/core/commands.cfg.erb'),
    }
  }
}
