class nagios::plugins::common (
  $ensure = present
) inherits nagios::params {
  # validate parameters
  validate_re($ensure, '^(present|absent)$')

  # package management
  package {
    'nagios-plugins-nrpe' :
      ensure => $ensure,
      require => Package['nagios-plugins'] ;
  }

  case $ensure {
    present : {
      package {
        ['perl-Net-SMTP-SSL', 'perl-Net-SMTP-TLS', 'perl-Mail-IMAPClient', 'perl-JSON'] :
          ensure => present ;
      }
      realize(Package['perl-Time-HiRes', 'perl-libwww-perl'])
    }

    absent : {
      # nothing to do here
    }
  }
}
