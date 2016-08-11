# Tests to be run in the CentOS CI
Continuous integration helpers for nfs-ganesha. These tests run in the [CentOS
CI](https://ci.centos.org/view/NFS-Ganesha). Most of the tests will use
components from the [CentOS Storage
SIG](https://wiki.centos.org/SpecialityGroups/Storage) for setting up the
backend storage (Gluster and Ceph).

## layout of this branch
`common-scripts` contains helpers that are used to install and configure the
NFS-Ganesha environment.

The other directories contain additional (mostly client-site) test-scripts and
`.xml` files that have been exported from Jenkins through the
[CLI](https://ci.centos.org/cli). Some jobs have additional `.xml` files that
are used for scheduling runs of the jobs. Examples of the jobs with additional
schedulers are in the `nightly-builds` directory.
