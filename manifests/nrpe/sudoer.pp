# define a sudoer
define nagios::nrpe::sudoer (
  $command,
  $runas = 'root',
  $ensure = present
) {
  # validate parameters
  if !is_string($command) and !is_array($command) {
    fail('parameter $command has to be of type string or array')
  }
  if !is_string($runas) and !is_array($runas) {
    fail('parameter $runas has to be of type string or array')
  }
  validate_re($ensure, '^(present|absent)$')

  # fully qualify command
  if is_absolute_path($command) or $command == 'ALL' or is_array($command) {
    $command_real = $command
  } else {
    $command_real = "${nagios::params::plugindir}/${command}"
  }

  # manage sudoer
  $name_real = upcase("NAGIOS_${name}")
  users::sudoer {
    $name_real :
      ensure => $ensure,
      user => $nagios::params::user,
      host => 'ALL',
      command => $command_real,
      tag => 'NOPASSWD',
      runas => $runas,
      defaults => '!syslog' ;
  }
}
