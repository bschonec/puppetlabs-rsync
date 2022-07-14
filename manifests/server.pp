# Class: rsync::server
#
# The rsync server. Supports both standard rsync as well as rsync over ssh
#
# Requires:
#   class xinetd if use_xinetd is set to true
#   class rsync
#
class rsync::server(
  Boolean                                       $use_xinetd = true,
  $address                                                  = '0.0.0.0',
  $motd_file                                                = 'UNSET',
  Variant[Enum['UNSET'], Stdlib::Absolutepath]    $pid_file = '/var/run/rsyncd.pid',
  $use_chroot                                               = 'yes',
  $uid                                                      = 'nobody',
  $gid                                                      = 'nobody',
  $modules                                                  = {},
  Optional[String[1]]                         $package_name = undef,
  String[1]                                      $conf_file = '/etc/rsync.conf',
  String[1]                                    $servicename = 'rsync',
  Stdlib::Ensure::Service                   $service_ensure = 'running',
  Variant[Enum['mask'], Boolean]            $service_enable = true,
  $package_ensure                                           = $rsync::package_ensure,
  Boolean                                   $manage_package = $rsync::manage_package,
) inherits rsync {

  # RHEL8 and newer have a separate package for rsyncd daemon.  If we're trying to remove the 
  # rsyncd package on RHEL7 or older, signal an error since the rsync client and rsync daemon
  # are provided by the same package.
  if $facts[os][family] == 'RedHat' and (versioncmp($facts['os']['release']['major'], '8') < 0) and $package_ensure == 'absent' {
    fail("Unable to remove rsyncd package since that would also remove the rsync client package.")
  }

  if $use_xinetd {
    include xinetd
    xinetd::service { 'rsync':
      bind        => $address,
      port        => '873',
      server      => '/usr/bin/rsync',
      server_args => "--daemon --config ${conf_file}",
      require     => Package['rsync'],
    }
  } else {

    # Manage the installation of the rsyncd package?
    if $manage_package {

      # RHEL8 and newer (and their variants) have a separate package for rsyncd daemon.  If the $package_name
      # variable is defined (the variable is defined in the hiera hierarchy), then install the package.
      if $package_name {
        package {$package_name:
          ensure => $package_ensure,
          notify => Service[$servicename],
        }
      }
    }

    service { $servicename:
      ensure     => $service_ensure,
      enable     => $service_enable,
      hasstatus  => true,
      hasrestart => true,
      subscribe  => Concat[$conf_file],
    }

    if ( $facts['os']['family'] == 'Debian' ) {
      file { '/etc/default/rsync':
        source => 'puppet:///modules/rsync/defaults',
        notify => Service['rsync'],
      }
    }
  }

  if $motd_file != 'UNSET' {
    file { '/etc/rsync-motd':
      source => 'puppet:///modules/rsync/motd',
    }
  }

  concat { $conf_file: }

  # Template uses:
  # - $use_chroot
  # - $address
  # - $motd_file
  concat::fragment { 'rsyncd_conf_header':
    target  => $conf_file,
    content => template('rsync/header.erb'),
    order   => '00_header',
  }

  create_resources(rsync::server::module, $modules)

}
