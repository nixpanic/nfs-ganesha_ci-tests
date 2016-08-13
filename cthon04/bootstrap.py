
#
# from: https://raw.githubusercontent.com/kbsingh/centos-ci-scripts/master/build_python_script.py
#
# This script uses the Duffy node management api to get fresh machines to run
# your CI tests on. Once allocated you will be able to ssh into that machine
# as the root user and setup the environ
#
# XXX: You need to add your own api key below, and also set the right cmd= line 
#      needed to run the tests
#
# Please note, this is a basic script, there is no error handling and there are
# no real tests for any exceptions. Patches welcome!

import json, urllib, subprocess, sys, os

url_base="http://admin.ci.centos.org:8080"
ver="7"
arch="x86_64"
count=2
script_ganesha_setup=os.getenv("GANESHA_SETUP")
script_nfs_client=os.getenv("NFS_CLIENT")

# read the API key for Duffy from the ~/duffy.key file
fo=open("/home/nfs-ganesha/duffy.key")
api=fo.read().strip()
fo.close()

# build the URL to request the system(s)
get_nodes_url="%s/Node/get?key=%s&ver=%s&arch=%s&count=%s" % (url_base,api,ver,arch,count)

# request the system
dat=urllib.urlopen(get_nodes_url).read()
b=json.loads(dat)

# NFS-Ganesha Server
cmd="""ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@%s '
	yum -y install curl &&
	curl %s | GERRIT_HOST="%s" GERRIT_PROJECT="%s" GERRIT_REFSPEC="%s" BUILD_HOST="%s" bash -
'""" % (b['hosts'][0], script_ganesha_setup, os.getenv("GERRIT_HOST"), os.getenv("GERRIT_PROJECT"), os.getenv("GERRIT_REFSPEC"), b['hosts'][0])
rtn_code=subprocess.call(cmd, shell=True)

if rtn_code != "0":
       verdict="SUCCESS"
else:
       verdict="FAILURE"

#NFS-Client
cmd="""ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@%s '
	yum -y install curl nfs-utils &&
	curl %s | NFS_SERVER="%s" NFS_SHARE="%s" LOGFILE="%s" bash -
'""" % (b['hosts'][1], script_nfs_client, b['hosts'][0], "vol1", "/tmp/cthon.log")
rtn_code=subprocess.call(cmd, shell=True)

if rtn_code != "0":
       verdict="SUCCESS"
else:
       verdict="FAILURE"

publish='gerrit review --message "' + os.getenv("BUILD_URL") + 'consoleFull : ' + verdict + '" --project '+ os.getenv("GERRIT_PROJECT") + ' --notify=NONE ' +  os.getenv("GERRIT_PATCHSET_REVISION")
#result_submit="ssh -l jenkins-glusterorg -i /home/nfs-ganesha/.ssh/gerrithub\@gluster.org -o StrictHostKeyChecking=no -p 29418 review.gerrithub.io '%s' " % (publish)

rtn_submit=subprocess.call(result_submit, shell=True)

# return the system(s) to duffy
done_nodes_url="%s/Node/done?key=%s&ssid=%s" % (url_base, api, b['ssid'])
das=urllib.urlopen(done_nodes_url).read()

sys.exit(rtn_code)
