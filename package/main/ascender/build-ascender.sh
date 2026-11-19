#!/bin/bash
# Builds the Ascender web UI, venv, static files and launch files into TARGET_DIR, as upstream's
# Dockerfile.j2 and Makefile do at the pinned commit. The leaf's pipeline step sets the variables.
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${ASCENDER_VERSION:?ASCENDER_VERSION is required}"
: "${PINNED_RELEASE:?PINNED_RELEASE is required}"
: "${NOTICE_FILE:?NOTICE_FILE is required}"
: "${D3_VERSIONS:?D3_VERSIONS is required}"

SRC="${SOURCE_DIR}/src"
VENV="${TARGET_DIR}/var/lib/awx/venv/awx"
STATIC="${TARGET_DIR}/var/lib/awx/public/static"

# COMMIT_SHA is set by hand; stop when VERSION or the checkout moves without PINNED_RELEASE.
head_sha=$(git -C "${SRC}" rev-parse HEAD)
if [ "${ASCENDER_VERSION}" != "${PINNED_RELEASE%@*}" ] || [ "${head_sha}" != "${PINNED_RELEASE#*@}" ]; then
  echo "VERSION ${ASCENDER_VERSION} at commit ${head_sha} is not PINNED_RELEASE ${PINNED_RELEASE}." >&2
  echo "Find the commit the ${ASCENDER_VERSION} image was built from, then set COMMIT_SHA and PINNED_RELEASE together (or return to the tag commit once the tag is right)." >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}/usr/bin" "${STATIC}" "${TARGET_DIR}/etc/tower/conf.d" \
  "${TARGET_DIR}/var/lib/awx/venv" "${TARGET_DIR}/var/lib/awx/projects" "${TARGET_DIR}/var/lib/awx/job_status" \
  "${TARGET_DIR}/var/lib/awx/rsyslog/conf.d" "${TARGET_DIR}/var/log/tower"
# build-pkg packs files only; a .keep file carries each empty state directory into the package.
for d in etc/tower/conf.d var/lib/awx/projects var/lib/awx/job_status \
  var/lib/awx/rsyslog/conf.d var/log/tower; do
  touch "${TARGET_DIR}/${d}/.keep"
done

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy
export UV_NO_CACHE=1
export AWX_LOGGING_MODE=stdout

# Stop when requirements.txt or requirements-git.txt no longer match upstream's files at this commit.
upstream_lock="${SRC}/requirements/requirements.txt"
upstream_git="${SRC}/requirements/requirements_git.txt"
vendored_lock="${SOURCE_DIR}/requirements.txt"
vendored_git="${SOURCE_DIR}/requirements-git.txt"
lock_pins() {
  grep -v -E '^[[:space:]]*(#|--hash)|^[[:space:]]*$|git\+' "$1" | sed -E 's/\[[^]]*\]//; s/[[:space:]]*\\$//' | LC_ALL=C sort
}
git_names() {
  grep -E '^[A-Za-z0-9][^[:space:]#]* @ git\+' "$1" | cut -d' ' -f1 | LC_ALL=C sort
}
git_sha_refs() {
  tr -d '\r' < "$1" | grep -E '^[A-Za-z0-9][^[:space:]#]* @ git\+[^[:space:]#]*@[0-9a-f]{40}$' | sed -E 's/ @ git\+.*@/@/' | LC_ALL=C sort
}
drift() {
  comm -3 --output-delimiter='only-vendored: ' "$1" "$2" | sed '/^only-vendored: /!s/^/only-upstream: /'
}
upstream_pins=$(lock_pins "${upstream_lock}")
vendored_pins=$(lock_pins "${vendored_lock}" | grep -v -E '^psycopg-c==')
upstream_git_names=$(git_names "${upstream_git}")
vendored_git_names=$(git_names "${vendored_git}")
upstream_git_shas=$(git_sha_refs "${upstream_git}" || [ $? -eq 1 ])
vendored_git_shas=$(git_sha_refs "${vendored_git}" || [ $? -eq 1 ])
lock_drift=$(drift <(printf '%s\n' "${upstream_pins}") <(printf '%s\n' "${vendored_pins}"))
git_drift=$(drift <(printf '%s\n' "${upstream_git_names}") <(printf '%s\n' "${vendored_git_names}"))
git_sha_drift=$(comm -23 <(printf '%s\n' "${upstream_git_shas}") <(printf '%s\n' "${vendored_git_shas}") | sed -e '/^$/d' -e 's/^/only-upstream: /')
if [ -n "${lock_drift}" ] || [ -n "${git_drift}" ] || [ -n "${git_sha_drift}" ]; then
  echo "lock drift: ${vendored_lock} / ${vendored_git} do not match ${upstream_lock} / ${upstream_git} at ${ASCENDER_VERSION}:" >&2
  printf '%s\n' "${lock_drift}" "${git_drift}" "${git_sha_drift}" >&2
  echo "regenerate package/main/ascender/requirements.txt and requirements-git.txt from the upstream files as their headers say, keeping the psycopg-c tail" >&2
  exit 1
