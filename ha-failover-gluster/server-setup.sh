#!/bin/bash
#
# run `server-setup node1.f.q.d.n vip1 node2.f.q.d.n vip2 ...`
# or `server-setup node1 vip1 node2 vip2 ...`
#
# assume: passwordless ssh between all nodes
#

ulimit -c unlimited

# comment this out when nfs-ganesha rpms land in repo
enable_test="--enablerepo=centos-gluster38-test"

clustername=$(uuidgen | cut -f 1 -d '-')

gluster_pkgs="glusterfs glusterfs-libs glusterfs-fuse glusterfs-api glusterfs-server glusterfs-client-xlators glusterfs-ganesha glusterfs-cli glusterfs-geo-replication userspace-rcu python-gluster"

ganesha_pkgs="nfs-ganesha nfs-ganesha-gluster"

me=$(hostname -f)
meshort=$(hostname -s)

sshdo()
{
    cmd="ssh ${1} ${2}"
    if [ "${me}" = "${1}" -o \
         "${meshort}" = "${1}" -o \
         "localhost" = "${1}" ]; then
        cmd=${2}
    fi

    ${cmd}
}

num_nodes=$(( $# / 2 ))
for (( i = 1; i <= ${num_nodes}; i++ )); do
	nodes[$i]=$1
	shift
	float_ips[$i]=$1
	shift
done

for node in ${nodes[@]}; do
	sshdo ${node} "yum -y ${enable_test} install ${gluster_pkgs} ${ganesha_pkgs}"
	sshdo ${node} "systemctl enable glusterd"
	sshdo ${node} "systemctl start glusterd"
	sshdo ${node} "mkdir -p /bricks/${clustername}"
	sleep 3
	if [ ${node} != ${me} -a \
             ${node} != ${meshort} ]; then
		gluster peer probe ${node}
	fi
done

rm -f /var/lib/glusterd/nfs/secret.*

ssh-keygen -f /var/lib/glusterd/nfs/secret.pem -N ""

for node in ${nodes[@]}; do
	ssh-copy-id -i /var/lib/glusterd/nfs/secret.pem.pub ${node};
	if [ ${node} != ${me} -a \
             ${node} != ${meshort} ]; then
		scp /var/lib/glusterd/nfs/secret.* ${node}:/var/lib/glusterd/nfs
	fi
done

gluster volume set all cluster.enable-shared-storage enable

sleep 5

for node in ${nodes[@]}; do
	sshdo ${node} "systemctl enable pcsd"
	sshdo ${node} "systemctl start pcsd"
done

for node in ${nodes[@]}; do
	sshdo ${node} "echo demopass | passwd --stdin hacluster"
done

for node in ${nodes[@]}; do
	pcs cluster auth ${node}
done

clusternodes="${nodes[1]}"
for (( i = 2; i <= ${num_nodes}; i++ )); do
	clusternodes="${clusternodes},${nodes[$i]}"
done

cat > /var/tmp/ganesha-ha.conf <<EOF
HA_NAME=${clustername}
HA_VOL_SERVER="${nodes[1]}"
HA_CLUSTER_NODES="${clusternodes}"
EOF

for (( i = 1; i <= ${num_nodes}; i++ )); do
	scratch=${nodes[$i]//./_}
	echo "VIP_${scratch}=\"${float_ips[$i]}\"" >> /var/tmp/ganesha-ha.conf
done
mv /var/tmp/ganesha-ha.conf /etc/ganesha/

ha_vol_cmd=""

if [[ ${num_nodes} = "4" ]]; then
	ha_vol_cmd="${ha_vol_cmd} replica 2"
fi

for node in ${nodes[@]}; do
	ha_vol_cmd="${ha_vol_cmd} ${node}:/bricks/${clustername}"
done

gluster volume create test ${ha_vol_cmd} force
gluster volume set test cache-invalidation off
gluster volume start test
gluster --mode=script nfs-ganesha enable
gluster volume set test ganesha.enable on


