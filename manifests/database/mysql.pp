#mysql.pp

class opencart::database::mysql (  $ensure = 'present',
                                   $host = 'localhost',
                                   $password_hash = mysql_password('opencart'),
                                   $user = 'opencart',
                                   $dbname = 'opencart',
                                ) {

  include opencart::database::mysql_server

  mysql_database { $dbname:
    collate => 'utf8_unicode_ci',
    ensure => $ensure,
  }
  mysql_user { "${user}@${host}":
    ensure => $ensure,
    password_hash => $password_hash,
  }
  mysql_grant { "${user}@${host}/${dbname}.*":
    ensure => $ensure,
    options => ['GRANT'],
    privileges => ['ALL'],
    table => "${dbname}.*",
    user => "${user}@${host}",
  }
}
