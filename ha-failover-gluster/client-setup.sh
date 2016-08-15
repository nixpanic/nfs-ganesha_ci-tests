#!/bin/bash

yum -y install git numpy

git clone https://github.com/parallel-fs-utils/fs-drift.git

cd fs-drift

if [ ! -e my_workload.csv ]; then

	cat > my_workload.csv << EOF
read,10
create,30
append,60
delete,5
rename,1
EOF

fi

if [ ! -e my_workload.csv ]; then
	exit 3
fi

exit 0
