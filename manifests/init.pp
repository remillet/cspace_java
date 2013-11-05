# == Class: cspace_java
#
# Full description of class cspace_java here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { cspace_java:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <richard.millet@berkeley.edu>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#
class cspace_java {

  exec { 'Hello' :
    command => '/bin/echo howdy software-properties-common  >/tmp/howdy.txt',
  }
  
  exec { 'apt-get-update' :
    command => '/usr/bin/apt-get -y update',
  }
  
  package { 'software-properties-common' :
    ensure => installed,
    require => Exec[apt-get-update],
  }

  package { 'python-software-properties' :
    ensure => installed,
    require => Package[software-properties-common],
  }
  
  exec { 'add-apt-repository' :
    command => '/usr/bin/add-apt-repository ppa:webupd8team/java',
    require => Package[python-software-properties],
  }
  
  exec { 'apt-get-update-webupd8team' :
    command => '/usr/bin/apt-get -y update',    
    require => Exec[add-apt-repository],
  }
  
  exec { 'accept-oracle-license' :
    command => '/bin/echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections',
    require => Exec[apt-get-update-webupd8team],
  }
  
  package { 'oracle-jdk7-installer' :
    ensure => installed,
    require => Exec[accept-oracle-license],
  }
  
}

include cspace_java
