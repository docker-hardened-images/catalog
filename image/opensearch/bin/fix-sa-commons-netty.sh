#!/usr/bin/env bash
# fix-sa-commons-netty.sh
# Purpose:
#  - Strip embedded Netty from security-analytics-commons jar
#  - Rebuild the security-analytics plugin
#  - Optionally inject Netty 4.1.124.Final jars into the plugin zip
#
# Usage:
#   ./fix-sa-commons-netty.sh /abs/path/to/security-analytics [--bundle-netty] [--netty 4.1.124.Final] [--netty-from-zip /path/to/other-plugin.zip] [--netty-from-dir /path/to/extracted/dir]
#
# Notes:
#  - Run from anywhere. Paths must be absolute.
#  - This does NOT edit build.gradle. It replaces the commons jar on disk BEFORE the build.
#  - If --bundle-netty is omitted, the plugin zip will rely on OpenSearch core’s Netty at runtime.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /abs/path/to/security-analytics [--bundle-netty] [--netty 4.1.124.Final] [--netty-from-zip /path/to/other-plugin.zip] [--netty-from-dir /path/to/extracted/dir]" >&2
  exit 1
fi

SA_REPO="$1"; shift || true
[[ "${SA_REPO}" = /* ]] || { echo "ERROR: SA_REPO must be an absolute path"; exit 1; }
[[ -d "${SA_REPO}" && -f "${SA_REPO}/build.gradle" ]] || { echo "ERROR: ${SA_REPO} missing build.gradle"; exit 1; }

BUNDLE_NETTY="0"
NETTY_VER="4.1.124.Final"
NETTY_FROM_ZIP=""
NETTY_FROM_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-netty) BUNDLE_NETTY="1"; shift ;;
    --netty-version) NETTY_VER="${2:-}"; shift 2 ;;
    --netty-from-zip) NETTY_FROM_ZIP="${2:-}"; shift 2 ;;
    --netty-from-dir) NETTY_FROM_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Derive commons jar name from SA build.gradle defaults
SA_COMMONS_VERSION="$(grep -E "sa_commons_version\s*=\s*'[^']+'" "${SA_REPO}/build.gradle" | sed -E "s/.*'([^']+)'.*/\1/")"
[[ -n "${SA_COMMONS_VERSION}" ]] || SA_COMMONS_VERSION="1.0.0"
SA_COMMONS_FILENAME="security-analytics-commons-${SA_COMMONS_VERSION}.jar"
SA_COMMONS_PATH="${SA_REPO}/${SA_COMMONS_FILENAME}"

if [[ ! -f "${SA_COMMONS_PATH}" ]]; then
  echo "ERROR: commons jar not found at ${SA_COMMONS_PATH}"
  echo "       Place ${SA_COMMONS_FILENAME} in ${SA_REPO} (as expected by build.gradle)."
  exit 1
fi

echo "Backing up and stripping embedded Netty from: ${SA_COMMONS_PATH}"
cp -f "${SA_COMMONS_PATH}" "${SA_COMMONS_PATH}.bak"

# Create stripped copy (remove io/netty classes and Netty pom metadata)
TMP_STRIPPED="$(mktemp -t sa-commons-stripped.XXXXXX).jar"
cp -f "${SA_COMMONS_PATH}" "${TMP_STRIPPED}"
# zip -d fails if patterns not found; ignore errors
zip -qd "${TMP_STRIPPED}" 'io/netty/*' 'META-INF/maven/io.netty/*/*' || true
# Sanity check: ensure no io/netty classes remain
if jar tf "${TMP_STRIPPED}" | grep -q '^io/netty/'; then
  echo "ERROR: Failed to strip embedded Netty classes from commons jar" >&2
  exit 1
fi

# Replace the jar at the original expected path (build picks this up)
cp -f "${TMP_STRIPPED}" "${SA_COMMONS_PATH}"

echo "Rebuilding plugin with stripped commons jar..."
pushd "${SA_REPO}" >/dev/null
./gradlew clean assemble -Dbuild.snapshot=false -x integTest
popd >/dev/null

# Locate the freshly built plugin zip
DIST_DIR="${SA_REPO}/build/distributions"
PLUGIN_ZIP="$(ls -t "${DIST_DIR}"/opensearch-security-analytics-*.zip | head -n 1 || true)"
[[ -n "${PLUGIN_ZIP}" ]] || { echo "ERROR: No plugin zip found in ${DIST_DIR}"; exit 1; }
echo "Built: ${PLUGIN_ZIP}"

# Verify commons jar in zip no longer contains embedded Netty
TMP_JAR="$(mktemp -t sa-commons-from-zip.XXXXXX).jar"
unzip -p "${PLUGIN_ZIP}" "${SA_COMMONS_FILENAME}" > "${TMP_JAR}"
if jar tf "${TMP_JAR}" | grep -q '^io/netty/'; then
  echo "ERROR: Embedded Netty classes still present in ${SA_COMMONS_FILENAME} inside the zip" >&2
  echo "       The jar replacement likely didn’t take effect. Check build script copying logic." >&2
  exit 1
else
  echo "OK: ${SA_COMMONS_FILENAME} in zip has no embedded io/netty classes."
fi

if [[ "${BUNDLE_NETTY}" = "1" ]]; then
  echo "Bundling Netty ${NETTY_VER} jars into plugin zip..."

  # Prepare a temp staging dir
  STAGE_DIR="$(mktemp -d -t sa-zip-stage.XXXXXX)"
  pushd "${STAGE_DIR}" >/dev/null
  unzip -q "${PLUGIN_ZIP}"

  # Option A: stage jars from a provided directory
  stage_netty_from_dir() {
    local src_dir="$1"
    local found=0
    while IFS= read -r -d '' jf; do
      cp -f "$jf" .
      found=$((found+1))
    done < <(find "$src_dir" -type f -name "netty-*-${NETTY_VER}.jar" -print0)
    if [[ $found -eq 0 ]]; then
      echo "ERROR: No netty *-${NETTY_VER}.jar found under: $src_dir" >&2
      exit 1
    fi
    echo "Staged ${found} Netty jars from: $src_dir"
  }

  # Option B: stage jars from a provided plugin zip
  if [[ -n "${NETTY_FROM_ZIP}" ]]; then
    [[ -f "${NETTY_FROM_ZIP}" ]] || { echo "ERROR: --netty-from-zip not found: ${NETTY_FROM_ZIP}" >&2; exit 1; }
    SRC_TMP="$(mktemp -d -t netty-src-zip.XXXXXX)"
    unzip -q "${NETTY_FROM_ZIP}" -d "${SRC_TMP}"
    stage_netty_from_dir "${SRC_TMP}"
  elif [[ -n "${NETTY_FROM_DIR}" ]]; then
    [[ -d "${NETTY_FROM_DIR}" ]] || { echo "ERROR: --netty-from-dir not a directory: ${NETTY_FROM_DIR}" >&2; exit 1; }
    stage_netty_from_dir "${NETTY_FROM_DIR}"
  else
    # Fallback: fetch jars from local m2 or Maven Central
    fetch_netty() {
      local artifact="$1"
      local jar="netty-${artifact}-${NETTY_VER}.jar"
      local m2="${HOME}/.m2/repository/io/netty/netty-${artifact}/${NETTY_VER}/${jar}"
      if [[ -f "${m2}" ]]; then
        cp -f "${m2}" .
        return
      fi
      local url="https://repo1.maven.org/maven2/io/netty/netty-${artifact}/${NETTY_VER}/${jar}"
      echo "Downloading ${url}"
      curl -sfL "${url}" -o "${jar}"
    }
    NETTY_ARTS=(buffer common codec codec-http codec-http2 handler transport transport-native-unix-common resolver transport-classes-epoll)
    for a in "${NETTY_ARTS[@]}"; do
      fetch_netty "${a}"
    done
  fi

  # Repack the zip (overwrite original with a .rebundled suffix)
  TMP_ZIP="${PLUGIN_ZIP}.tmp"
  zip -qr "${TMP_ZIP}" .
  popd >/dev/null
  rm -rf "${STAGE_DIR}"

  # Replace original zip in place
  mv -f "${TMP_ZIP}" "${PLUGIN_ZIP}"

  echo "Updated zip in place: ${PLUGIN_ZIP}"
  echo "Verify bundled Netty versions:"
  unzip -l "${PLUGIN_ZIP}" | grep -E "netty-.*-${NETTY_VER}\.jar" || echo "No netty *-${NETTY_VER}.jar found (unexpected)"
else
  echo "Skipping bundling Netty jars (rely on OpenSearch core’s Netty at runtime)."
fi

echo "Done."
