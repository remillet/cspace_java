# == Class: cspace_java
#
# Manages the availability of Oracle Java 7, a prerequisite for a
# CollectionSpace server installation.
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
#  }
#
# === Authors
#
# Richard Millet <richard.millet@berkeley.edu>
# Aron Roberts <aron@socrates.berkeley.edu>
#
# === Copyright
#
# Copyright © 2013 The Regents of the University of California
#

include cspace_environment::execpaths
include cspace_environment::osfamily

class cspace_java {

  $os_family = $cspace_environment::osfamily::os_family
  $linux_exec_paths = $cspace_environment::execpaths::linux_default_exec_paths
  $osx_exec_paths = $cspace_environment::execpaths::osx_default_exec_paths

  case $os_family {
    
    RedHat: {
      # See in part:
      # http://www.java.com/en/download/help/linux_x64rpm_install.xml
    }
    
    Debian: {
      
      $exec_paths = $linux_exec_paths
      
      exec { 'Update apt-get to reflect current packages and versions' :
        command => 'apt-get -y update',
        path    => $exec_paths,
      }
  
      package { 'Install software-properties-common' :
        ensure  => installed,
        name    => 'software-properties-common',
        require => Exec[ 'Update apt-get to reflect current packages and versions' ],
      }

      package { 'Install python-software-properties' :
        ensure  => installed,
        name    => 'python-software-properties',
        require => Package[ 'Install software-properties-common' ],
      }
  
      exec { 'Add an APT repository providing Oracle Java packages' :
        command => 'add-apt-repository ppa:webupd8team/java',
        path    => $exec_paths,
        require => Package[ 'Install python-software-properties' ],
      }
  
      exec { 'Update apt-get to reflect the new repository' :
        command => 'apt-get -y update',  
        path    => $exec_paths,
        require => Exec[ 'Add an APT repository providing Oracle Java packages' ],
      }
  
      # Perform unattended acceptance of the Oracle license agreement and
      # store this acceptance in a configuration file.
      exec { 'Accept Oracle license agreement' :
        command => 'echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections',
        path    => $exec_paths,
        require => Exec[ 'Update apt-get to reflect the new repository' ],
      }
  
      package { 'Install Oracle Java 7' :
        ensure  => installed,
        name    => 'oracle-jdk7-installer',
        require => Exec[ 'Accept Oracle license agreement' ],
      }

    }
    
    # OS X
    darwin: {
    }
    
    default: {
    }
  
  } # end case
  
}