fi
# psycopg loads any psycopg_c it finds, so the psycopg-c pin must equal the psycopg pin.
psycopg_pin=$(grep -o -E '^psycopg==[^[:space:]]+' "${vendored_lock}")
psycopg_c_pin=$(grep -o -E '^psycopg-c==[^[:space:]]+' "${vendored_lock}") || { echo "no psycopg-c== pin in ${vendored_lock}; add one at the version of ${psycopg_pin}" >&2; exit 1; }
[ "${psycopg_pin#*==}" = "${psycopg_c_pin#*==}" ] || { echo "${psycopg_c_pin} must match ${psycopg_pin} in ${vendored_lock}" >&2; exit 1; }

# The version of the pinned ansible-runner commit, which its tagless checkout cannot derive.
export SETUPTOOLS_SCM_PRETEND_VERSION_FOR_ANSIBLE_RUNNER=2.4.1.dev71+gfb826c258
runner_line=$(grep -E '^ansible-runner @ git\+' "${vendored_git}")
case "${runner_line##*@}" in
  "${SETUPTOOLS_SCM_PRETEND_VERSION_FOR_ANSIBLE_RUNNER##*+g}"*) ;;
  *) echo "SETUPTOOLS_SCM_PRETEND_VERSION_FOR_ANSIBLE_RUNNER=${SETUPTOOLS_SCM_PRETEND_VERSION_FOR_ANSIBLE_RUNNER} does not describe the ansible-runner commit ${runner_line##*@} pinned in ${vendored_git}" >&2; exit 1 ;;
esac
uv venv --python "${PYTHON_BIN}" "${VENV}"
# Build tools first; every later install builds against them with --no-build-isolation.
uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes \
  --build-constraints "${SOURCE_DIR}/requirements-build.txt" \
  --no-binary cffi --no-binary pycparser --no-binary lxml \
  -r "${SOURCE_DIR}/requirements-build.txt"
extra_no_binary=()
for name in ${EXTRA_NO_BINARY:-}; do
  extra_no_binary+=(--no-binary "${name}")
done
# cffi, pycparser, psycopg and twilio are upstream's SRC_ONLY_PKGS; the rest link system libraries.
UWSGI_PROFILE_OVERRIDE=xml=false uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes \
  --no-build-isolation "${extra_no_binary[@]}" \
  --no-binary cffi \
  --no-binary pycparser \
  --no-binary psycopg \
  --no-binary psycopg-c \
  --no-binary twilio \
  --no-binary lxml \
  --no-binary xmlsec \
  --no-binary python-ldap \
  --no-binary cryptography \
  -r "${SOURCE_DIR}/requirements.txt"
uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes --no-build-isolation \
  -r "${SOURCE_DIR}/requirements-runtime.txt"
uv pip install --python "${VENV}/bin/python" --no-deps --no-build-isolation \
  -r "${vendored_git}"
# CVE pins replace the locked versions in place.
uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes --no-build-isolation \
  "${extra_no_binary[@]}" -r "${SOURCE_DIR}/requirements-security.txt"
uv pip check --python "${VENV}/bin/python"
# No wheel may carry its own copy of a shared library.
bundled=$(find "${VENV}" -type f \( -path '*.libs/*' -o -name 'libstdc++*' -o -name 'libgcc_s*' -o -name 'libssl*' -o -name 'libcrypto*' \))
[ -z "${bundled}" ] || { printf 'wheels with bundled shared libraries:\n%s\n' "${bundled}" >&2; exit 1; }
# The spdx@v1 versions of compiled-in C libraries hold only for these releases.
for pin in ${BUNDLED_FROM:-}; do
  have=$("${VENV}/bin/python" -c 'import importlib.metadata, sys; print(importlib.metadata.version(sys.argv[1]))' "${pin%%==*}")
  [ "${have}" = "${pin#*==}" ] || { echo "${pin%%==*} is ${have}, not ${pin#*==}: run dhi def track update on the package leaf (README.md, entry bundled-code)" >&2; exit 1; }
