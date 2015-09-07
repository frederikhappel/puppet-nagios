class nagios inherits nagios::params {
  # user management
  exec {
    'nagios_checkUser' :
      command => "pkill -TERM -U '${user}'",
      unless => "getent passwd ${user} | grep '^${user}:x:[0-9]*:[0-9]*:.*:${rundir}:/bin/bash\$'",
      returns => [0, 1, 2] ;
  }
  @user {
    $user :
      provider => useradd,
      home => $rundir,
      shell => '/bin/bash',
      managehome => false,
      require => Exec['nagios_checkUser'] ;
  }

  # file management
  File {
    owner => 0,
    group => 0,
  }
  file {
    [$cfgdir, $cfgddir, $libexecdir, $datadir] :
      ensure => directory ;

    $rundir :
      ensure => directory,
      owner => $user,
      group => $group,
      mode => '0755' ;
  }
}
