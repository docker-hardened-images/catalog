#!/bin/bash
# Image-owned wrapper: the package ships upstream paths under /usr/share; Percona
# database pods still exec /init-entrypoint.sh at the image root.

set -o errexit
set -o xtrace

payload=/usr/share/percona-server-mongodb-operator

install -o "$(id -u)" -g "$(id -g)" -m 0755 -D "${payload}/ps-entry.sh" /opt/percona/ps-entry.sh
install -o "$(id -u)" -g "$(id -g)" -m 0755 -D "${payload}/physical-restore-ps-entry.sh" /opt/percona/physical-restore-ps-entry.sh
install -o "$(id -u)" -g "$(id -g)" -m 0755 -D /mongodb-healthcheck /opt/percona/mongodb-healthcheck
install -o "$(id -u)" -g "$(id -g)" -m 0755 -D "${payload}/pbm-entry.sh" /opt/percona/pbm-entry.sh
install -o "$(id -u)" -g "$(id -g)" -m 0755 -D "${payload}/mongot-entrypoint.sh" /opt/percona/mongot-entrypoint.sh

cp -a "${payload}/logcollector" /opt/percona/
chown -R "$(id -u)":"$(id -g)" /opt/percona/logcollector
chmod -R 0755 /opt/percona/logcollector
