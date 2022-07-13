# Class: rsync::server
#
# The rsync server. Supports both standard rsync as well as rsync over ssh
#
# Requires:
#   class xinetd if use_xinetd is set to true
#   class rsync
#
class rsync::server(
  $use_xinetd = true,
  $address    = '0.0.0.0',
  $motd_file  = 'UNSET',
  Variant[Enum['UNSET'], Stdlib::Absolutepath] $pid_file = '/var/run/rsyncd.pid',
  $use_chroot = 'yes',
  $uid        = 'nobody',
  $gid        = 'nobody',
  $modules    = {},
) inherits rsync {

  if $use_xinetd {
    include xinetd
    xinetd::service { 'rsync':
      bind        => $address,
      port        => '873',
      server      => '/usr/bin/rsync',
      server_args => "--daemon --config ${rsync::conf_file}",
      require     => Package['rsync'],
    }
  } else {

    if ($rsync::rsyncd_package_name) {
      package {$rsync::rsyncd_package_name:
        ensure => $rsync::package_ensure,
        notify => Service[$rsync::servicename],
      }
    }

    service { $rsync::servicename:
      ensure     => running,
      enable     => true,
      hasstatus  => true,
      hasrestart => true,
      subscribe  => Concat[$rsync::conf_file],
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

  concat { $rsync::conf_file: }

  # Template uses:
  # - $use_chroot
  # - $address
  # - $motd_file
  concat::fragment { 'rsyncd_conf_header':
    target  => $rsync::conf_file,
    content => template('rsync/header.erb'),
    order   => '00_header',
  }

  create_resources(rsync::server::module, $modules)

}
