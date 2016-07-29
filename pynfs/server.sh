#!/bin/sh

VOLUME=pynfs

# abort if anything fails
set -e

# be a little bit more verbose
set -x

# enable repositories
yum -y install centos-release-gluster yum-utils
yum-config-manager --add-repo=http://artifacts.ci.centos.org/nfs-ganesha/nightly/libntirpc/libntirpc-latest.repo
yum-config-manager --add-repo=http://artifacts.ci.centos.org/nfs-ganesha/nightly/nfs-ganesha-next.repo

# install the latest version of gluster
yum -y install nfs-ganesha nfs-ganesha-gluster glusterfs-ganesha

# start nfs-ganesha service
systemctl start rpcbind
systemctl start nfs-ganesha

# create and start gluster volume
systemctl start glusterd
mkdir -p /bricks
gluster v create ${VOLUME} replica 2 $(hostname --fqdn):/bricks/b{1,2} force
gluster v start ${VOLUME} force

#disable gluster-nfs
#gluster v set vol1 nfs.disable on
#sleep 2

#enable cache invalidation
#gluster v set vol1 cache-invalidation on

# TODO: open only the ports needed?
# disable the firewall, otherwise the client can not connect
systemctl stop firewalld || service iptables stop

# TODO: SELinux prevents creating special files on Gluster bricks (bz#1331561)
setenforce 0

# Export the volume
/usr/libexec/ganesha/create-export-ganesha.sh /etc/ganesha ${VOLUME}
/usr/libexec/ganesha/dbus-send.sh /etc/ganesha on ${VOLUME}

# wait till server comes out of grace period
sleep 90
