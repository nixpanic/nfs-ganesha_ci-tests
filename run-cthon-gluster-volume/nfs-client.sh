#!/bin/sh
#
# Environment variables used:
#  - NFS_SERVER
#  - NFS_SHARE
#  - LOGFILE
 
set -e

#mount the share
mkdir -p /mnt/
mkdir -p /mnt/ganesh-mnt
cd /mnt
git clone git://fedorapeople.org/~steved/cthon04
yum -y install time
cd cthon04
make all

# v3 mount
mount -t nfs -o vers=3 ${NFS_SERVER}:/{NFS_SHARE} /mnt/ganesha-mnt
./server -a  -p /${NFS_SHARE} -m /mnt/ganesha-mnt ${NFS_SERVER} | tee ${LOGFILE}


# v4 mount
mount -t nfs -o vers=4 ${NFS_SERVER}:/{NFS_SHARE} /mnt/ganesha-mnt
./server -a  -p /${NFS_SHARE} -m /mnt/ganesha-mnt ${NFS_SERVER} | tee -a ${LOGFILE}
