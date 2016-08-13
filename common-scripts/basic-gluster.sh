#!/bin/sh
#
# Setup a simple gluster environment and export a volume through NFS-Ganesha.
#
# This script uses the following environment variables:
# - VOLUME: name of the gluster volume to create
#           this name will also be used as name for the export
#
# The YUM_REPO and GERRIT_* variables are mutually exclusive.
#
# - YUM_REPO: URL to the yum repository (.repo file) for the NFS-Ganesha
#             packages. When this option is used, libntirpc-latest is enabled
#             as well. Leave empty in case patches from Gerrit need testing.
#
# - GERRIT_HOST: when triggered from a new patch submission, this is set to the
#                git server that contains the repository to use.
#
# - GERRIT_PROJECT: project that triggered the build (like ffilz/nfs-ganesha).
#
# - GERRIT_REFSPEC: git tree-ish that can be fetched and checked-out for testing.


# abort if anything fails
set -e

[ -n "${VOLUME}" ]

# be a little bit more verbose
set -x

# enable repositories
yum -y install centos-release-gluster

systemctl start rpcbind

if [ -n "${YUM_REPO}" ]
then
	# for yum-config-manager
	yum -y install yum-utils
	yum-config-manager --add-repo=http://artifacts.ci.centos.org/nfs-ganesha/nightly/libntirpc/libntirpc-latest.repo
	yum-config-manager --add-repo=${YUM_REPO}

	# install the latest version of gluster
	yum -y install nfs-ganesha nfs-ganesha-gluster glusterfs-ganesha

	# start nfs-ganesha service
	systemctl start nfs-ganesha
else
	[ -n "${GERRIT_HOST}" ]
	[ -n "${GERRIT_PROJECT}" ]
	[ -n "${GERRIT_REFSPEC}" ]

	GIT_REPO=$(basename "${GERRIT_PROJECT}")
	GIT_URL="https://${GERRIT_HOST}/${GERRIT_PROJECT}"

	# install NFS-Ganesha build dependencies
	yum -y install git bison flex cmake gcc-c++ libacl-devel krb5-devel \
		dbus-devel libnfsidmap-devel libwbclient-devel libcap-devel \
		libblkid-devel rpm-build redhat-rpm-config glusterfs-api-devel

	git init "${GIT_REPO}"
	pushd "${GIT_REPO}"

	git fetch "${GIT_URL}" "${GERRIT_REFSPEC}"
	git checkout -b "${GERRIT_REFSPEC}" FETCH_HEAD

	# update libntirpc
	git submodule update --init || git submodule sync

	mkdir build
	pushd build

	cmake -DCMAKE_BUILD_TYPE=Maintainer ../src && make install

	# start nfs-ganesha service
	/usr/bin/ganesha.nfsd -L /var/log/ganesha.log \
		-f /etc/ganesha/ganesha.conf -N NIV_EVENT
fi

# create and start gluster volume
systemctl start glusterd
mkdir -p /bricks/${VOLUME}
gluster volume create ${VOLUME} \
	replica 2 \
	$(hostname --fqdn):/bricks/${VOLUME}/b{1,2} force

gluster volume start ${VOLUME} force

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
