# == Class: cspace_java
#
# Manages the availability of either OpenJDK 7 or the Oracle Java SE (Standard Edition) version 7
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

  $os_family                 = $cspace_environment::osfamily::os_family
  $linux_exec_paths          = $cspace_environment::execpaths::linux_default_exec_paths
  $linux_combined_exec_paths = $cspace_environment::execpaths::linux_combined_exec_paths
  $osx_exec_paths            = $cspace_environment::execpaths::osx_default_exec_paths
  $temp_dir                  = $cspace_environment::tempdir::system_temp_directory
  
  # ---------------------------------------------------------
  # Define custom resources related to the Linux
  # 'alternatives' system
  # ---------------------------------------------------------
  
  # RedHat-based systems appear to alias 'update-alternatives' to RedHat's
  # executable file 'alternatives', perhaps for cross-platform compatibility?
  
  # FIXME: Remove hard-coded '/usr/bin' from command paths below, once we figure out
  # why the 'path' attribute isn't being reflected as expected. (On RedHat-based
  # systems, 'update-alternatives' might be found in '/usr/sbin' instead.)
  
  # Define a custom resource to install commands via the Linux 'alternatives' system.
  define alternatives-install ( $cmd = $title, $target_dir, $source_dir, $priority = '20000' ) {
    exec { "Install alternative for ${cmd} with priority ${priority}":
      command   => "/usr/bin/update-alternatives --install ${target_dir}/${cmd} ${cmd} ${source_dir}/${cmd} ${priority}",
      path      => $linux_combined_exec_paths,
      logoutput => on_failure,
    }
  }
  
  # Define a custom resource to configure ('set') commands as defaults
  # via the Linux 'alternatives' system.
  define alternatives-config ( $cmd = $title, $source_dir ) {
    exec { "Config default alternative for ${cmd} pointing to source directory ${source_dir}":
      command   => "/usr/bin/update-alternatives --set ${cmd} ${source_dir}/${cmd}",
      path      => $linux_combined_exec_paths,
      logoutput => on_failure,
    }
  }
  
  # ---------------------------------------------------------
  # Install OpenJDK
  # ---------------------------------------------------------
  
  # TODO: Successively switch over other Linux distributions to
  # install OpenJDK 7, rather than the Oracle Java SE 7 JDK.
  # (We'll likely start with Debian, then move on to RedHat-based distros.)
  #
  # Before doing so, verify support in each distro for OpenJDK versions.
  # Some distros might not offer current, or long-term, support
  # for version 7. (We currently believe that Debian-based
  # distros will support OpenJDK 7 for some considerable time.)
  
  case $::operatingsystem {
  
    Ubuntu: {
    
      # Uncomment for debugging as needed:
      # notice( "Detected Ubuntu" )

      $exec_paths = $linux_exec_paths

      exec { 'Update apt-get before Java update to reflect current packages' :
        command   => 'apt-get -y update',
        path      => $exec_paths,
        logoutput => on_failure,
      }

      package { 'Install OpenJDK 7' :
        ensure    => installed,
        name      => 'openjdk-7-jdk',
        require   => Exec[ 'Update apt-get before Java update to reflect current packages' ],
      }
          
      # ---------------------------------------------------------
      # Add key Java commands to the Linux 'alternatives' system
      # ---------------------------------------------------------
    
      # Add OpenJDK's key Java commands to the 'alternatives' system.
      #
      # This is valuable in case another Java distribution may already be
      # installed on the target system, or another Java distribution might
      # later be installed alongside OpenJDK.
    
      # TODO: Determine whether there's some non-hard-coded way to identify these paths.
      $java_target_dir  = '/usr/bin' # where to install aliases to java executables
      $java_source_dir  = "/usr/lib/jvm/java-7-openjdk-i386/bin" # where to find these executables
      
      # TODO: Investigate possible use of the Ubuntu 'update-java-alternatives' command.
  
      # Uses custom 'alternatives-install' resource defined above.
      # See http://stackoverflow.com/a/6403457 for this looping technique
      alternatives-install { [ 'java', 'javac' ]:
        target_dir => $java_target_dir,
        source_dir => $java_source_dir,
        before     => Alternatives-config [ 'java', 'javac' ],
        require    => Package[ 'Install OpenJDK 7' ],
      }

      # Uses custom 'alternatives-config' resource defined above.
      alternatives-config { [ 'java', 'javac' ]:
        source_dir => $java_source_dir,
      }
    
    }
    
  } # end case $::operatingsystem

  # ---------------------------------------------------------
  # Install Oracle Java
  # ---------------------------------------------------------
  
  unless $::operatingsystem == 'Ubuntu' {   
  
    # The following values for Java version, update number, and build number
    # MUST be manually updated whenever the Oracle Java SE JDK is updated.
    #
    # TODO: Investigate whether it may be possible to avoid hard-coding
    # specific versions below via the technique discussed at
    # http://stackoverflow.com/a/20705933 (requires Oracle support account).
    #
    # If/when the Java version reaches double-digits ('10'), or if the
    # equivalance between 'Java n' and JDK '1.n' for any version 'n' might
    # be changed, some path and code changes below will be required.
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
            " --timeout 300", # 300 seconds (5 minutes) download timeout
            " --tries 2",
            " http://download.oracle.com/otn-pub/java/jdk/${jdk_url_path}",
          ]
        )
            
        exec { 'Download Oracle Java archive file':
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
          require   => Exec[ 'Download Oracle Java archive file' ],
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
    
      # TODO: Investigate whether we can succinctly install OpenJDK 7
      # under Debian 7/8, as we can under Ubuntu 14.04.x LTS
    
      Debian: {

        # For this technique, see:
        # https://wiki.debian.org/JavaPackage
    
        augeas { 'Add Debian contrib APT repository':
          # See documentation on constructing Augeas paths at
          # http://docs.puppetlabs.com/guides/augeas.html
          #
          # Output from 'augtool print /files/etc/apt/sources.list', after the 'contrib' repo
          # was manually added to the entry specified below. This output was used to construct
          # the 'changes' path below.
          # /files/etc/apt/sources.list/1/type = "deb"
          # /files/etc/apt/sources.list/1/uri = "http://http.us.debian.org/debian"
          # /files/etc/apt/sources.list/1/distribution = "wheezy" # For Debian 7 'wheezy'; will vary by release
          # /files/etc/apt/sources.list/1/component[1] = "main"
          # /files/etc/apt/sources.list/1/component[2] = "contrib"
          #
          # FIXME: the following path makes some positional assumptions and thus is brittle;
          # it can and should be improved:
          changes => "set /files/etc/apt/sources.list/1[type = 'deb' and uri = 'http://http.us.debian.org/debian']/component[2] contrib",
          require => Exec[ 'Download Oracle Java archive file' ],
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
      
        package { 'Install expect' :
          ensure    => installed,
          name      => 'expect',
          require   => Package[ 'Install java-package' ],
        }
      
        # Install and run an Expect script, which is stored in the top-level
        # 'files' directory in the current module.
        $script_source_path = 'puppet:///modules/cspace_java'
        $script_name        = 'make-jpkg-oraclejava.exp'
        $script_path        = "${script_source_path}/${script_name}"
      
        file { 'Create expect script file':
          path    => "${temp_dir}/${script_name}",
          source  => $script_path,
          mode    => '755',
          require => Package[ 'Install expect' ],
        }
      
        # Run an expect script to invoke 'make-jpkg', to generate a .deb package
        # file for installing Oracle Java 7 from Oracle's binary tarball (.tar.gz) file
        # for that Java release. The expect script provides responses at various
        # interactive prompts, allowing 'make-jpkg' to run unattended.
        notify { 'Creating Debian package for Oracle Java':
          message => 'Creating a Debian package from an Oracle Java archive file. This may take a few minutes ...',
          require => File[ 'Create expect script file' ],
        }
        exec { 'Run expect script to make Debian package from Oracle Java archive file':
          # Add a '-d' flag to the 'expect' command below to debug the Expect script, if needed.
          command     => "expect -f ${script_name} ${jdk_filename}",
          cwd         => $temp_dir,
          # make-jpkg needs to run as a non-root user; the non-privileged 'nobody' user appears
          # to work adequately for that purpose.
          user        => 'nobody',
          path        => $linux_combined_exec_paths,
          logoutput   => on_failure,
          require     => Notify[ 'Creating Debian package for Oracle Java' ],
        }
      
        # The following reflects file naming conventions currently used by the
        # 'make-jpkg' script. This code will break and require modification if
        # any of the script's conventions change.
        $build_architecture = $os_bits ? {
            32-bit => 'i386',
            64-bit => 'amd64',
        }
        # E.g. oracle-j2sdk1.7_1.7.0+update55_i386.deb
        $debian_package_name = "oracle-j2sdk1.${java_version}_1.${java_version}.0+update${update_number}_${build_architecture}.deb"
      
        notify { 'Installing Debian package for Oracle Java':
          message => 'Installing Debian package for Oracle Java. This may take a few minutes ...',
          require => Exec[ 'Run expect script to make Debian package from Oracle Java archive file' ],
        }
        exec { 'Install Debian package to install Oracle Java':
          command   => "dpkg --install ${debian_package_name}",
          cwd       => $temp_dir,
          path      => $linux_combined_exec_paths,
          logoutput => on_failure,
          require   => Notify[ 'Installing Debian package for Oracle Java' ],
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
    
      RedHat: {
      
        # TODO: Determine whether there's some non-hard-coded way to identify these paths.
        $java_target_dir  = '/usr/bin' # where to install aliases to java executables
        $java_source_dir  = '/usr/java/latest/bin' # where to find these executables
      
        # Uses custom 'alternatives-install' resource defined above.
        # See http://stackoverflow.com/a/6403457 for this looping technique
        alternatives-install { [ 'java', 'javac' ]:
          target_dir => $java_target_dir,
          source_dir => $java_source_dir,
          before     => Alternatives-config [ 'java', 'javac' ],
          require    => Exec[ 'Install and upgrade Oracle Java RPM package' ],
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
  
    case $::operatingsystem {
        
      Debian: {

        # TODO: Determine whether there's some non-hard-coded way to identify these paths.
        $java_target_dir  = '/usr/bin' # where to install aliases to java executables
        $java_source_dir  = "/usr/lib/jvm/j2sdk1.${java_version}-oracle/bin" # where to find these executables
      
        # Uses custom 'alternatives-install' resource defined above.
        # See http://stackoverflow.com/a/6403457 for this looping technique
        alternatives-install { [ 'java', 'javac' ]:
          target_dir => $java_target_dir,
          source_dir => $java_source_dir,
          before     => Alternatives-config [ 'java', 'javac' ],
          require    => Exec[ 'Install Debian package to install Oracle Java' ],
        }

        # Uses custom 'alternatives-config' resource defined above.
        alternatives-config { [ 'java', 'javac' ]:
          source_dir => $java_source_dir,
        }        
      
      }
    
    } # end case $::operatingsystem
  
  } # end unless $::operatingsystem == ubuntu

}