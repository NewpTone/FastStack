#!/usr/bin/env bash 
#SwsStack.sh** is a tool to deploy complete and real OpenStack  service fast.  
  
# This script installs and configures various combinations of *Glance*,  
#*Swift*, *Horizon*, *Keystone*, *Nova*, *Mysql* and others.  
  
# yuxcer@gmail.com (Newptone)  
# Learn more and get the most recent version at http://

## 请使用root执行本脚本！
## Ubuntu 12.04 ("Precise") 部署 OpenStack Essex
## 参考：
## http://hi.baidu.com/chenshake/item/29a7b8c1b96fb82d46d5c0fb
## http://docs.openstack.org/essex/openstack-compute/starter/content/

## 一：准备系统
## 1：下载ubuntu 12.04. 服务器版本
## http://mirrors.ustc.edu.cn/ubuntu-releases/12.04/ubuntu-12.04-server-amd64.iso
## 2：安装OS
## 最小化安装，只需要安装ssh server就可以。
## 装完系统后 更新源里的包,更新系统。确保你装的是最新版本的包。

## 3：设置root权限
## 为了简单，全部都是用root来运行。 
if [ `whoami` != "root" ]; then
        sudo -s
        exec su -c 'sh ./FastStack.sh'
fi
#########################################################################

#install aptitude and related software
apt-get -y install aptitude
aptitude -y install puppet puppetmaster augeas-tools lvm2
aptitude -y install sqlite3 libsqlite3-ruby libactiverecord-ruby git rake
gem install puppetlabs_spec_helper
echo 'Finish Base Package Install!'
#modify Puppet.conf to enable storedconfig and configure database

augtool << EOF
set /files/etc/puppet/puppet.conf/main/storeconfigs true
set /files/etc/puppet/puppet.conf/main/dbadapter sqlite3
set /files/etc/puppet/puppet.conf/main/dblocation /var/lib/puppet/server_data/storeconfigs.sqlite
save
EOF

#add user and group for openstack
addgroup --system --gid 996 nova-volumes
addgroup --system --gid 999 kvm
addgroup --system --gid 998 libvirtd
addgroup --system --gid 997 nova
adduser --system --home /var/lib/libvirt --shell /bin/false --uid 999 --gid 999 --disabled-password libvirt-qemu
adduser --system --home /var/lib/libvirt/dnsmasq --shell /bin/false --uid 998 --gid 998 --disabled-password libvirt-dnsmasq
adduser --system --home /var/lib/nova --shell /bin/false --uid 997 --gid 997 --disabled-password nova
adduser nova libvirtd

#Download the openstack modules
cd /etc/puppet/modules
git clone git://github.com/puppetlabs/puppetlabs-openstack openstack
cd openstack
rake modules:clone


cat > /tmp/puppetlabs-openstack.patch << EOF
diff --git examples/site.pp examples/site.pp
index 879d8fa..fd38d4e 100644
--- examples/site.pp
+++ examples/site.pp
@@ -4,7 +4,9 @@
 #
 
 # deploy a script that can be used to test nova
-class { 'openstack::test_file': }
+class { 'openstack::test_file':
+  image_type => 'ubuntu',
+}
 
 ####### shared variables ##################
 
@@ -21,17 +23,17 @@ \$public_interface        = 'eth0'
 \$private_interface       = 'eth1'
 # credentials
 \$admin_email             = 'root@localhost'
-\$admin_password          = 'admin'
-\$keystone_db_password    = 'keystone_db_pass'
-\$keystone_admin_token    = 'keystone_admin_token'
-\$nova_db_password        = 'nova_pass'
-\$nova_user_password      = 'nova_pass'
-\$glance_db_password      = 'glance_pass'
-\$glance_user_password    = 'glance_pass'
-\$rabbit_password         = 'openstack_rabbit_password'
-\$rabbit_user             = 'openstack_rabbit_user'
-\$fixed_network_range     = '10.0.0.0/24'
-\$floating_network_range  = '192.168.1.64/28'
+\$admin_password          = 'openstack'
+\$keystone_db_password    = 'openstack'
+\$keystone_admin_token    = 'bdbb8df712625fa7d1e0ff1e049e8aab'
+\$nova_db_password        = 'openstack'
+\$nova_user_password      = 'openstack'
+\$glance_db_password      = 'openstack'
+\$glance_user_password    = 'openstack'
+\$rabbit_password         = 'openstack'
+\$rabbit_user             = 'openstack'
+\$fixed_network_range     = '10.1.0.0/16'
+\$floating_network_range  = '172.24.1.0/24'
 # switch this to true to have all service log at verbose
 \$verbose                 = false
 # by default it does not enable atomatically adding floating IPs
@@ -75,7 +77,7 @@ node /openstack_all/ {
 
 # multi-node specific parameters
 
-\$controller_node_address  = '192.168.101.11'
+\$controller_node_address  = '127.0.0.1'
 
 \$controller_node_public   = \$controller_node_address
 \$controller_node_internal = \$controller_node_address
@@ -83,9 +85,9 @@ \$sql_connection         = "mysql://nova:\${nova_db_password}@\${controller_node_in
 
 node /openstack_controller/ {
 
-#  class { 'nova::volume': enabled => true }
+  class { 'nova::volume': enabled => true }
 
-#  class { 'nova::volume::iscsi': }
+  class { 'nova::volume::iscsi': }
 
   class { 'openstack::controller':
     public_address          => \$controller_node_public,
@@ -142,7 +144,7 @@ node /openstack_compute/ {
     vncproxy_host      => \$controller_node_public,
     vnc_enabled        => true,
     verbose            => \$verbose,
-    manage_volumes     => true,
+    manage_volumes     => false,
     nova_volume        => 'nova-volumes'
   }

EOF
cd /etc/puppet/modules/openstack
patch -p0 < /tmp/puppetlabs-openstack.patch

ln -s /etc/puppet/modules/openstack/examples/site.pp /etc/puppet/manifests/init.pp

#Use puppet to apply
puppet apply -l /tmp/manifest.log /etc/puppet/manifest/init.pp

if echo $?=0;then
#Add nova-volumes
dd if=/dev/zero of=/opt/volume.img bs=8M seek=1000 count=0
losetup -f /opt/volume.img
losetup -a 
vgcreate nova-volumes /dev/loop0
fi
# Download a small image for test
cd ~ && mkdir images
cd images
wget http://smoser.brickies.net/ubuntu/ttylinux-uec/ttylinux-uec-amd64-12.1_2.6.35-22_1.tar.gz
tar zxvf ttylinux-uec-amd64-12.1_2.6.35-22_1.tar.gz
source /root/openrc
# Add images to glance
glance add name="tty-kernel" disk_format=aki container_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz
glance add name="tty-ramdisk" disk_format=ari container_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-loader

kernel_id=`glance index | grep 'tty-kernel' | head -1 |  awk -F' ' '{print $1}'`
ram_id=`glance index | grep 'tty-ramdisk' | head -1 |  awk -F' ' '{print $1}'`
glance add name="tty-linux" kernel_id=${kernel_id} ramdisk_id=${ram_id} disk_format=ami container_format=ami < ttylinux-uec-amd64-12.1_2.6.35-22_1.img 

#Add this,is just for good performance in vm 
nova flavor-create m1.thin 6 64 0 1

exit 0
