#!/bin/bash

set -e

# Install packages specified in liquibase.json if required
if [[ "$INSTALL_MYSQL" -eq "true" ]]; then
  /opt/liquibase/lpm add mysql --global
fi

if [[ "$INSTALL_POSGRESQL" -eq "true" ]]; then
  /opt/liquibase/lpm add postgresql --global
fi

# /usr/share/liquibase is the packaged launcher (symlink to /opt/liquibase/liquibase).
exec /usr/share/liquibase "$@"