done
# Each <extension glob>=<library> pair in LINK_CHECKS: the extension must link that system library.
platlib=$("${VENV}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["platlib"])')
read -r -a link_checks <<< "${LINK_CHECKS:-}"
for check in "${link_checks[@]}"; do
  ext=$(compgen -G "${platlib}/${check%%=*}") \
    || { echo "no extension matches ${check%%=*} under ${platlib}" >&2; exit 1; }
  pattern=$(printf '%s' "${check#*=}" | sed 's/\./\\./g')
  readelf -d "${ext}" | grep -E "\[${pattern}(\.[0-9]+)*\]" \
    || { echo "${ext} does not link ${check#*=}" >&2; exit 1; }
done

sdists=$(mktemp -d)
# Receives a distribution name; unpacks its sdist from ${SOURCE_DIR}/sdists into ${sdists}/<name> and requires
# its version to be the venv's.
unpack_sdist() {
  local name=$1 want have
  want=$("${VENV}/bin/python" -c 'import importlib.metadata, sys; print(importlib.metadata.version(sys.argv[1]))' "${name}")
  mkdir "${sdists}/${name}"
  tar -xzf "${SOURCE_DIR}/sdists/${name}.tar.gz" --strip-components=1 -C "${sdists}/${name}"
  have=$(sed -n '/^$/q; s/^Version: //p' "${sdists}/${name}/PKG-INFO")
  [ "${have}" = "${want}" ] || { echo "the ${name} sdist is ${have:-unversioned}, not the venv's ${want}" >&2; exit 1; }
  sdist_archive="${name}-${have}.tar.gz"
}

# Licence notices of compiled-in code that no dist-info directory carries, copied from the sdists.
notice="${TARGET_DIR}${NOTICE_FILE}"
install -d "$(dirname "${notice}")"
cat > "${notice}" <<'EOF'
Licence notices of the third-party code this package compiles in that no
dist-info directory in /var/lib/awx/venv/awx carries. Each section starts with
a "==> <component>: <file> in <archive>" line naming the release archive and
the file in it that the text is copied from.

EOF
unpack_sdist libvalkey
libvalkey_files=$(cd "${sdists}/libvalkey" && find vendor/libvalkey -type f \( -name '*.c' -o -name '*.h' \) | LC_ALL=C sort)
for f in ${libvalkey_files}; do
  block=$(sed -n '1,/\*\//p' "${sdists}/libvalkey/${f}")
  if [[ "${block}" == *'Redistributions in binary form must reproduce'* ]]; then
    printf '==> libvalkey: %s in %s\n%s\n\n' "${f}" "${sdist_archive}" "${block}" >> "${notice}"
  elif [[ "${f}" == *.c ]]; then
    echo "${f} in ${sdist_archive} carries no licence notice" >&2
    exit 1
  fi
done
# UJSON_NOTICE is set where ujson compiles in its own double-conversion copy.
if [ -n "${UJSON_NOTICE:-}" ]; then
  unpack_sdist ujson
  dc_license=src/ujson/deps/double-conversion/LICENSE
  grep -q 'Redistributions in binary form must reproduce' "${sdists}/ujson/${dc_license}" \
    || { echo "no double-conversion licence notice at ${dc_license} in ${sdist_archive}" >&2; exit 1; }
  {
    printf '==> double-conversion: %s in %s\n' "${dc_license}" "${sdist_archive}"
    cat "${sdists}/ujson/${dc_license}"
    echo
  } >> "${notice}"
fi
chmod 0644 "${notice}"

# For each distribution in RUST_SDISTS: its sdist's Cargo.lock cut to the crates the extension links
# on this target, written to RUST_LOCK_DIR for the crates SBOM step.
host=$(rustc -vV | sed -n 's/^host: //p')
for name in ${RUST_SDISTS:-}; do
  : "${RUST_LOCK_DIR:?RUST_LOCK_DIR is required with RUST_SDISTS}"
  unpack_sdist "${name}"
  "${VENV}/bin/python" -I - "${sdists}/${name}" "${RUST_LOCK_DIR}/${name}/Cargo.lock" "${host}" <<'PY'
import pathlib, subprocess, sys, tomllib
src, out, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
tool = tomllib.loads((src / "pyproject.toml").read_text())["tool"]
if "maturin" in tool:
    manifest = src / tool["maturin"].get("manifest-path", "Cargo.toml")
    features = tool["maturin"].get("features", [])
else:
    (ext,) = tool["setuptools-rust"]["ext-modules"]
    manifest = src / ext["path"]
    features = ext.get("features", [])
def cargo(*args):
    return subprocess.run(["cargo", *args, "--manifest-path", str(manifest)], check=True, capture_output=True, text=True).stdout
tree = cargo("tree", "--locked", "--target", target, "--edges", "normal,no-proc-macro", "--prefix", "none",
             "--format", "{p}", *(["--features", ",".join(features)] if features else []))
linked = {tuple(line.split()[:2]) for line in tree.splitlines() if line.strip() and " (/" not in line}
lock = tomllib.loads((pathlib.Path(cargo("locate-project", "--workspace", "--message-format", "plain").strip()).parent / "Cargo.lock").read_text())
pkgs = [p for p in lock["package"] if "source" in p and (p["name"], "v" + p["version"]) in linked]
if not pkgs:
    sys.exit(f"{src}: cargo tree lists no registry crates for {target}")
if len(pkgs) != len(linked):
    sys.exit(f"{src}: cargo tree lists {sorted(linked)}, Cargo.lock has {len(pkgs)} of them")
text = f"version = {lock.get('version', 3)}\n"
for p in pkgs:
    text += f'\n[[package]]\nname = "{p["name"]}"\nversion = "{p["version"]}"\nsource = "{p["source"]}"\n'
    text += f'checksum = "{p["checksum"]}"\n' if "checksum" in p else ""
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
PY
done
rm -r "${sdists}"

cd "${SRC}"

# Each <name>=<version> in D3_VERSIONS: the d3 file upstream keeps in public/static/js, recorded with spdx@v1.
d3_dir=awx/ui/public/static/js
d3_have=$(cd "${d3_dir}" && printf '%s\n' d3-* | LC_ALL=C sort)
d3_want=$(for pair in ${D3_VERSIONS}; do printf '%s.v1.min.js\n' "${pair%%=*}"; done | LC_ALL=C sort)
[ "${d3_have}" = "${d3_want}" ] || { printf 'd3 files in %s:\n%s\nD3_VERSIONS names:\n%s\n' "${d3_dir}" "${d3_have}" "${d3_want}" >&2; exit 1; }
for pair in ${D3_VERSIONS}; do
  grep -q -F "// https://d3js.org/${pair%%=*}/ v${pair#*=} " "${d3_dir}/${pair%%=*}.v1.min.js" \
    || { echo "${d3_dir}/${pair%%=*}.v1.min.js is not version ${pair#*=}" >&2; exit 1; }
done

# Web UI, as upstream's ui-release target; --ignore-scripts is added (README).
NODE_OPTIONS=--max-old-space-size=6144 npm --prefix awx/ui --loglevel warn --force ci --ignore-scripts
"${VENV}/bin/python" tools/scripts/compilemessages.py
npm --prefix awx/ui --loglevel warn run compile-strings
npm --prefix awx/ui --loglevel warn run build
# Upstream's Playwright suite, not part of the build; its package.json would show in the UI SBOM.
rm -r awx/ui/e2e
# Production dependencies only, for the UI SBOM step.
npm --prefix awx/ui --loglevel warn --force prune --omit=dev

# sdist and install, as upstream's sdist target.
export SETUPTOOLS_SCM_PRETEND_VERSION_FOR_AWX="${ASCENDER_VERSION}"
uv build --sdist --no-build-isolation --python "${VENV}/bin/python" --out-dir dist .
uv pip install --python "${VENV}/bin/python" --no-deps --no-build-isolation \
  "dist/awx-${ASCENDER_VERSION}.tar.gz"

# Django reads only build/, public/ and *.py under awx/ui.
site_packages=$("${VENV}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
find "${site_packages}/awx/ui" -mindepth 1 -maxdepth 1 \
  ! -name build ! -name public ! -name '*.py' -exec rm -r {} +

# Upstream's API tests (README); test requirements stay outside the venv.
testdeps=$(mktemp -d)
uv pip install --python "${VENV}/bin/python" --target "${testdeps}" --no-deps --require-hashes \
  --no-build-isolation -r "${SOURCE_DIR}/requirements-test.txt"
(
  export PYTHONPATH="${testdeps}" PATH="${VENV}/bin:${PATH}" PYTHONDONTWRITEBYTECODE=1
  "${VENV}/bin/python" -m pytest -p no:cacheprovider -n auto --dist=loadfile \
    --deselect awx/main/tests/functional/api/test_settings.py::test_logging_aggregator_connection_test_valid \
    awx/main/tests/unit awx/main/tests/functional awx/conf/tests awx/sso/tests
  "${VENV}/bin/python" manage.py check_migrations --dry-run --check -n 'missing_migration_file'
  "${VENV}/bin/python" manage.py check_settings
)
rm -r "${testdeps}"

# Build tools, tests, C and Cython sources out of the venv (README, trimmed venv).
uv pip uninstall --python "${VENV}/bin/python" pip wheel cython setuptools-rust setuptools-scm maturin setuptools \
  hatchling pathspec pluggy tomlkit trove-classifiers
find "${VENV}" -type d \( -name test -o -name tests \) ! -path '*/site-packages/django/test' -prune -exec rm -r {} +
rm -r "${site_packages}/autobahn/_flatc" "${VENV}/bin/flatc"
find "${VENV}" -type f \( -name '*.c' -o -name '*.h' -o -name '*.pyx' -o -name '*.pxd' \) ! -path '*/site-packages/autobahn/nvx/*' -delete

# collectstatic on the trimmed venv, into upstream's static path.
printf "STATIC_ROOT = '%s'\n" "${STATIC}" > /tmp/collectstatic_settings.py
AWX_SETTINGS_FILE=/tmp/collectstatic_settings.py SKIP_SECRET_KEY_CHECK=yes SKIP_PG_VERSION_CHECK=yes \
  "${VENV}/bin/awx-manage" collectstatic --noinput --clear

# Launch files at upstream's paths, except /usr/local/bin, which becomes /usr/bin.
files=tools/ansible/roles/dockerfile/files
install -m 0755 "${files}/launch_awx_web.sh" "${files}/launch_awx_task.sh" \
  "${files}/launch_awx_rsyslog.sh" "${files}/wait-for-migrations" \
  "${files}/stop-supervisor" tools/scripts/awx-python \
  tools/scripts/rsyslog-4xx-recovery "${TARGET_DIR}/usr/bin/"
install -m 0644 "${files}/uwsgi.ini" "${TARGET_DIR}/etc/tower/uwsgi.ini"
# Group-writable: launch_awx_rsyslog.sh rewrites it at start as uid 1000 or any uid in group 0.
install -m 0664 "${files}/rsyslog.conf" "${TARGET_DIR}/var/lib/awx/rsyslog/rsyslog.conf"

# supervisord configs rendered as upstream's dockerfile role does with kube_dev=false.
for role in web task rsyslog; do
  "${VENV}/bin/python" - "tools/ansible/roles/dockerfile/templates/supervisor_${role}.conf.j2" \
    > "${TARGET_DIR}/etc/supervisord_${role}.conf" <<'PY'
import sys
import jinja2
env = jinja2.Environment(keep_trailing_newline=True)
env.filters['bool'] = bool
with open(sys.argv[1]) as f:
    sys.stdout.write(env.from_string(f.read()).render(kube_dev=False))
PY
  chmod 0644 "${TARGET_DIR}/etc/supervisord_${role}.conf"
done

ln -s ../../var/lib/awx/venv/awx/bin/awx-manage "${TARGET_DIR}/usr/bin/awx-manage"
ln -s ../../var/lib/awx/venv/awx/bin/awx-manage "${TARGET_DIR}/usr/bin/ascender-manage"
ln -s ../../var/lib/awx/venv/awx/bin/supervisord "${TARGET_DIR}/usr/bin/supervisord"
ln -s ../../var/lib/awx/venv/awx/bin/supervisorctl "${TARGET_DIR}/usr/bin/supervisorctl"

# The source SPDX from the git entry's spdx: block, shipped in the package (README, SPDX files).
install -D -m 0644 /opt/docker/sbom/ascender/.spdx.ascender.json \
  "${TARGET_DIR}/opt/docker/sbom/ascender/.spdx.ascender.json"

find "${VENV}" -type d -name __pycache__ -prune -exec rm -r {} +
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
rm "${VENV}/.lock"

# Strip the TARGET_DIR uv writes into the venv's bin scripts; stop if any text file keeps a staged path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  sed -i "s|${TARGET_DIR}||g" "$f"
done
hits=$(grep -rIl -e "${TARGET_DIR}/var/lib/awx" -e "${TARGET_DIR}/usr" "${TARGET_DIR}" || [ $? -eq 1 ])
[ -z "${hits}" ] || { printf 'build path %s left in:\n%s\n' "${TARGET_DIR}" "${hits}" >&2; exit 1; }
