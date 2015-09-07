class nagios::plugins::googletalk (
  $user,
  $pass = undef,
  $resource = 'nagios',
  $ensure = present
) inherits nagios::params {
  # validate parameters
  validate_string($user, $pass, $resource)
  validate_re($ensure, '^(present|absent)$')

  # dependency on plugins
  require nagios::plugins::common

  # package management
  package {
    'perl-Net-XMPP':
      ensure => ensure_latest($ensure) ;
  }

  file {
    "${plugindir}/notify_via_googletalk.pl" :
      ensure => $ensure,
      content => template('nagios/plugins/notify_via_googletalk.pl.erb'),
      owner => 0,
      group => 0,
      mode => '0755',
      require => Package['perl-Net-XMPP'] ;
  }
}
