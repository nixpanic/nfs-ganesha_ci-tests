#!/bin/sh
#
# Environment variables used:
#  - NFS_SERVER
#  - EXPORT

# if any command fails, the script should exit
set -e

LOGFILE=/tmp/cthon04.log

# TODO: pynfs Jenkins job actually hardcodes the export to "pynfs"
EXPORT=pynfs

# enable some more output
set -x

[ -n "${NFS_SERVER}" ]
[ -n "${EXPORT}" ]

# install build and runtime dependencies
yum -y install git gcc nfs-utils time

# checkout the connectathon tests
git clone git://git.linux-nfs.org/projects/steved/cthon04.git
cd cthon04
make all

# v3 mount
mount -t nfs -o vers=3 ${NFS_SERVER}:/${EXPORT} /mnt
./server -a  -p /${EXPORT} -m /mnt ${NFS_SERVER} | tee ${LOGFILE}

# v4 mount
mount -t nfs -o vers=4 ${NFS_SERVER}:/${EXPORT} /mnt
./server -a  -p /${EXPORT} -m /mnt ${NFS_SERVER} | tee -a ${LOGFILE}

# implicit exit status from the last command
