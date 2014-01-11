# == Class: cspace_java
#
# Manages the availability of Oracle Java SE (Standard Edition) version 7
# Java Development Kit (JDK), a prerequisite for a CollectionSpace server installation.
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
# Copyright 2013 The Regents of the University of California

include cspace_environment::execpaths
include cspace_environment::osbits
include cspace_environment::osfamily
include cspace_environment::tempdir
include stdlib # for join()

class cspace_java {

  $os_family        = $cspace_environment::osfamily::os_family
  $linux_exec_paths = $cspace_environment::execpaths::linux_default_exec_paths
  $osx_exec_paths   = $cspace_environment::execpaths::osx_default_exec_paths
  $temp_dir         = $cspace_environment::tempdir::system_temp_directory
  
  # Define a custom resource to install commands via the Linux 'alternatives' system.
  define alternatives-install ( $cmd = $title, $target_dir, $source_dir, $priority = '20000' ) {
    exec { "Install alternative for ${cmd} with priority ${priority}":
      command => "/usr/sbin/update-alternatives --install ${target_dir}/${cmd} ${cmd} ${source_dir}/${cmd} ${priority}"
    }
  }
  
  # Define a custom resource to configure ('set') commands as defaults
  # via the Linux 'alternatives' system.
  define alternatives-config ( $cmd = $title, $source_dir ) {
    exec { "Config default alternative for ${cmd} pointing to source directory ${source_dir}":
      command => "/usr/sbin/update-alternatives --set ${cmd} ${source_dir}/${cmd} "
    }
  }
  
  # ---------------------------------------------------------
  # Install Oracle Java
  # ---------------------------------------------------------
  
  case $os_family {
    
    RedHat: {
      $exec_paths = $linux_exec_paths
      # See in part:
      # http://www.java.com/en/download/help/linux_x64rpm_install.xml
      
      exec { 'Find wget executable':
        command   => '/bin/sh -c "command -v wget"',
        path      => $exec_paths,
      }
      
      # The following values for Java version, update number, and build number
      # MUST be manually updated when the Java JDK is updated.
      #
      # TODO: Investigate whether it may be possible to avoid hard-coding
      # specific versions below via the technique discussed at
      # http://stackoverflow.com/a/20705933 (requires Oracle support account)
      # or any symlinked URLs, such as (the posited, perhaps now obsolete)
      # http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-x64.tar.gz
      $java_version        = '7'
      $update_number       = '45'
      $build_number        = '18'
      # The following reflects naming conventions currently used by Oracle.
      # This code will break and require modification if any of the following
      # conventions change, either for Java version numbers or for URLs on
      # Oracle's Java SE downloads website.
      # E.g. gives JDK version '7u45' for Java version 7, update 45
      $jdk_version         = "${java_version}u${update_number}"
      # E.g. gives build version 'b18' for build 18
      $build_version       = "b${build_number}"
      $jdk_path_segment    = "${jdk_version}-${build_version}"
      $jdk_filename_prefix = "jdk-${jdk_version}"
      $os_bits = $cspace_environment::osbits::os_bits
      if $os_bits == '64-bit' {
        $jdk_filename = "${jdk_filename_prefix}-linux-x64.rpm"
        # E.g. gives '7u45-b18/jdk-7u45-linux-x64.rpm' for Java version 7, update 45, build 18, Linux 64-bit RPM
        $jdk_path = "${jdk_path_segment}/${jdk_filename}"
      } elsif $os_bits == '32-bit' {
        $jdk_filename = "${jdk_filename_prefix}-linux-i586.rpm"
        # E.g. gives '7u45-b18/jdk-7u45-linux-i586.rpm' for Java version 7, update 45, build 18, Linux 32-bit RPM
        $jdk_path = "${jdk_path_segment}/${jdk_filename}"
      } else {
        fail( 'Could not select Oracle Java RPM file for download: unknown value for OS virtual address space' )
      }
      
      # Per http://stackoverflow.com/a/10959815
      # Note that the contents of the cookie below, which helps serve as
      # validation that this automated process has its users' consent to
      # agree to Oracle's Java SE license terms, as well as that validation
      # process in general, is subject to change on Oracle's part.
      $download_cmd = join(
        [
          "wget",
          " --directory-prefix=${temp_dir}",
          " --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com\"",
          " http://download.oracle.com/otn-pub/java/jdk/${jdk_path}",
          " --no-check-certificate",
          " --no-cookies",
          " --no-verbose",
          " --timeout 300", # 5 minutes
          " --tries 2",
        ]
      )
 
      exec { 'Download Oracle Java RPM package':
        command   => $download_cmd,
        cwd       => $temp_dir, # may be redundant with --directory-prefix in 'wget' command
        path      => $exec_paths,
        logoutput => true,
        creates   => "${temp_dir}/${jdk_filename}",
        require   => Exec[ 'Find wget executable' ],
      }
      
      exec { 'Set execute permission on Oracle Java RPM package':
        command => "chmod a+x ${temp_dir}/${jdk_filename}",
        path    => $exec_paths,
        require => Exec[ 'Download Oracle Java RPM package' ],
      }
      
      # Installs and removes any older versions.
      # ('--replacepkgs forces installation even if the package is already installed.)
      exec { 'Install and upgrade Oracle Java RPM package':
        command => "rpm -Uvh --replacepkgs ${temp_dir}/${jdk_filename}",
        path    => $exec_paths,
        require => Exec[ 'Set execute permission on Oracle Java RPM package' ],
        before  => Alternatives-install [ 'java', 'javac' ],
      }
      
    }
    
    Debian: {
      
      $exec_paths = $linux_exec_paths
      
      exec { 'Update apt-get before Java update to reflect current packages' :
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
        before  => Alternatives-install [ 'java', 'javac' ],
      }

    }
    
    # OS X
    darwin: {
      $exec_paths = $osx_exec_paths
    }
    
    # Microsoft Windows
    windows: {
    }
    
    default: {
    }
  
  } # end case
  
  # ---------------------------------------------------------
  # Add key Java commands to the Linux 'alternatives' system
  # ---------------------------------------------------------
  
  # TODO: Identify whether building on the existing alternatives
  # package at http://puppetforge.com/adrien/alternatives may
  # provide advantages over Exec-based management here.
  
  case $os_family {
    
    # FIXME: Verify whether the installation paths are identical in Debian-based
    # distros to those in RedHat-based distros.  If not, split off a Debian case here.
    
    RedHat, Debian: {
      # RedHat-based systems appear to alias 'update-alternatives' to the
      # executable file 'alternatives', perhaps for cross-platform compatibility.
      $java_target_dir  = '/usr/bin' # where to install aliases to java executables
      $java_source_dir  = '/usr/java/latest/bin' # where to find these executables
      
      # Uses custom 'alternatives-install' resource defined above.
      # See http://stackoverflow.com/a/6403457 for this looping technique
      alternatives-install { [ 'java', 'javac' ]:
        target_dir => $java_target_dir,
        source_dir => $java_source_dir,
        before  => Alternatives-config [ 'java', 'javac' ],
      }

      # Uses custom 'alternatives-config' resource defined above.
      alternatives-config { [ 'java', 'javac' ]:
        source_dir => $java_source_dir,
      }  
    }
    
    default: {
      # Do nothing under OS families that don't use this system
    }
    
  } # end case $os_family
  
}