class nagios::plugins::sshnag (
  $ensure = present
) inherits nagios::params {
  # validate parameters
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $user = 'sshnag'
  $script = "/home/${user}/sshnag"

  # ssh nagios user for passive check results
  users::local {
    $user :
      ensure => $ensure,
      uid => 494,
      gid => 494,
      managehome => true ;
  }
  file {
    $script :
      ensure => $ensure,
      mode => '0700',
      owner => $user,
      group => $user,
      source => 'puppet:///modules/nagios/plugins/sshnag.sh',
      require => User['sshnag'] ;
  }
  users::sudoer {
    'SSHNAG_SUDO' :
      ensure => $ensure,
      host => "ALL",
      command => $script,
      tag => "NOPASSWD",
      runas => "root",
      user => $user ;
  }
}
