class nagios::core::gui (
  $users = { 'admins' => ['nagiosadmin'] },
  $refresh_rate_in_seconds = 30,
  $apache_group = 'apache',
  $ensure = present
) inherits nagios::core::params {
  # validate parameters
  validate_hash($users)
  validate_integer($refresh_rate_in_seconds)
  validate_string($apache_group)
  validate_re($ensure, '^(present|absent)$')

  # set dependency on apache
  require nagios::core

  # define variables
  $cfgfile = "${cfgdir}/cgi.cfg"
  $statuschecker = "${libexecdir}/cgi/monitorcheck.cgi"

  # package management
  # TODO: yum repo ['monitoring']
  package {
    'nagios-gui' :
      ensure => $ensure ; # repo monitoring
  }

  # add selinux module
#  selinux::module {
#    'nagios_gui_classic' :
#      ensure => $ensure,
#      source => 'puppet:///modules/nagios/gui/classic/selinux_nagios_gui_classic.te' ;
#  }

  # set selinux permissions
  selinux::setsefileperm {
    "${libexecdir}/cgi/tac.cgi" :
      ensure => $ensure,
      context => 'httpd_sys_script_exec_t' ;
  }

  case $ensure {
    present : {
      # setup files
      File {
        owner => $user,
        group => $group,
        require => Package['nagios-gui', $package_name],
      }
      # setup files
      file {
        '/usr/bin/nagios' :
          group => $apache_group,
          mode => '0770' ;

        $cfgfile :
          mode => '0664',
          content => template('nagios/core/cgi.cfg.erb') ;

        $statuschecker :
          source => 'puppet:///modules/nagios/monitorcheck.sh',
          mode => '0775' ;
      }

       # TODO: apache configuration
#      @apache::configfile {
#        'nagios' :
#          content => template('nagios/core/apache_vhost.erb'),
#          require => [
#            Class['apache::module::cgi', 'apache::module::php'],
#            Package[$package_name],
#          ] ;
#      }
    }

    absent : {
      # nothing to do here
      file {
        [$cfgfile, $statuschecker] :
          ensure => absent,
          recurse => true,
          force => true,
      }
    }
  }
}
