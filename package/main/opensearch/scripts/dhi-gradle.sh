#!/usr/bin/env bash
# DHI wrapper: always apply Gradle CVE dependency overrides from an init script.
# https://docs.gradle.org/current/userguide/init_scripts.html
#
# OpenSearch builds use /src as the merged definition source.dir in the build container.
set -euo pipefail
DHI_INIT="/src/dhi-overrides.init.gradle"
if [ ! -f "${DHI_INIT}" ]; then
  echo "dhi-gradle: init script missing: ${DHI_INIT}" >&2
  exit 1
fi
exec gradle --init-script "${DHI_INIT}" "$@"
