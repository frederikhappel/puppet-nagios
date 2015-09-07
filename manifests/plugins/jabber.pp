class nagios::plugins::jabber (
  $host,
  $port = 5222,
  $user,
  $pass = undef,
  $ensure = present
) inherits nagios::params {
  # validate parameters
  validate_string($host, $user, $pass)
  validate_integer($port)
  validate_ip_port($port)
  validate_re($ensure, '^(present|absent)$')

  # dependency on plugins
  require nagios::plugins::common

  # package management
  package {
    'php-xmpphp':
      ensure => ensure_latest($ensure) ;
  }

  file {
    "${plugindir}/notify_via_jabber.php" :
      ensure => $ensure,
      content => template('nagios/plugins/notify_via_jabber.php.erb'),
      owner => 0,
      group => 0,
      mode => '0755',
      require => Package['php-xmpphp'] ;
  }
}
