#!/bin/sh
#
# Environment variables used:
#  - GERRIT_HOST
#  - GERRIT_PROJECT
#  - GERRIT_REFSPEC
#  - BUILD_HOST
 
set -e
 
GIT_REPO=$(basename "${GERRIT_PROJECT}")
GIT_URL="https://${GERRIT_HOST}/${GERRIT_PROJECT}"
 
# install NFS-Ganesha build dependencies
yum -y install git bison flex cmake gcc-c++ libacl-devel krb5-devel dbus-devel libnfsidmap-devel libwbclient-devel libcap-devel libblkid-devel rpm-build redhat-rpm-config
 
# install the latest version of gluster
yum -y install centos-release-gluster
yum -y install glusterfs-api-devel
 
[ -d "${GIT_REPO}" ] && rm -rf "${GIT_REPO}"
git init "${GIT_REPO}"
pushd "${GIT_REPO}"
 
git fetch "${GIT_URL}" "${GERRIT_REFSPEC}"
git checkout -b "${GERRIT_REFSPEC}" FETCH_HEAD
 
# update libntirpc
git submodule update --init || git submodule sync
 
mkdir build
pushd build
 
cmake -DCMAKE_BUILD_TYPE=Maintainer ../src && make install
 
 
#start nfs-ganesha service
/usr/bin/ganesha.nfsd -L /var/log/ganesha.log -f /etc/ganesha/ganesha.conf -N NIV_EVENT
 
 
# create and start gluster volume
glusterd
mkdir -p /bricks
gluster v create vol1 replica 2 ${BUILD_HOST}:/bricks/b1 ${BUILD_HOST}:/bricks/b2 force
gluster v start vol1
 
#disable gluster-nfs
gluster v set vol1 nfs.disable ON
sleep 2
 
#Export the volume
/usr/libexec/ganesha/create-export-ganesha.sh /etc/ganesha vol1
/usr/libexec/ganesha/dbus-send.sh /etc/ganesha on vol1

# wait till server comes out of grace period
sleep 90
