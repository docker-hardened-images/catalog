#!/bin/bash

set -e

# Install packages specified in liquibase.json if required
if [[ "$INSTALL_MYSQL" -eq "true" ]]; then
  /usr/share/liquibase/lpm add mysql --global
fi

if [[ "$INSTALL_POSGRESQL" -eq "true" ]]; then
  /usr/share/liquibase/lpm add postgresql --global
fi

# Run liquibase
exec /usr/share/liquibase/liquibase "$@"
