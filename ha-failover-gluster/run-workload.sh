#!/bin/bash
#
# on a 'client' machine:
# run `run-workload.sh vnodeX.f.q.d.n`
#
# E.g. if a four node cluster with nodes named n{1,2,3,4}.f.q.d.n,
# with 'normal' IP addresses of 
#    192.168.122.{11,12,13,14},
# respectively; and also has floating (or virtual) IP addresses of 
#    192.168.222.{11,12,13,14} allocated for it.
#
# Note: Ideally there should also be corresponding DNS entries or
# /etc/hosts entries (e.g. nv{1,2,3,4}.f.q.d.n) for the floating IPs
# in order to allow using a hostname instead of a dotted IP address.
#
# Then run `run-workload.sh nv2.f.q.d.n` or
#          `run-workload.sh 192.168.222.12`
#

if [ $# != "1" ]; then
	echo "please provide a vhostname or VIP"
	exit 1
fi

mkdir /mnt/fs-drift
mount ${1}:/test /mnt/fs-drift

# tests should have been git-clone'd and prepated by client-setup.sh
cd fs-drift
if [ ! -e my_workload.csv ]; then
	exit 3
fi

# run five minutes of I/O
./fs-drift.py -t /mnt/fs-drift -d 300 -w my_workload.csv
result=$?

umount /mnt/fs-drift

exit ${result}
