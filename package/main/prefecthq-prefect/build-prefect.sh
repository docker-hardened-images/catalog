#!/bin/bash
set -eux -o pipefail

test -n "${TARGET_DIR}"
test -n "${WHEEL_PATH}"
test -n "${PACKAGE_LINE}"
test -n "${PYTHON_MAJOR_MINOR_VERSION}"
test -f "${WHEEL_PATH}"
test -x /usr/bin/python"${PYTHON_MAJOR_MINOR_VERSION}"
command -v uv
command -v readelf
command -v strip

PY="${PYTHON_MAJOR_MINOR_VERSION}"
VENV=/usr/lib/prefect
SITE="${VENV}/lib/python${PY}/site-packages"
SOURCE_DIR=$(pwd)

if [ "${PACKAGE_LINE}" = "3" ]; then
    test -f uv.lock
    extra_args=()
    if [ -n "${PREFECT_EXTRAS}" ]; then
        for extra in ${PREFECT_EXTRAS}; do
            extra_args+=(--extra "${extra}")
        done
    fi
    # Upstream 3.9.1's uv.lock already ships at least the versions below, so the
    # lock is exported as upstream wrote it. These are floors, not pins: a lock
    # that moves one of them below its floor fails the check after the export,
    # and an ordinary upgrade above it needs no edit here.
    uv export --frozen --no-dev --no-emit-project --format requirements-txt \
        "${extra_args[@]}" -o /tmp/reqs.txt
    "/usr/bin/python${PY}" - << 'PY'
import re
from pathlib import Path

floors = {
    "certifi": "2026.10.19",
    "mako": "1.4.2",
    "opentelemetry-api": "1.45.1",
    "opentelemetry-distro": "0.66b1",
    "opentelemetry-exporter-http-transport": "0.66b1",
    "opentelemetry-exporter-otlp": "1.45.1",
    "opentelemetry-exporter-otlp-common": "0.66b1",
    "opentelemetry-exporter-otlp-proto-common": "1.45.1",
    "opentelemetry-exporter-otlp-proto-grpc": "1.45.1",
    "opentelemetry-exporter-otlp-proto-http": "1.45.1",
    "opentelemetry-instrumentation": "0.66b1",
    "opentelemetry-instrumentation-logging": "0.66b1",
    "opentelemetry-instrumentation-system-metrics": "0.66b1",
    "opentelemetry-proto": "1.45.1",
    "opentelemetry-sdk": "1.45.1",
    "opentelemetry-semantic-conventions": "0.66b1",
    "opentelemetry-test-utils": "0.66b1",
}

def key(version):
    return tuple(int(part) for part in re.findall(r"\d+", version))

