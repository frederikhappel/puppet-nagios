class nagios::core::nagmq (
  $pull_bind = '*',
  $pull_port = 5556,
  $pull_hwm = 5000,
  $reply_bind = '*',
  $reply_port = 5557,
  $reply_hwm = 5000,
  $allowed_hosts = [],
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_string($pull_bind, $reply_bind)
  validate_ip_port($pull_port, $reply_port)
  validate_integer($pull_hwm, $reply_hwm)
  validate_array($allowed_hosts)
  validate_re($ensure, '^(present|absent)$')

  # define variables
  $cfgjson_nagmq = "${cfgdir}/nagmq-json.cfg"
  $pull_bind_real = $pull_bind ? { '*' => $::ipaddress, default => $pull_bind }
  $reply_bind_real = $reply_bind ? { '*' => $::ipaddress, default => $reply_bind }

  # package management
  # TODO: yum repo ['zeromq', 'monitoring']
  package {
    'nagmq' : # repo monitoring
      ensure => ensure_latest($ensure) ;
  }

  # configure shorewall if needed
  @shorewall::rule {
    'nagmq_all2fw' :
      ensure => $ensure,
      action => 'ACCEPT',
      src => shorewall_zonehost('all', $allowed_hosts),
      dst => 'fw',
      proto => 'tcp',
      dst_port => [$pull_port, $reply_port] ;
  }

  # add monitoring for zeromq ports
  nagios::nrpe::check {
    'check_nagios_nagmq' :
      ensure => $ensure,
      source => 'check_tcp',
      commands => {
        check_nagios_nagmq_pull => "-H ${pull_bind_real} -p ${pull_port}",
        check_nagios_nagmq_reply => "-H ${reply_bind_real} -p ${reply_port}",
      },
      manage_script => false ;
  }
  @nagioscollector::resource::service {
    'nagios_nagmq_pull' :
      ensure => $ensure,
      check_command => 'puppet_check_nrpe_noargs!check_nagios_nagmq_pull' ;

    'nagios_nagmq_reply' :
      ensure => $ensure,
      check_command => 'puppet_check_nrpe_noargs!check_nagios_nagmq_reply' ;
  }

  # define monit hook
  @monit::include {
    "${service_name}_nagmq" :
      ensure => $ensure,
      content => template('nagios/core/monit_nagmq.include.erb') ;
  }

  case $ensure {
    present : {
      # manage files and directories
      file {
        $cfgjson_nagmq :
          content => template('nagios/core/nagmq-json.cfg.erb'),
          owner => 0,
          group => 0,
          mode => '0644',
          notify => Service[$service_name],
          require => Package['nagmq'] ;
      }
    }

    absent : {
      # delete everything
      file {
        $cfgjson_nagmq :
          ensure => absent,
          recurse => true,
          force => true;
      }
    }
  }
}
