#!/bin/sh

# run this on the server that the client mounted from
#
# For a four node cluster with nodes n{1,2,3,4}.f.q.d.n. 
# having corresponding "floating" names nv{1234}.f.q.d.n 
# and associated floating IP addresses.
# If the run-workload.sh is running with nv2.f.q.d.n,
# then run this script on n2.f.q.d.n.

# Note: to run on RHEL6, change /var/run/ganesha.pid
# to /var/run/ganesha.nfsd.pid

if [ -e /var/run/ganesha.pid -a \
     -d /proc/$(cat /var/run/ganesha.pid) ]; then
	kill -9 $(cat /var/run/ganesha.pid)
fi