def pins(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        if not line or line[0] in " #-":
            continue
        name, _, rest = line.partition("==")
        if not rest:
            continue
        found[name.split("[", 1)[0].strip()] = rest.split(" ", 1)[0].split("\\", 1)[0]
    return found

after = pins("/tmp/reqs.txt")
for name, floor in floors.items():
    got = after.get(name)
    if got is None or key(got) < key(floor):
        raise SystemExit("%s is %s, want at least %s" % (name, got, floor))
PY
else
    # The 2.x line ships no lock upstream. The committed lock was generated from
    # this tag's requirements.txt and is installed as written, so the resolved
    # set cannot change between rebuilds. The header names the tag it came from.
    test -n "${LOCK_PATH}"
    test -f "${LOCK_PATH}"
    grep -qF "# upstream: PrefectHQ/prefect ${VERSION} requirements.txt" "${LOCK_PATH}"
    cp "${LOCK_PATH}" /tmp/reqs.txt
fi
test -s /tmp/reqs.txt
"/usr/bin/python${PY}" - << 'PY'
from pathlib import Path
text = Path("/tmp/reqs.txt").read_text()
blocks = []
current = []
for line in text.splitlines(True):
    starts_requirement = bool(current) and line[:1] not in (" ", "#", "\n", "\r", "-")
    if starts_requirement and not line.startswith("--"):
        blocks.append("".join(current))
        current = [line]
    else:
        current.append(line)
if current:
    blocks.append("".join(current))
kept = []
for block in blocks:
    first = block.splitlines()[0].strip()
    name = first.split("==", 1)[0].split("[", 1)[0].split(";", 1)[0].split(" ", 1)[0]
    if name == "prefect":
        continue
    kept.append(block)
Path("/tmp/reqs.txt").write_text("".join(kept))
PY
test -s /tmp/reqs.txt
if grep -E '^prefect([^A-Za-z0-9_-]|$)' /tmp/reqs.txt; then
    echo "requirements still name the prefect project without a pin" >&2
    exit 1
fi
grep -q 'cryptography==' /tmp/reqs.txt

# Outside the git checkout so uv does not treat the local project as a requirement.
# The lock export omits the project, but extras such as prefect-redis depend on it.
# Hash mode rejects that dependency unless this file pins the same wheel.
cd /tmp
wheel_install="/tmp/prefect-${VERSION}-py3-none-any.whl"
cp "${WHEEL_PATH}" "${wheel_install}"
test -s "${wheel_install}"
wheel_sha=$(sha256sum "${wheel_install}" | cut -d' ' -f1)
test -n "${wheel_sha}"
printf '\nprefect==%s \\\n    --hash=sha256:%s\n' "${VERSION}" "${wheel_sha}" >> /tmp/reqs.txt
grep -q "^prefect==${VERSION} " /tmp/reqs.txt
uv venv "${VENV}" --python "/usr/bin/python${PY}"
UV_COMPILE_BYTECODE=1 uv pip install --python "${VENV}/bin/python" \
    --require-hashes --find-links /tmp -r /tmp/reqs.txt
if [ "${PACKAGE_LINE}" = "3" ]; then
    PYTHONDONTWRITEBYTECODE=1 "${VENV}/bin/python" - certifi 2026.10.19 mako 1.4.2 opentelemetry-api 1.45.1 << 'PY'
import re
import sys
from importlib.metadata import version

def key(text):
    return tuple(int(part) for part in re.findall(r"\d+", text))

floors = dict(zip(sys.argv[1::2], sys.argv[2::2]))
for name, floor in floors.items():
    got = version(name)
    if key(got) < key(floor):
        raise SystemExit("installed %s %s < %s" % (name, got, floor))
PY
fi

locked() {
    "/usr/bin/python${PY}" - "$1" << 'PY'
import sys
from pathlib import Path
pkg = sys.argv[1]
lines = Path("/tmp/reqs.txt").read_text().splitlines(True)
out = []
capture = False
for line in lines:
    if line.startswith(pkg + "=="):
        capture = True
    if capture:
        out.append(line)
        if not line.rstrip("\n").endswith("\\"):
            break
if not out:
    raise SystemExit("missing requirement %s" % pkg)
sys.stdout.write("".join(out))
PY
}

locked cryptography > /tmp/cryptography.txt
test -s /tmp/cryptography.txt
uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes \
    --no-binary cryptography --reinstall-package cryptography -r /tmp/cryptography.txt
test ! -e "${SITE}/cryptography.libs"
crypto_so=$(find "${SITE}/cryptography" -name '_rust*.so' -type f -print -quit)
test -n "${crypto_so}"
readelf -d "${crypto_so}" > /tmp/readelf.txt
grep -qF libssl /tmp/readelf.txt
PYTHONDONTWRITEBYTECODE=1 "${VENV}/bin/python" - << 'PY'
import ssl
from cryptography.hazmat.backends.openssl.backend import backend
got = backend.openssl_version_text()
want = ssl.OPENSSL_VERSION
if got != want:
    raise SystemExit("cryptography OpenSSL %r != system %r" % (got, want))
PY

if [ "${BUILD_GRPCIO}" = "1" ]; then
    if [ "${GRPC_PYTHON_BUILD_SYSTEM_ABSL:-}" = "1" ]; then
        # grpc's setup.py links every /usr/lib*/libabsl_*.so it finds, and abseil-cpp-dev
        # owns unversioned links to test-only abseil libraries (twelve in this
        # release; several need gtest and gmock). Remove those links before grpcio
        # compiles, and fail if any test-only library is still linkable.
        for lib in absl_exception_safety_testing absl_hash_generator_testing absl_log_internal_test_actions absl_log_internal_test_helpers absl_log_internal_test_matchers absl_per_thread_sem_test_common absl_random_internal_distribution_test_util absl_scoped_mock_log absl_spinlock_test_common absl_status_matchers absl_test_instance_tracker absl_time_internal_test_util; do
            rm "/usr/lib/lib${lib}.so"
        done
        left=$(find /usr/lib -maxdepth 1 -name 'libabsl_*.so' \( -name '*test*' -o -name '*mock*' -o -name '*matchers*' \) -print)
        test -z "${left}"
    fi
    locked grpcio > /tmp/grpcio.txt
    test -s /tmp/grpcio.txt
    uv pip install --python "${VENV}/bin/python" --no-deps --require-hashes \
        --no-binary grpcio --reinstall-package grpcio -r /tmp/grpcio.txt
    grpc_so=$(find "${SITE}/grpc" -name 'cygrpc*.so' -type f -print -quit)
    test -n "${grpc_so}"
    # A source build keeps the DWARF sections that the upstream wheel strips
    # (482 MB of cygrpc.so on this leaf). Strip them, then fail if any survive,
    # so a later grpcio bump cannot bring them back.
    strip --strip-debug "${grpc_so}"
    readelf -S --wide "${grpc_so}" > /tmp/grpc-sections.txt
    if grep -qF '.debug_' /tmp/grpc-sections.txt; then
        echo "cygrpc.so still carries debug sections after strip" >&2
        exit 1
    fi
    readelf -d "${grpc_so}" > /tmp/readelf.txt
    grep -qF libssl /tmp/readelf.txt
    grep -qF libcares /tmp/readelf.txt
    grep -qF 'libz.so' /tmp/readelf.txt
    if [ "${GRPC_PYTHON_BUILD_SYSTEM_RE2:-}" = "1" ]; then
        # System route (Alpine): abseil-cpp and re2 come from the apk packages and
        # must be linked dynamically, not compiled into cygrpc.so.
        grep -qF 'libre2.so' /tmp/readelf.txt
        grep -qF 'libabsl_' /tmp/readelf.txt
        if grep -E 'NEEDED.*(test|mock|matchers|gtest|gmock)' /tmp/readelf.txt; then
            echo "cygrpc.so links a test-only library" >&2
            exit 1
        fi
    else
        # Vendored route (Debian fallback): abseil-cpp and re2 are compiled from
        # grpc's copies and declared as spdx rows in the pipeline. Fail when this
        # grpcio carries another abseil LTS (its inline namespace is in the symbol
        # names) or another grpcio version, so the rows cannot go stale. re2 has no
        # version string in the binary; grpcio pins it.
        test -n "${GRPC_ABSEIL_VERSION}"
        test -n "${GRPCIO_VERSION}"
        grep -qaF "lts_${GRPC_ABSEIL_VERSION%.*}" "${grpc_so}"
        grpc_version=$("${VENV}/bin/python" -c 'from importlib.metadata import version; print(version("grpcio"))')
        test "${grpc_version}" = "${GRPCIO_VERSION}"
    fi
fi

if [ -d "${SITE}/setuptools" ]; then
    uv pip uninstall --python "${VENV}/bin/python" setuptools
    test ! -d "${SITE}/setuptools"
fi

find "${SITE}" -type f \( -name '*.h' -o -name '*.hpp' -o -name '*.c' -o -name '*.cpp' \) -delete
test -z "$(find "${SITE}" -type f \( -name '*.h' -o -name '*.hpp' -o -name '*.c' -o -name '*.cpp' \))"

for junk in "${VENV}/CACHEDIR.TAG" "${VENV}/.gitignore" "${VENV}/.lock"; do
    if [ -f "${junk}" ]; then
        rm "${junk}"
    fi
done
find "${VENV}/bin" -name 'activate*' -type f -print > /tmp/activates
while IFS= read -r activate; do
    test -n "${activate}"
    rm "${activate}"
done < /tmp/activates

ui="${SITE}/prefect/server/ui/index.html"
test -f "${ui}"
grep -q 'Prefect Server' "${ui}"
if [ "${PACKAGE_LINE}" = "3" ]; then
    test -f "${SITE}/prefect/server/ui-v2/index.html"
    grep -q 'Prefect Server' "${SITE}/prefect/server/ui-v2/index.html"
fi

got=$("${VENV}/bin/python" -c 'import prefect; print(prefect.__version__)')
test "${got}" = "${VERSION}"

if [ "${DEPEND_DISTRO_SQLITE}" = "1" ]; then
    test -n "${SQLITE_VERSION}"
    PYTHONDONTWRITEBYTECODE=1 "${VENV}/bin/python" - << 'PY'
import os
import sqlite3
got = tuple(int(part) for part in sqlite3.sqlite_version.split("."))
need = tuple(int(part) for part in os.environ["SQLITE_VERSION"].split("."))
if got < need:
    raise SystemExit("sqlite %s < %s" % (sqlite3.sqlite_version, os.environ["SQLITE_VERSION"]))
PY
fi

install -d "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin" "${TARGET_DIR}/usr/share/prefect"
cp -a "${VENV}" "${TARGET_DIR}/usr/lib/prefect"
cp -a "${SOURCE_DIR}/LICENSE" "${TARGET_DIR}/usr/share/prefect/LICENSE"
test -s "${TARGET_DIR}/usr/share/prefect/LICENSE"
ln -s ../lib/prefect/bin/prefect "${TARGET_DIR}/usr/bin/prefect"
test "$(readlink "${TARGET_DIR}/usr/bin/prefect")" = "../lib/prefect/bin/prefect"

shebang=$(head -n 1 "${TARGET_DIR}/usr/lib/prefect/bin/prefect")
case "${shebang}" in
    "#!/usr/lib/prefect/bin/python"*) ;;
    *)
        echo "unexpected prefect shebang: ${shebang}" >&2
        exit 1
        ;;
esac
case "${shebang}" in
    *"${TARGET_DIR}"*)
        echo "prefect shebang contains the build staging directory" >&2
        exit 1
        ;;
esac
