# Author:: Nacer Laradji (<nacer.laradji@gmail.com>)
# Cookbook Name:: zabbix
# Recipe:: server_source
#
# Copyright 2011, Efactures
#
# Apache 2.0
#

include_recipe "zabbix::default"

packages = Array.new
case node['platform']
when "ubuntu","debian"
  packages = %w{ fping libcurl4-openssl-dev libiksemel-utils libiksemel-dev libiksemel3 libsnmp-dev snmp}
  case node['zabbix']['database']['install_method']
  when 'mysql', 'rds_mysql'
    packages.push('libmysql++-dev', 'libmysql++3', 'libcurl3', 'php5-mysql', 'php5-gd' )
  when 'postgres'
    packages.push('libssh2-1-dev')
  end
  init_template = 'zabbix_server.init.erb'
when "redhat","centos","scientific","amazon","oracle"
  curldev = (node['platform_version'].to_i < 6) ? 'curl-devel' : 'libcurl-devel'

  packages = %w{ fping iksemel-devel iksemel-utils net-snmp-libs net-snmp-devel openssl-devel redhat-lsb }
  packages.push(curldev)

  case node['zabbix']['database']['install_method']
  when 'mysql', 'rds_mysql'
    php_packages = (node['platform_version'].to_i < 6)?
      %w{ php53-mysql php53-gd php53-bcmath php53-mbstring } :
      %w{ php-mysql php-gd php-bcmath php-mbstring }
    packages.push('mysql-devel')
    packages.push(*php_packages)
  when 'postgres'
    php_packages = (node['platform_version'].to_i < 6)?
      %w{ php5-pgsql php5-gd } :
      %w{ php-pgsql php-gd php-bcmath php-mbstring } 
    packages.push(*php_packages)
  end
  init_template = 'zabbix_server.init-rh.erb'
end

packages.each do |pck|
  package pck do
    action :install
  end
end
configure_options = Array.new
node['zabbix']['server']['configure_options'].each do |option|
  configure_options.push(option) unless option.match(/\s*--prefix(\s|=).+/)
end
case node['zabbix']['database']['install_method']
when 'mysql', 'rds_mysql'
  with_mysql = "--with-mysql"
  configure_options << with_mysql unless configure_options.include?(with_mysql)
when 'postgres'
  with_postgresql = "--with-postgresql"
  configure_options << with_postgresql unless configure_options.include?(with_postgresql)
end
node.set['zabbix']['server']['configure_options'] = configure_options

zabbix_source "install_zabbix_server" do
  branch              node['zabbix']['server']['branch']
  version             node['zabbix']['server']['version']
  code_dir            node['zabbix']['src_dir']
  target_dir          "zabbix-#{node['zabbix']['server']['version']}-server"  
  install_dir         node['zabbix']['install_dir']
  configure_options   configure_options.join(" ")

  action :install_server
end

# Install Init script
template "/etc/init.d/zabbix_server" do
  source init_template
  owner "root"
  group "root"
  mode "755"
  notifies :restart, "service[zabbix_server]", :delayed
end

# install zabbix server conf
template "#{node['zabbix']['etc_dir']}/zabbix_server.conf" do
  source "zabbix_server.conf.erb"
  owner "root"
  group "root"
  mode "644"
  variables ({
    :dbhost     => node['zabbix']['database']['dbhost'],
    :dbname     => node['zabbix']['database']['dbname'],
    :dbuser     => node['zabbix']['database']['dbuser'],
    :dbpassword => node['zabbix']['database']['dbpassword'],
    :dbport     => node['zabbix']['database']['dbport']
  })
  notifies :restart, "service[zabbix_server]", :delayed
end

# Define zabbix_agentd service
service "zabbix_server" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :start, :enable ]
end
