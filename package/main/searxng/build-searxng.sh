#!/bin/bash
# Shared searxng staging for alpine (uv) and debian (venv+pip).
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR      - work dir containing src/ (upstream git checkout)
#   TARGET_DIR      - package root (app lands at ${TARGET_DIR}/usr/lib/searxng)
#   PYTHON_BIN      - interpreter path (e.g. /usr/bin/python3.13)
#   SEARXNG_VERSION - upstream date-based version (e.g. 2026.8.6)
#   SEARXNG_COMMIT  - full commit SHA the checkout is pinned to
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${SEARXNG_VERSION:?SEARXNG_VERSION is required}"
: "${SEARXNG_COMMIT:?SEARXNG_COMMIT is required}"

SRC="${SOURCE_DIR}/src"
APP="${TARGET_DIR}/usr/lib/searxng"
VENV="${APP}/.venv"
# Upstream's %h abbreviation is 9 hex chars (git auto width on the full
# repo). Running git in the build's shallow checkout under-abbreviates to 7,
# so slice the pinned SHA to upstream's observed width instead.
SHORT_SHA="$(printf '%.9s' "${SEARXNG_COMMIT}")"

mkdir -p "${APP}" "${TARGET_DIR}/etc/searxng"

# Venv without pip at the final path; upstream's dist venv carries no
# installer either (built with `uv venv`). Installs come from the vendored
# full transitive lock with --no-deps (httpbin pattern) so both leaves ship
# the same dependency set and rebuilds are reproducible; upstream's
# requirements*.txt only pin direct deps. A dependency CVE fix — direct or
# transitive — is a version bump on the affected requirements-lock.txt line.
LOCK="${SOURCE_DIR}/requirements-lock.txt"
if command -v uv >/dev/null 2>&1; then
  uv venv --python "${PYTHON_BIN}" "${VENV}"
  uv pip install --python "${VENV}/bin/python" --no-cache \
    --no-deps -r "${LOCK}"
else
  "${PYTHON_BIN}" -m venv --without-pip "${VENV}"
  "${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" install \
    --no-cache-dir --no-compile \
    --no-deps -r "${LOCK}"
fi

# SearXNG has no releases; searx/version.py derives the version from git
# (commit date + short hash) and upstream CI freezes it into
# searx/version_frozen.py before the container build. Do the same from the
# pinned commit so the runtime reports the real version without git.
cat > "${SRC}/searx/version_frozen.py" <<EOF
# SPDX-License-Identifier: AGPL-3.0-or-later
VERSION_STRING = "${SEARXNG_VERSION}+${SHORT_SHA}"
VERSION_TAG = "${SEARXNG_VERSION}+${SHORT_SHA}"
DOCKER_TAG = "${SEARXNG_VERSION}-${SHORT_SHA}"
GIT_URL = "https://github.com/searxng/searxng"
GIT_BRANCH = "master"
EOF

# Stage the application tree the way upstream's dist image ships it: the venv
# holds only dependencies and searx/ is imported from the work dir.
cp -a "${SRC}/searx" "${APP}/searx"

# Default config from upstream's template; the "ultrasecretkey" placeholder
# must be overridden at runtime via SEARXNG_SECRET (searxng refuses to start
# with the placeholder), which the image guides document.
install -m 0644 "${SRC}/container/settings.template.yml" \
  "${TARGET_DIR}/etc/searxng/settings.yml"

# Mirror upstream builder.dockerfile: slim the venv, byte-compile, and
# precompress static assets for whitenoise.
find "${VENV}/lib/" -type f -exec strip --strip-unneeded {} + || true
find "${VENV}/lib/" -type d -name __pycache__ -exec rm -rf {} +
find "${VENV}/lib/" -type f -name '*.pyc' -delete
# -s strips the build prefix so embedded source paths are the final ones
"${VENV}/bin/python" -m compileall -q -f -j 0 \
  --invalidation-mode=unchecked-hash -s "${TARGET_DIR}" "${VENV}/lib/"
"${VENV}/bin/python" -m compileall -q -f -j 0 \
  --invalidation-mode=unchecked-hash -s "${TARGET_DIR}" "${APP}/searx/"
find "${APP}/searx/static/" -type f \
  \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.svg' \) \
  -exec gzip -9 -k {} + \
  -exec brotli -9 -k {} +
find "${APP}/searx/static/" -type f -name '*.gz' -exec gzip --test {} +
find "${APP}/searx/static/" -type f -name '*.br' -exec brotli --test {} +

# pip/uv may bake the build-time path into shebangs; normalize to the final path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/searxng
chmod -R 0777 /opt/docker/sbom
