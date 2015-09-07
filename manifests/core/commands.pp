class nagios::core::commands (
  $nrpe_timeout = 30,
  $ensure = present
) {
  # validate parameters
  validate_integer($nrpe_timeout)
  validate_re($ensure, '^(present|absent)$')

  @nagios::core::resource::check {
    'puppet_check_website_response' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_website_response.sh',
      commands => {
        puppet_check_website_response => '-u $ARG1$ -w $ARG2$ -c $ARG3$',
      } ;

    'puppet_check_dummy' :
      ensure => $ensure,
      source => 'puppet:///modules/nagios/checks/check_dummy.sh',
      commands => {
        puppet_check_dummy => ''
      } ;

    'puppet_host-alive-ping' :
      ensure => $ensure,
      source => 'check_icmp',
      commands => {
        puppet_host-alive-ping => '$HOSTADDRESS$ 5 1',
      },
      require => Package['nagios-plugins-nrpe'] ;

    'puppet_host-alive-ssh' :
      ensure => $ensure,
      source => 'check_ssh',
      commands => {
        puppet_host-alive-ssh => '-H $HOSTADDRESS$ -p 22',
      },
      require => Package['nagios-plugins'] ;

    'puppet_check_nrpe' :
      ensure => $ensure,
      source => 'check_nrpe',
      commands => {
        puppet_check_nrpe => "-t ${nrpe_timeout} -H \$HOSTADDRESS\$ -c \$ARG1\$ -a \$ARG2\$",
        puppet_check_nrpe_noargs => "-t ${nrpe_timeout} -H \$HOSTADDRESS\$ -c \$ARG1\$"
      },
      require => Package['nagios-plugins-nrpe'] ;

    'puppet_check_tcp' :
      ensure => $ensure,
      source => 'check_tcp',
      commands => {
        puppet_check_tcp => '-H $HOSTADDRESS$ -p $ARG1$',
      },
      require => Package['nagios-plugins'] ;
  }
}
