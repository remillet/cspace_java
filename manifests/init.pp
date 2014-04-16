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
      command   => "/usr/sbin/update-alternatives --install ${target_dir}/${cmd} ${cmd} ${source_dir}/${cmd} ${priority}",
      logoutput => on_failure,
    }
  }
  
  # Define a custom resource to configure ('set') commands as defaults
  # via the Linux 'alternatives' system.
  define alternatives-config ( $cmd = $title, $source_dir ) {
    exec { "Config default alternative for ${cmd} pointing to source directory ${source_dir}":
      command   => "/usr/sbin/update-alternatives --set ${cmd} ${source_dir}/${cmd}",
      logoutput => on_failure,
    }
  }
  
  # ---------------------------------------------------------
  # Install Oracle Java
  # ---------------------------------------------------------
  
  # The following values for Java version, update number, and build number
  # MUST be manually updated whenever the Java JDK is updated.
  #
  # TODO: Investigate whether it may be possible to avoid hard-coding
  # specific versions below via the technique discussed at
  # http://stackoverflow.com/a/20705933 (requires Oracle support account).
  $java_version        = '7'
  $update_number       = '55'
  $build_number        = '13'
  
  # The following reflects naming conventions currently used by Oracle.
  # This code will break and require modification if any of the following
  # conventions change, either for Java version numbers or for URLs on
  # Oracle's Java SE downloads website.
  # E.g. gives JDK version '7u55' for Java version 7, update 55
  $jdk_version         = "${java_version}u${update_number}"
  # E.g. gives build version 'b13' for build 13
  $build_version       = "b${build_number}"
  
  $platform = $os_family ? {
      RedHat  => 'linux',
      Debian  => 'linux',
      darwin  => 'macosx',
      windows => 'windows',
  }
  
  $os_bits = $cspace_environment::osbits::os_bits
  $architecture = $os_bits ? {
      32-bit => 'i586',
      64-bit => 'x64',
  }
  
  $filename_extension = $os_family ? {
      RedHat  => '.rpm',
      Debian  => '.tar.gz',
      darwin  => '.dmg',
      windows => '.exe',
  }
  
  $jdk_path_segment    = "${jdk_version}-${build_version}"
  $jdk_filename        = "jdk-${jdk_version}-${platform}-${architecture}${filename_extension}"
  # E.g. gives '7u55-b13/jdk-7u55-linux-x64.rpm' for Java version 7, update 55, build 13,
  # for Linux 64-bit RPM archives on RedHat-based Linux systems
  # and '7u55-b13/jdk-7u55-linux-i586.tar.gz' for Java version 7, update 55, build 13,
  # for Linux 32-bit tarred and gzipped (tarball) archives on Debian-based Linux systems  
  $jdk_url_path        = "${jdk_path_segment}/${jdk_filename}"
  
  # Uncomment for debugging as needed:
  # notice("jdk_url_path=${jdk_url_path}")

  case $os_family {
    
    RedHat, Debian: {
      
      $exec_paths = $linux_exec_paths
      
      exec { 'Find wget executable':
        command   => '/bin/sh -c "command -v wget"',
        path      => $exec_paths,
        logoutput => on_failure,
      }
  
      # The cookie below helps validate that this automated process has
      # its users' consent to agree to Oracle's Java SE license terms.
      #
      # NOTE: this cookie's contents, as well as that validation
      # process in general, is subject to change on Oracle's part.
      # Whenever that changes, this code will need to be changed accordingly.
      $cookie = 'oraclelicense=accept-securebackup-cookie'
      
      # Per http://stackoverflow.com/a/10959815
      $download_cmd = join(
        [
          "wget",
          " --directory-prefix=${temp_dir}",
          " --header \"Cookie: ${cookie}\"",
          " --no-check-certificate",
          " --no-cookies",
          " --no-verbose",
          " --timeout 300", # 5 minutes
          " --tries 2",
          " http://download.oracle.com/otn-pub/java/jdk/${jdk_url_path}",
        ]
      )
            
      exec { 'Download Oracle Java package':
        command   => $download_cmd,
        cwd       => $temp_dir, # may be redundant with --directory-prefix in 'wget' command
        path      => $exec_paths,
        logoutput => true,
        creates   => "${temp_dir}/${jdk_filename}",
        require   => Exec[ 'Find wget executable' ],
      }
      
    }
    
  }
  
  case $os_family {
    
    RedHat: {
                        
      # See in part:
      # http://www.java.com/en/download/help/linux_x64rpm_install.xml
      
      exec { 'Set execute permission on Oracle Java RPM package':
        command   => "chmod a+x ${temp_dir}/${jdk_filename}",
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Exec[ 'Download Oracle Java package' ],
      }
      
      # Installs and removes any older versions.
      # ('--replacepkgs forces installation even if the package is already installed.)
      exec { 'Install and upgrade Oracle Java RPM package':
        command   => "rpm -Uvh --replacepkgs ${temp_dir}/${jdk_filename}",
        path      => $exec_paths,
        logoutput => on_failure,
        before    => Alternatives-install [ 'java', 'javac' ],
        require   => Exec[ 'Set execute permission on Oracle Java RPM package' ],
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
          
  }
    
  case $::operatingsystem {
        
    Debian: {

      # Uncomment for debugging as needed:
      # notice( "Detected Debian" )

      # See https://wiki.debian.org/JavaPackage
    
      augeas { "Add Debian contrib APT repository":
        context => '/files/etc/apt/sources.list',
        # See (older) documentation on constructing Augeas paths at
        # http://projects.puppetlabs.com/projects/1/wiki/puppet_augeas
        # FIXME: the following path makes some positional assumptions and thus is brittle; it can and should be improved.
        changes => "set /files/etc/apt/sources.list/1[type = 'deb' and uri = 'http://http.us.debian.org/debian']/component[2] contrib",
        # Output from 'augtool print /files/etc/apt/sources.list', after 'contrib' repo was manually added:
        # /files/etc/apt/sources.list/1/type = "deb"
        # /files/etc/apt/sources.list/1/uri = "http://http.us.debian.org/debian"
        # /files/etc/apt/sources.list/1/distribution = "wheezy"
        # /files/etc/apt/sources.list/1/component[1] = "main"
        # /files/etc/apt/sources.list/1/component[2] = "contrib"
        require   => Exec[ 'Download Oracle Java package' ],
      }

      exec { 'Update apt-get to reflect the new repository configuration' :
        command   => 'apt-get -y update',  
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Augeas[ 'Add Debian contrib APT repository' ],
      }

      package { 'Install java-package' :
        ensure    => installed,
        name      => 'java-package',
        require   => Exec[ 'Update apt-get to reflect the new repository configuration' ],
      }
    
      # The following are (untested and known to be partly incorrect) placeholders for
      # additional steps required to install Oracle Java 7 on Debian:
    
      # exec { 'Store interactive responses required for automation of make-jpkg' :
      # NOTE: the following command is incorrect for doing so; we need to work out the correct
      # debconf-set-selections values or another equivalent approach.  There is one prompt
      # at which pressing a 'y' and the Enter key (CR?) is required, and a second prompt at
      # which pressing the Enter key by itself is required.  For some possible hints,
      # see http://unix.stackexchange.com/a/106553
      #   command   => 'echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections',
      #   path      => $exec_paths,
      #   logoutput => on_failure,
      #   require   => Package[ 'Install java-package' ],
      # }
      # 
      # exec { 'Create a Debian installer from the Oracle Java tarball' :
      #   command   => "make-jpkg ${$jdk_filename}",
      #   cwd       => $temp_dir,
      #   path      => $exec_paths,
      #   logoutput => on_failure,
      #   require   => Exec[ 'Store interactive responses required for automation of make-jpkg' ],
      # }
      #
      # Via another exec resource here, launch the Debian package manager;
      # e.g. sudo dpkg -i oracle-j2sdk1.7_1.7.0+update55_i386.deb
      # finding this file via the filename convention (also brittle)
      # for the .deb file created via 'make-jpkg'
    
    }
  
    Ubuntu: {
      
      # Uncomment for debugging as needed:
      # notice( "Detected Ubuntu" )

      exec { 'Update apt-get before Java update to reflect current packages' :
        command   => 'apt-get -y update',
        path      => $exec_paths,
        logoutput => on_failure,
      }

      package { 'Install software-properties-common' :
        ensure    => installed,
        name      => 'software-properties-common',
        require   => Exec[ 'Update apt-get before Java update to reflect current packages' ],
      }

      package { 'Install python-software-properties' :
        ensure    => installed,
        name      => 'python-software-properties',
        require   => Package[ 'Install software-properties-common' ],
      }

      # For a non-Exec-based technique for managing APT repositories,
      # see https://github.com/softek/puppet-java7/blob/master/manifests/init.pp
      exec { 'Add an APT repository providing Oracle Java packages' :
        command   => 'add-apt-repository ppa:webupd8team/java',
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Package[ 'Install python-software-properties' ],
      }

      exec { 'Update apt-get to reflect the new repository' :
        command   => 'apt-get -y update',  
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Exec[ 'Add an APT repository providing Oracle Java packages' ],
      }

      # Perform unattended acceptance of the Oracle license agreement and
      # store this acceptance in a configuration file.
      exec { 'Accept Oracle license agreement' :
        command   => 'echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections',
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Exec[ 'Update apt-get to reflect the new repository' ],
      }

      package { 'Install Oracle Java 7' :
        ensure    => installed,
        name      => 'oracle-jdk7-installer',
        require   => Exec[ 'Accept Oracle license agreement' ],
        # before  => Alternatives-install [ 'java', 'javac' ],
      }
    
    }
    
  } # end case $::operatingsystem

  
  # ---------------------------------------------------------
  # Add key Java commands to the Linux 'alternatives' system
  # ---------------------------------------------------------
  
  # TODO: Identify whether building on the existing alternatives
  # package at http://puppetforge.com/adrien/alternatives may
  # provide advantages over Exec-based management here.
  
  case $os_family {

    # At least with Ubuntu 13.10, the installation process set
    # up 'alternatives' pointing to
    # /usr/lib/jvm/java-7-oracle/jre/bin/java and
    # /usr/lib/jvm/java-7-oracle/bin/javac
    #
    # For this reason, we won't set these up explicitly here, unless we
    # determine that older Ubuntu releases may still require that.
    Debian: {
    }
    
    RedHat: {
      
      # RedHat-based systems appear to alias 'update-alternatives' to the
      # executable file 'alternatives', perhaps for cross-platform compatibility.
      
      # TODO: Determine whether there's some non-hard-coded way to identify these paths.
      $java_target_dir  = '/usr/bin' # where to install aliases to java executables
      $java_source_dir  = '/usr/java/latest/bin' # where to find these executables
      
      # Uses custom 'alternatives-install' resource defined above.
      # See http://stackoverflow.com/a/6403457 for this looping technique
      alternatives-install { [ 'java', 'javac' ]:
        target_dir => $java_target_dir,
        source_dir => $java_source_dir,
        before     => Alternatives-config [ 'java', 'javac' ],
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