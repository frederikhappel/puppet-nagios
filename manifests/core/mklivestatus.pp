class nagios::core::mklivestatus (
  $socket = "${nagios::params::socketdir}/live",
  $port = 6557,
  $allow_from = [],
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_absolute_path($socket)
  validate_ip_port($port)
  validate_array($allow_from)
  validate_re($ensure, '^(present|absent)$')

  # package management
  # TODO: yum repo ['monitoring']
  package {
    'nagios-livestatus' :
      ensure => $ensure, # repo monitoring
      name => 'op5-livestatus' ;

    'unixcat' : # repo monitoring
      ensure => $ensure ;
  }

  # configure shorewall
  @shorewall::rule {
    'nagios_all2mklivestatus' :
      action => 'ACCEPT',
      src => 'all',
      dst => shorewall_zonehost('all', $allow_from),
      proto => 'tcp',
      dst_port => $port ;
  }

  # configure remote access to livestatus
  if $ensure == present {
    # remove unwanted files
    file {
      "${cfgddir}/check_mk_templates.cfg" :
        ensure => absent,
        require => Package['nagios-livestatus'] ;
    }

    include xinetd
    @xinetd::service {
      'mklivestatus' :
        ensure => $ensure,
        cps => '100 3',
        flags => 'NODELAY',
        per_source => 250,
        port => $port,
        server => '/usr/bin/unixcat',
        server_args => $socket,
        socket_type => "stream",
        protocol => "tcp",
        user => $user,
        group => $group_cmd,
        instances => 500,
        wait => false,
        log_on_success => '',
        require => Package['unixcat', 'nagios-livestatus'] ;
    }
  }
}
