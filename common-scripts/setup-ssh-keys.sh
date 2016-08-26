#!/bin/sh
#
# Create a private/public ssh-key-pair and distribute it over several systems.
# After running this scripts, the systems can do password-less SSH to/from each
# other.
#

# fail on an any error
set -e

if [ -z "${@}" ]
then
	echo "Usage: setup-ssh-keys.sh <HOSTNAME> [<HOSTNAME>...]"
	exit 1
fi

SSH_KEY_DIR=$(mktemp -p ${PWD} -d)
SSH_COMMAND_ARGS="-t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root"

# remove the key-pair when exiting this script
cleanup() {
	[ -z "${SSH_KEY_DIR}" ] || rm -rf ${SSH_KEY_DIR}
}
trap cleanup EXIT

# create a password-less key
ssh-keygen -N '' -f ${SSH_KEY_DIR}/ci-key

# install the key on all hosts
for HOST in ${@}
do
	# append the public key to authorized_keys
	ssh ${SSH_COMMAND_ARGS} ${HOST} \
		tee -a .ssh/authorized_keys < ${SSH_KEY_DIR}/ci-key.pub > /dev/null

	# use the private key to login on all systems
	ssh ${SSH_COMMAND_ARGS} ${HOST} \
		tee .ssh/id_rsa < ${SSH_KEY_DIR}/ci-key > /dev/null

	# make sure the private key has secure permissions
	ssh ${SSH_COMMAND_ARGS} ${HOST} \
		chmod 0600 .ssh/id_rsa
done

# test login from all the hosts to the others
for MASTER in ${@}
do
	for SLAVE in ${@}
	do
		# no need to do localhost tesing
		[ "${MASTER}" = "${SLAVE}" ] && continue

		# connect to the master, execute an ssh-command to the slave
		ssh ${SSH_COMMAND_ARGS} ${MASTER} \
			ssh ${SSH_COMMAND_ARGS} ${SLAVE} \
				echo "CONNECTION OK: ${MASTER} -> ${SLAVE}"
	done
done

