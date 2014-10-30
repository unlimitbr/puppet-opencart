# init.pp

class opencart ( $source     = 'https://github.com/opencart/opencart.git',
                 $installdir = '/opt/opencart',
                 $vhostname  = $fqdn,
                 $dbhost     = 'localhost',
                 $dbname     = 'opencart',
                 $dbuser     = 'opencart',
                 $dbpass     = false,
                 $version    = '2.0.0.0',
                 $timezone   = 'America/Sao_Paulo'
               ) {

  if !$dbpass {
    fail("The following variables are mandatory: dbpass")
  }
   
  if $dbhost == 'localhost' {
    class { 'opencart::database::mysql':
      ensure        => 'present',
      host          => 'localhost',
      password_hash => mysql_password("${dbpass}"),
      user          => $dbuser, 
      dbname        => $dbname, 
    }
  }

  if !defined(Class['apache']) {
    class { 'apache':
      mpm_module        => 'prefork',
      keepalive         => 'off',
      keepalive_timeout => '4',
      timeout           => '45',
    }
  }
  if !defined(Class['apache::mod::php']) {
    include apache::mod::php
  }

  exec { "create installdir":
    command => "mkdir -p $installdir",
    unless  => "test -d $installdir",
    path    => ["/bin", "/usr/bin", "/usr/sbin", "/usr/local/bin"],
  }

  file { "$installdir/upload":
    ensure => directory,
    owner => 'www-data', group => 'root', mode => '664',
    recurse => true,
    require => Vcsrepo["$installdir"],
  }

  vcsrepo { "$installdir":
    ensure   => present,
    provider => git,
    source   => $source,
    revision => $version,
  }

  # Config file
  exec { "create config.php": 
    command => "touch $installdir/upload/config.php",
    creates => "$installdir/upload/config.php",
    path    => ["/bin", "/usr/bin", "/usr/sbin", "/usr/local/bin"],
    require => Vcsrepo["$installdir"],
  }
  
  exec { "create admin config.php": 
    command => "touch $installdir/upload/admin/config.php",
    creates => "$installdir/upload/admin/config.php",
    path    => ["/bin", "/usr/bin", "/usr/sbin", "/usr/local/bin"],
    require => Vcsrepo["$installdir"],
  }

  # Vhost
  apache::vhost { $vhostname:
    port => '80',
    docroot => "$installdir/upload",
    access_log_file => 'access_opencart.log',
    error_log_file => 'error_opencart.log',
    options => ['Indexes','FollowSymLinks'],
    require => Vcsrepo["$installdir"],
  }

  # Prereqs
  $pkgs = [ 'php5' ]
  ensure_packages ( $pkgs )

  # PHP Cache Config
  php::module { [ 'apc', 
                  'mysql',
                  'curl',
                  'gd',
                  'mcrypt',
                ]: }
  php::module::ini { 'apc':
    settings => {
      'apc.enabled'      => '1',
      'apc.shm_segments' => '1',
      'apc.shm_size'     => '128M',
      'apc.stat'         => '0',
    }
  }

  augeas { "/etc/php5/apache2/php.ini":
    changes => [
      "set date.timezone ${timezone}",
      "set magic_quotes_gpc Off",
      "set register_globals Off",
      "set default_charset UTF-8",
      "set safe_mode Off",
      "set mysql.connect_timeout 20",
      "set session.use_only_cookies On",
      "set session.use_trans_sid Off",
      "set session.cookie_httponly On",
      "set session.gc_maxlifetime 3600",
      "set allow_url_fopen on",
      "set memory_limit 64M",
      "set file_uploads On",
      "set upload_max_filesize 999M",
      "set post_max_size 20M",
      "set max_execution_time 36000",
    ],
    context => "/files/etc/php5/apache2/php.ini/PHP",
  } 


}
