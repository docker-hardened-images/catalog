#!/bin/bash
# Shared localstack venv staging for alpine and debian leaves.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing localstack/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.13)
#   VERSION     - LocalStack release version
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${VERSION:?VERSION is required}"

VENV="${TARGET_DIR}/usr/lib/localstack"
SRC="${SOURCE_DIR}/localstack"
PYTHON_MINOR="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"

export VIRTUAL_ENV="${VENV}"
"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python3" install --upgrade pip setuptools wheel

# Align with upstream Dockerfile: pyproject name is localstack-core (setuptools-scm env).
export SETUPTOOLS_SCM_PRETEND_VERSION_FOR_LOCALSTACK_CORE="${VERSION}"
"${VENV}/bin/python3" - << 'PY'
from pathlib import Path

replacements = {
    "localstack-core/localstack/aws/protocol/parser.py": [
        (
            "# cbor2: explicitly load from private _decoder module to avoid using the (non-patched) C-version\nfrom cbor2._decoder import loads as cbor2_loads\n",
            "# cbor2>=5.9 removed the private _decoder module; fall back to the public loader.\ntry:\n    from cbor2._decoder import loads as cbor2_loads\nexcept ModuleNotFoundError:\n    from cbor2 import loads as cbor2_loads\n",
        ),
    ],
    "localstack-core/localstack/aws/protocol/serializer.py": [
        (
            "from cbor2._encoder import dumps as cbor2_dumps\n",
            "try:\n    from cbor2._encoder import dumps as cbor2_dumps\nexcept ModuleNotFoundError:\n    from cbor2 import dumps as cbor2_dumps\n",
        ),
    ],
    "localstack-core/localstack/aws/client.py": [
        (
            "            # cbor2: explicitly load from private _decoder module to avoid using the (non-patched) C-version\n            from cbor2._decoder import loads\n",
            "            # cbor2>=5.9 removed the private _decoder module; fall back to the public loader.\n            try:\n                from cbor2._decoder import loads\n            except ModuleNotFoundError:\n                from cbor2 import loads\n",
        ),
        (
            "    from cbor2._decoder import CBORDecodeValueError, semantic_decoders\n    from cbor2._encoder import CBOREncodeValueError, default_encoders\n    from cbor2._types import CBORTag\n",
            "    try:\n        from cbor2._decoder import CBORDecodeValueError, semantic_decoders\n        from cbor2._encoder import CBOREncodeValueError, default_encoders\n        from cbor2._types import CBORTag\n    except ModuleNotFoundError:\n        return\n",
        ),
    ],
}

for relpath, pairs in replacements.items():
    path = Path(relpath)
    text = path.read_text()
    for old, new in pairs:
        if old not in text:
            raise SystemExit(f"expected block not found in {path}")
        text = text.replace(old, new)
    path.write_text(text)
PY
"${VENV}/bin/python3" -m pip install -r requirements-runtime.txt
"${VENV}/bin/python3" -m pip install -e .[runtime]
# Install the CLI launcher without dependencies: runtime comes from localstack-core.
"${VENV}/bin/python3" -m pip install --no-deps "localstack==${VERSION}"

# aws.spec uses host-mode dirs under localstack-core/.filesystem/... (see Directories.for_host).
mkdir -p localstack-core/.filesystem/usr/lib/localstack

# Generate AWS service catalog cache like upstream final stage.
"${VENV}/bin/python3" -m localstack.aws.spec

# Container runtime reads static_libs from /usr/lib/localstack (venv root).
find localstack-core/.filesystem/usr/lib/localstack -maxdepth 1 -name 'service-catalog-*.dill' -exec cp {} "${VENV}/" \;

# Patch CVEs in the venv dependency tree.
"${VENV}/bin/python3" -m pip install --upgrade 'awscli>=1.44.78'      # Fix CVE-2026-13769
"${VENV}/bin/python3" -m pip install --upgrade 'joserfc>=1.6.3'       # Fix CVE-2026-27932
"${VENV}/bin/python3" -m pip install --upgrade 'pyopenssl>=26.0.0'    # Fix CVE-2026-27459, CVE-2026-27448
"${VENV}/bin/python3" -m pip install --upgrade 'pyasn1>=0.6.3'        # Fix CVE-2026-30922
"${VENV}/bin/python3" -m pip install --upgrade 'multipart>=1.3.1'     # Fix CVE-2026-28356
"${VENV}/bin/python3" -m pip install --upgrade 'cbor2>=5.9.0'         # Fix CVE-2026-26209
"${VENV}/bin/python3" -m pip install --upgrade 'requests>=2.33.0'     # Fix CVE-2026-25645
"${VENV}/bin/python3" -m pip install --upgrade 'urllib3>=2.7.0'       # Fix CVE-2026-44432, CVE-2026-44431
"${VENV}/bin/python3" -m pip install --upgrade 'cryptography>=46.0.7' # Fix CVE-2026-39892, CVE-2026-34073
"${VENV}/bin/python3" -m pip install --upgrade 'python-dotenv>=1.2.2' # Fix CVE-2026-28684
"${VENV}/bin/python3" -m pip install --upgrade 'pygments>=2.20.0'     # Fix CVE-2026-4539
"${VENV}/bin/python3" -m pip install --upgrade 'idna>=3.15'           # Fix CVE-2026-45409
"${VENV}/bin/python3" -m pip install --upgrade 'click>=8.3.3'         # Fix CVE-2026-7246
"${VENV}/bin/python3" -m pip install --upgrade 'h2>=4.4.1'            # Fix CVE-2026-71554

"${VENV}/bin/python3" -m pip uninstall -y pip

# Fixes CVE-2025-55163
rm -rf "${VENV}/lib/python${PYTHON_MINOR}/site-packages/amazon_kclpy/jars"

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete || true

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -e "${VENV}/bin/localstack"
test -e "${VENV}/bin/localstack-supervisor"
ln -sf ../lib/localstack/bin/localstack "${TARGET_DIR}/usr/bin/localstack"
ln -sf ../lib/localstack/bin/localstack-supervisor "${TARGET_DIR}/usr/bin/localstack-supervisor"

mkdir -p /opt/docker/sbom/localstack
chmod -R 0777 /opt/docker/sbom
