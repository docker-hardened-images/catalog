#!/bin/bash
# Build the tensorboards web app (Angular frontend and Flask backend venv) and
# stage it under /usr/lib/kubeflow-tensorboards-web-app in TARGET_DIR.
# Melange does not expand ${...} in this file. The pipeline exports:
#   SOURCE_DIR       work dir holding the locks
#   TARGET_DIR       package root
#   UPSTREAM_DIR     kubeflow/notebooks checkout at v${VERSION}
#   PYTHON_BIN       distro interpreter, /usr/bin/python3.12
#   VERSION          upstream version, for example 1.11.1
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${UPSTREAM_DIR:?UPSTREAM_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${VERSION:?VERSION is required}"

LOCK_FILE="${SOURCE_DIR}/requirements-lock.txt"
BUILD_LOCK_FILE="${SOURCE_DIR}/requirements-build.txt"
APPS="${UPSTREAM_DIR}/components/crud-web-apps"
LIB_FE="${APPS}/common/frontend/kubeflow-common-lib"
APP_FE="${APPS}/tensorboards/frontend"
BACKEND="${APPS}/tensorboards/backend"
COMMON_BE="${APPS}/common/backend"
FONTS_SRC="${LIB_FE}/projects/kubeflow/src/assets/fonts"

# The venv is built at its installed path so no shebang or pyvenv.cfg needs
# rewriting, then copied into the package root.
APP_ROOT=/usr/lib/kubeflow-tensorboards-web-app
VENV="${APP_ROOT}/.venv"
SITE="${VENV}/lib/python3.12/site-packages"
SBOM_DIR="${TARGET_DIR}/opt/docker/sbom/kubeflow-tensorboards-web-app"

# Apache-2.0 text, the same bytes as googlefonts/roboto-2's LICENSE.
APACHE_LICENSE_SHA256=c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4

test -x "${PYTHON_BIN}"
test -f "${LOCK_FILE}"
test -f "${BUILD_LOCK_FILE}"
test -f "${APP_FE}/package-lock.json"
test -f "${LIB_FE}/package-lock.json"
test -f "${BACKEND}/entrypoint.py"
test -f "${COMMON_BE}/setup.py"
test ! -e "${APP_ROOT}"
command -v readelf
command -v strings
command -v npm

# Frontend, in the upstream Dockerfile's order. Cypress is a devDependency of
# the app whose install script downloads a test-runner binary; it is not used.
export NG_CLI_ANALYTICS=false \
  npm_config_update_notifier=false \
  npm_config_fund=false \
  npm_config_audit=false \
  CYPRESS_INSTALL_BINARY=0

npm --prefix "${LIB_FE}" ci
npm --prefix "${LIB_FE}" run build
test -f "${LIB_FE}/dist/kubeflow/package.json"

npm --prefix "${APP_FE}" ci
test ! -e "${APP_FE}/node_modules/kubeflow"
cp -a "${LIB_FE}/dist/kubeflow" "${APP_FE}/node_modules/kubeflow"
npm --prefix "${APP_FE}" run build -- --output-path=./dist --configuration=production

DIST="${APP_FE}/dist"
test -f "${DIST}/index.html"
test -f "${DIST}/3rdpartylicenses.txt"
grep -q '<base href="/tensorboards/">' "${DIST}/index.html"

font_count=$(find "${DIST}/assets/fonts" -maxdepth 1 -type f -name 'roboto-*.woff2' | wc -l)
test "${font_count}" -eq 21
for font in "${FONTS_SRC}"/roboto-*.woff2; do
  base=$(basename "${font}" .woff2)
  cmp "${font}" "${DIST}/assets/fonts/${base}.woff2"
  hashed=$(find "${DIST}" -maxdepth 1 -type f -name "${base}.*.woff2")
  test -n "${hashed}"
  cmp "${font}" "${hashed}"
done

icon_count=0
for icon in "${APP_FE}"/node_modules/material-icons/iconfont/*.woff2; do
  base=$(basename "${icon}" .woff2)
  hashed=$(find "${DIST}" -maxdepth 1 -type f -name "${base}.*.woff2")
  test -n "${hashed}"
  cmp "${icon}" "${hashed}"
  icon_count=$((icon_count + 1))
done
test "${icon_count}" -eq 5

# npm SBOM for the bundle: the lockfile's production packages, filtered to the
# modules Angular lists in 3rdpartylicenses.txt (what it compiled in), plus
# material-icons, whose fonts are copied into the output as assets. The
# kubeflow entry is the common lib from this checkout, recorded by spdx@v1.
# npm sbom --omit=dev drops @angular/core, rxjs and zone.js from this tree
# although the lockfile marks them production, so the dev filter below reads
# the lockfile's own flags instead.
mkdir -p "${SBOM_DIR}"
npm --prefix "${APP_FE}" sbom --package-lock-only --sbom-format=spdx \
  > "${SOURCE_DIR}/frontend-lock.spdx.json"
"${PYTHON_BIN}" - "${DIST}/3rdpartylicenses.txt" "${SOURCE_DIR}/frontend-lock.spdx.json" \
  "${APP_FE}/package-lock.json" "${SBOM_DIR}/.spdx.kubeflow-tensorboards-web-app-frontend.json" <<'PY'
import json
import re
import sys

licenses, lock_sbom, lockfile, out = sys.argv[1:]
name_re = re.compile(r"^(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$")
license_re = re.compile(r"^\(?[A-Za-z0-9.+-]+(\s+(OR|AND|WITH)\s+[A-Za-z0-9.+-]+)*\)?$")

lines = open(licenses, encoding="utf-8").read().splitlines()
bundled = set()
for i, line in enumerate(lines[:-1]):
    if (i == 0 or lines[i - 1] == "") and name_re.match(line) and (
        lines[i + 1] == "" or license_re.match(lines[i + 1])
    ):
        bundled.add(line)
if "kubeflow" not in bundled or "@angular/core" not in bundled:
    raise SystemExit("3rdpartylicenses.txt parse found no kubeflow or @angular/core: %s" % sorted(bundled))
wanted = (bundled - {"kubeflow"}) | {"material-icons"}

doc = json.load(open(lock_sbom, encoding="utf-8"))
lock_packages = json.load(open(lockfile, encoding="utf-8"))["packages"]
root_ids = set(doc["documentDescribes"])

kept = []
for pkg in doc["packages"]:
    if pkg["SPDXID"] in root_ids:
        pkg["name"] = "kubeflow-tensorboards-web-app-frontend"
        pkg.pop("externalRefs", None)
        kept.append(pkg)
    elif pkg["name"] in wanted:
        entry = lock_packages.get(pkg["packageFileName"])
        if entry is None:
            raise SystemExit("npm sbom row %s has no lockfile entry" % pkg["packageFileName"])
        if not entry.get("dev"):
            kept.append(pkg)
missing = sorted(wanted - {p["name"] for p in kept})
if missing:
    raise SystemExit("bundled modules with no production lockfile entry: %s" % missing)
ids = {p["SPDXID"] for p in kept} | {doc["SPDXID"]}
doc["packages"] = kept
doc["relationships"] = [
    r for r in doc["relationships"]
    if r["spdxElementId"] in ids and r["relatedSpdxElement"] in ids
]
doc["name"] = "kubeflow-tensorboards-web-app-frontend"
json.dump(doc, open(out, "w", encoding="utf-8"), indent=2, sort_keys=True)
print("npm SBOM rows:", sorted(p["name"] + "@" + p["versionInfo"] for p in kept))
PY
test -s "${SBOM_DIR}/.spdx.kubeflow-tensorboards-web-app-frontend.json"
rm "${SOURCE_DIR}/frontend-lock.spdx.json"

# Backend venv. Build backends first (wheels only), then cffi, pycparser and
# greenlet, which cryptography and gevent import while they build, then the
# rest of the lock. --no-build-isolation keeps pip off the sdists' own ranges.
# cryptography, cffi, pyyaml, gevent and greenlet are compiled against the
# system OpenSSL, libffi, libyaml, c-ares, libev, libuv and libstdc++ instead
# of the copies their PyPI wheels embed.
export PYTHONDONTWRITEBYTECODE=1 \
  OPENSSL_NO_VENDOR=1 \
  OPENSSL_STATIC=0 \
  PYYAML_FORCE_LIBYAML=1 \
  GEVENTSETUP_EMBED=0

pip_venv() {
  "${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" --disable-pip-version-check "$@"
}

"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
# maturin's PEP 517 backend runs the maturin binary from PATH.
export PATH="${VENV}/bin:${PATH}"
pip_venv install --no-cache-dir --require-hashes --only-binary :all: --no-deps -r "${BUILD_LOCK_FILE}"

"${PYTHON_BIN}" - "${LOCK_FILE}" "${SOURCE_DIR}/requirements-stage1.txt" cffi pycparser greenlet <<'PY'
import re
import sys

lock, out, *names = sys.argv[1:]
blocks, current = {}, None
for line in open(lock, encoding="utf-8"):
    match = re.match(r"^([A-Za-z0-9_.-]+)==", line)
    if match:
        current = match.group(1).lower().replace("_", "-")
        blocks[current] = []
    elif not line.startswith(" "):
        current = None
    if current is not None and not line.lstrip().startswith("#"):
        blocks[current].append(line)
missing = [n for n in names if n not in blocks]
if missing:
    raise SystemExit("not in lock: %s" % missing)
with open(out, "w", encoding="utf-8") as fh:
    for name in names:
        fh.writelines(blocks[name])
        fh.write("\n")
PY
# greenlet's musllinux wheel carries auditwheel copies of libstdc++ and libgcc_s.
pip_venv install --no-cache-dir --require-hashes --no-deps --no-build-isolation \
  --no-binary cffi,greenlet -r "${SOURCE_DIR}/requirements-stage1.txt"
rm "${SOURCE_DIR}/requirements-stage1.txt"

pip_venv install --no-cache-dir --require-hashes --no-deps --no-build-isolation \
  --no-binary cryptography,cffi,pyyaml,gevent -r "${LOCK_FILE}"

pip_venv install --no-cache-dir --no-deps --no-build-isolation "${COMMON_BE}"

# The build lock is not a runtime dependency. Remove every name it added that
# the runtime lock does not also pin, and fail if any remain.
build_only=$("${PYTHON_BIN}" - "${BUILD_LOCK_FILE}" "${LOCK_FILE}" <<'PY'
import re
import sys
from pathlib import Path

def names(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        match = re.match(r"^([A-Za-z0-9_.-]+)==", line)
        if match:
            found[match.group(1).lower().replace("_", "-")] = match.group(1)
    return found

build = names(sys.argv[1])
runtime = names(sys.argv[2])
extra = [build[key] for key in sorted(set(build) - set(runtime))]
if not extra:
    raise SystemExit("build lock added no package beyond the runtime lock")
print(" ".join(extra))
PY
)
# shellcheck disable=SC2086
pip_venv uninstall -y ${build_only}
for name in ${build_only}; do
  if pip_venv show "${name}" >/dev/null 2>&1; then
    echo "build-only package still installed: ${name}" >&2
    exit 1
  fi
done
# patch/uv-overrides.txt lifts kubernetes 34.1.0's urllib3<2.4.0 cap; that is
# the only conflict pip check may report.
if ! pip_venv check > "${SOURCE_DIR}/pip-check.txt"; then
  if grep -vE '^kubernetes 34\.1\.0 has requirement urllib3<2\.4\.0,>=1\.24\.2, but you have urllib3 [0-9.]+\.$' \
    "${SOURCE_DIR}/pip-check.txt"; then
    echo "pip check reported conflicts beyond the urllib3 override" >&2
    exit 1
  fi
fi
rm "${SOURCE_DIR}/pip-check.txt"

# Native linkage: each extension built from source links the system library,
# and no vendored copy is left behind.
needed() {
  local so="$1"
  local out="${SOURCE_DIR}/readelf.txt"
  readelf -d "${so}" > "${out}"
  shift
  for soname in "$@"; do
    grep -qF "Shared library: [${soname}]" "${out}"
  done
  rm "${out}"
}

find_so() {
  local found
  found=$(find "${SITE}/$1" -type f -name "$2" -print -quit)
  test -n "${found}"
  printf '%s\n' "${found}"
}

vendored=$(find "${SITE}" -maxdepth 1 -type d -name '*.libs')
if test -n "${vendored}"; then
  echo "wheel-vendored libraries shipped: ${vendored}" >&2
  exit 1
fi
needed "$(find_so cryptography '_rust*.so')" libssl.so.3 libcrypto.so.3
needed "$(find_so . '_cffi_backend*.so')" libffi.so.8
needed "$(find_so yaml '_yaml*.so')" libyaml-0.so.2
needed "$(find_so greenlet '_greenlet*.so')" libstdc++.so.6
cares_so=$(find_so gevent/resolver 'cares*.so')
needed "${cares_so}" libcares.so.2
needed "$(find_so gevent/libev 'corecext*.so')" libev.so.4
needed "$(find_so gevent/libuv '_corecffi*.so')" libuv.so.1
strings -a "${cares_so}" > "${SOURCE_DIR}/cares-strings.txt"
if grep -qF 'deps/c-ares' "${SOURCE_DIR}/cares-strings.txt"; then
  echo "gevent resolver still carries the vendored c-ares" >&2
  exit 1
fi
rm "${SOURCE_DIR}/cares-strings.txt"

# The app module path is the one upstream runs from /src.
mkdir -p "${APP_ROOT}/src" "${APP_ROOT}/licenses"
cp -a "${BACKEND}/entrypoint.py" "${APP_ROOT}/src/entrypoint.py"
cp -a "${BACKEND}/app" "${APP_ROOT}/src/app"
test ! -e "${APP_ROOT}/src/app/static"
cp -a "${DIST}" "${APP_ROOT}/src/app/static"

echo "${APACHE_LICENSE_SHA256}  ${UPSTREAM_DIR}/LICENSE" | sha256sum -c -
install -m 0644 "${UPSTREAM_DIR}/LICENSE" "${APP_ROOT}/LICENSE"
{
  echo "Roboto 2.137 web fonts, shipped under src/app/static."
  echo "Copyright 2011 Google Inc. All Rights Reserved."
  echo
  cat "${UPSTREAM_DIR}/LICENSE"
} > "${APP_ROOT}/licenses/Roboto-LICENSE"
chmod 0644 "${APP_ROOT}/licenses/Roboto-LICENSE"

smoke_dir=$(mktemp -d)
cat > "${smoke_dir}/kubeconfig" <<'KUBECONFIG'
apiVersion: v1
kind: Config
clusters:
  - name: none
    cluster:
      server: https://127.0.0.1:1
contexts:
  - name: none
    context:
      cluster: none
      user: none
current-context: none
users:
  - name: none
    user:
      token: none
KUBECONFIG
KUBECONFIG="${smoke_dir}/kubeconfig" APP_PREFIX=/tensorboards \
  "${VENV}/bin/python" -B - "${APP_ROOT}/src" <<'PY'
import ssl
import sys

sys.path.insert(0, sys.argv[1])
import entrypoint
import gevent.core
import gevent.resolver.cares
import yaml
import _cffi_backend
from cryptography.hazmat.backends.openssl.backend import backend

got = backend.openssl_version_text()
if got != ssl.OPENSSL_VERSION:
    raise SystemExit("cryptography OpenSSL %r != system %r" % (got, ssl.OPENSSL_VERSION))
if not yaml.__with_libyaml__:
    raise SystemExit("pyyaml was built without libyaml")
if "libev" not in gevent.core.loop.__module__:
    raise SystemExit("gevent.core.loop is %s" % gevent.core.loop.__module__)
client = entrypoint.app.test_client()
resp = client.get("/healthz/liveness")
if resp.status_code != 200:
    raise SystemExit("liveness returned %d" % resp.status_code)
print("smoke ok:", got)
PY
rm -r "${smoke_dir}"

# Build residue: bytecode, test trees, the setuptools build tree in the
# checkout's dist record, and the local-path direct_url.json. dist-info
# license files stay.
find "${APP_ROOT}" -depth \( -type d -name __pycache__ -o -type d -name tests -o -type d -name test \
  -o -type f -name '*.pyc' -o -type f -name direct_url.json \) -print > "${SOURCE_DIR}/drop.txt"
while IFS= read -r path; do
  test -e "${path}"
  rm -r "${path}"
done < "${SOURCE_DIR}/drop.txt"
rm "${SOURCE_DIR}/drop.txt"
if find "${APP_ROOT}" \( -type d -name __pycache__ -o -type f -name '*.pyc' \) -print -quit | grep -q .; then
  echo "bytecode remains under ${APP_ROOT}" >&2
  exit 1
fi

for extra in activate activate.csh activate.fish Activate.ps1; do
  test -f "${VENV}/bin/${extra}"
  rm "${VENV}/bin/${extra}"
done
test ! -e "${VENV}/bin/pip"
test ! -e "${SITE}/pip"

shebang=$(head -n 1 "${VENV}/bin/gunicorn")
test "${shebang}" = "#!${VENV}/bin/python"

if grep -rlF --binary-files=without-match -e "${UPSTREAM_DIR}" -e "${TARGET_DIR}/usr/" "${APP_ROOT}" > "${SOURCE_DIR}/leaks.txt"; then
  echo "build-time path still present in:" >&2
  cat "${SOURCE_DIR}/leaks.txt" >&2
  exit 1
fi
rm "${SOURCE_DIR}/leaks.txt"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"
cp -a "${APP_ROOT}" "${TARGET_DIR}/usr/lib/"
ln -s ../lib/kubeflow-tensorboards-web-app/.venv/bin/gunicorn "${TARGET_DIR}/usr/bin/gunicorn"
test -x "${TARGET_DIR}/usr/lib/kubeflow-tensorboards-web-app/.venv/bin/gunicorn"
