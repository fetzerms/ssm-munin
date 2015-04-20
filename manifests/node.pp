# munin::node - Configure a munin node, and export configuration a
# munin master can collect.
#
# Parameters:
#
# allow: List of IPv4 and IPv6 addresses and networks to allow to connect.
#
# config_root: Root directory for munin configuration.
#
# nodeconfig: List of lines to append to the munin node configuration.
#
# host_name: The host name munin node identifies as. Defaults to
# the $::fqdn fact.
#
# log_dir: The log directory for the munin node process. Defaults
# change according to osfamily, see munin::params::node for details.
#
# log_file: Appended to "log_dir". Defaults to "munin-node.log".
#
# log_destination: "file" or "syslog".  Defaults to "file".  If log_destination
# is "syslog", the "log_file" and "log_dir" parameters are ignored, and the
# "syslog_*" parameters are used if set.
#
# syslog_ident: Defaults to undef, which makes munin-node use its
# default of "munin-node".
#
# syslog_facility: Defaults to undef, which makes munin-node use the
# perl Net::Server module default of "daemon". Possible values are any
# syslog facility by number, or lowercase name.
#
# masterconfig: List of configuration lines to append to the munin
# master node definitinon
#
# mastername: The name of the munin master server which will collect
# the node definition.
#
# mastergroup: The group used on the master to construct a FQN for
# this node. Defaults to "", which in turn makes munin master use the
# domain. Note: changing this for a node also means you need to move
# rrd files on the master, or graph history will be lost.
#
# plugins: A hash used by create_resources to create munin::plugin
# instances.
#
# address: The address used in the munin master node definition.
#
# package_name: The name of the munin node package to install.
#
# service_name: The name of the munin node service.
#
# service_ensure: Defaults to "". If set to "running" or "stopped", it
# is used as parameter "ensure" for the munin node service.
#
# export_node: "enabled" or "disabled". Defaults to "enabled".
# Causes the node config to be exported to puppetmaster.
#
# file_group: The UNIX group name owning the configuration files,
# log files, etc.

class munin::node (
  $address         = $munin::params::node::address,
  $allow           = $munin::params::node::allow,
  $config_root     = $munin::params::node::config_root,
  $host_name       = $munin::params::node::host_name,
  $log_dir         = $munin::params::node::log_dir,
  $log_file        = $munin::params::node::log_file,
  $masterconfig    = $munin::params::node::masterconfig,
  $mastergroup     = $munin::params::node::mastergroup,
  $mastername      = $munin::params::node::mastername,
  $nodeconfig      = $munin::params::node::nodeconfig,
  $package_name    = $munin::params::node::package_name,
  $plugins         = $munin::params::node::plugins,
  $service_ensure  = $munin::params::node::service_ensure,
  $service_name    = $munin::params::node::service_name,
  $export_node     = $munin::params::node::export_node,
  $file_group      = $munin::params::node::file_group,
  $log_destination = $munin::params::node::log_destination,
  $syslog_ident    = $munin::params::node::syslog_ident,
  $syslog_facility = $munin::params::node::syslog_facility,
) inherits munin::params::node {

  validate_array($allow)
  validate_array($nodeconfig)
  validate_array($masterconfig)
  if $mastergroup { validate_string($mastergroup) }
  if $mastername { validate_string($mastername) }
  validate_hash($plugins)
  validate_string($address)
  validate_absolute_path($config_root)
  validate_string($package_name)
  validate_string($service_name)
  if $service_ensure { validate_re($service_ensure, '^(running|stopped)$') }
  validate_re($export_node, '^(enabled|disabled)$')
  validate_absolute_path($log_dir)
  validate_re($log_destination, '^(?:file|syslog)$')
  validate_string($log_file)
  validate_string($file_group)

  case $log_destination {
    'file': {
      $_log_file = "${log_dir}/${log_file}"
      validate_absolute_path($_log_file)
    }
    'syslog': {
      $_log_file = 'Sys::Syslog'
      if $syslog_ident { validate_string($syslog_ident) }
      if $syslog_facility {
        validate_string($syslog_facility)
        validate_re($syslog_facility,
                    '^(?:\d+|(?:kern|user|mail|daemon|auth|syslog|lpr|news|uucp|authpriv|ftp|cron|local[0-7]))$')
      }
    }
    default: {
      fail('log_destination is not set')
    }
  }

  if $mastergroup {
    $fqn = "${mastergroup};${host_name}"
  }
  else {
    $fqn = $host_name
  }

  if $service_ensure { $_service_ensure = $service_ensure }
  else { $_service_ensure = undef }

  # Defaults
  File {
    ensure => present,
    owner  => 'root',
    group  => $file_group,
    mode   => '0444',
  }

  package { $package_name:
    ensure => installed,
  }

  service { $service_name:
    ensure  => $_service_ensure,
    enable  => true,
    require => Package[$package_name],
  }

  file { "${config_root}/munin-node.conf":
    content => template('munin/munin-node.conf.erb'),
    require => Package[$package_name],
    notify  => Service[$service_name],
  }

  # Export a node definition to be collected by the munin master
  if $export_node == 'enabled' {
    @@munin::master::node_definition{ $fqn:
      address    => $address,
      mastername => $mastername,
      config     => $masterconfig,
      tag        => [ "munin::master::${mastername}" ]
    }
  }

  # Generate plugin resources from hiera or class parameter.
  create_resources(munin::plugin, $plugins, {})

}
