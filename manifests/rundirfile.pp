define nagios::rundirfile (
  $source = undef,
  $content = undef,
  $selctx = undef,
  $mode = '0640',
  $ensure = present
) {
  # validate parameters
  validate_string($source, $content, $selctx)
  validate_re($ensure, '^(present|absent)$')

  file {
    "${nagios::params::rundir}/${name}" :
      ensure => $ensure,
      source => $source,
      content => $content,
      seltype => $::operatingsystemmajrelease ? { 5 => undef, default => $selctx },
      owner => $nagios::params::user,
      group => $nagios::params::group,
      mode => $mode,
      require => User[$nagios::params::user] ;
  }
}
