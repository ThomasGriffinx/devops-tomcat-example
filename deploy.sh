#!/bin/bash
#
# Prerequisites:
#
# 1. The `aws` executable in your path.
# 2. The `jar` executable in your path.
# 3. The following environment variables exported in your shell:
#    $GITHUB_API_TOKEN  : GitHub API token (cf. https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth)

# test for environment
if [[ -z $GITHUB_API_TOKEN ]]; then
  echo 'No value found for $GITHUB_API_TOKEN!'
  exit 1
fi

# write the EB extension
cd $(dirname "${BASH_SOURCE[0]}")

EXTDIR='example/.ebextensions'
SYNC_LOGFILE='/var/log/sync-logs'

# log if desired
if [ -z "${VERBOSE}" ]; then
  LOGCMD=''
else
  LOGCMD=">> ${SYNC_LOGFILE} 2>&1"
fi

mkdir -p $EXTDIR

cat > "${EXTDIR}/01bootstrap.config" <<EBBOOTSTRAP
---
packages:
  yum:
    git: []
    puppet: []
    util-linux-ng: []
  python:
    awscli: []
    boto-rsync: []
EBBOOTSTRAP

cat > "${EXTDIR}/02mean_bean.config" <<EBMEANBEAN
---
commands:
  01rmdir:
    command: "rm -rf /opt/mean-bean-s3log-machine ${LOGCMD}"
    cwd: "/opt"
  02mkdir:
    command: "mkdir -p /opt/mean-bean-s3log-machine ${LOGCMD}"
    cwd: "/opt"
  03init:
    command: "git init ${LOGCMD}"
    cwd: "/opt/mean-bean-s3log-machine"
  04pull:
    command: "git pull https://${GITHUB_API_TOKEN}:x-oauth-basic@github.com/FitnessKeeper/mean-bean-s3log-machine.git ${LOGCMD}"
    cwd: "/opt/mean-bean-s3log-machine"
  05apply:
    command: "puppet apply --modulepath=. -e 'include mean-bean-s3log-machine' ${LOGCMD}"
    cwd: "/opt"
EBMEANBEAN

cat > "${EXTDIR}/03hooks.config" <<EBHOOKS
---
files:
  "/opt/elasticbeanstalk/hooks/appdeploy/pre/10sync-logs":
    mode: "000755"
    content: |
      #!/bin/bash
      /opt/sync-logs.sh ${LOGCMD}
  "/opt/elasticbeanstalk/hooks/configdeploy/pre/10sync-logs":
    mode: "000755"
    content: |
      #!/bin/bash
      /opt/sync-logs.sh ${LOGCMD}
  "/opt/elasticbeanstalk/hooks/restartappserver/pre/10sync-logs":
    mode: "000755"
    content: |
      #!/bin/bash
      /opt/sync-logs.sh ${LOGCMD}
EBHOOKS

# make the WAR
rm -f *.war
APPVERSION=$(date +%s)
jar -cvf "${APPVERSION}.war" example

# version string
if [ $? ]; then
  echo "Version: ${APPVERSION}"
fi
