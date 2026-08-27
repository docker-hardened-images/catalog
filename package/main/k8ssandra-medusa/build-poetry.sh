#!/bin/bash
# Shared k8ssandra-medusa poetry venv staging for alpine and debian leaves.
# Exported by the definition pipeline (melange vars are not expanded here):
#   SOURCE_DIR  - work dir containing src/ (verified upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.12)
#   POETRY_VERSION - poetry release to install via pip
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${POETRY_VERSION:?POETRY_VERSION is required}"

SRC="${SOURCE_DIR}/src"
PKG_ROOT="${TARGET_DIR}/usr/lib/k8ssandra-medusa"
VENV_PYTHON="/usr/lib/k8ssandra-medusa/.venv/bin/python"

mkdir -p "${PKG_ROOT}/bin" "${TARGET_DIR}/usr/bin"

cd "${SRC}"

# CVE-2026-24049 / CVE-2026-59890: bump vendored setuptools in pyproject.toml.
sed -i 's/^setuptools = "78\.1\.1"$/setuptools = "83.0.0"/' pyproject.toml
grep -E '^setuptools = ' pyproject.toml

# Transitive dependency CVE pins mirrored from image/k8ssandra-medusa.
if grep -q '^urllib3 = ' pyproject.toml; then
  sed -i 's/^urllib3 = "[^"]*"$/urllib3 = ">=2.7.0"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a urllib3 = ">=2.7.0"' pyproject.toml
fi

if grep -q '^idna = ' pyproject.toml; then
  sed -i 's/^idna = "[^"]*"$/idna = ">=3.15"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a idna = ">=3.15"' pyproject.toml
fi

if grep -q '^pip = ' pyproject.toml; then
  sed -i 's/^pip = "[^"]*"$/pip = ">=26.1"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a pip = ">=26.1"' pyproject.toml
fi

if grep -q '^pyjwt = ' pyproject.toml; then
  sed -i 's/^pyjwt = "[^"]*"$/pyjwt = ">=2.13.0"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a pyjwt = ">=2.13.0"' pyproject.toml
fi

if grep -q '^aiohttp = ' pyproject.toml; then
  sed -i 's/^aiohttp = "[^"]*"$/aiohttp = ">=3.14.0"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a aiohttp = ">=3.14.0"' pyproject.toml
fi

if grep -q '^cryptography = ' pyproject.toml; then
  sed -i 's/^cryptography = "[^"]*"$/cryptography = ">=50.0.0"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a cryptography = ">=50.0.0"' pyproject.toml
fi

# arm64 has no manylinux wheel for psutil 5.9.6; newer releases ship aarch64
# wheels so poetry does not compile against Python.h at build time.
if grep -q '^psutil = ' pyproject.toml; then
  sed -i 's/^psutil = "[^"]*"$/psutil = ">=6.1.1"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a psutil = ">=6.1.1"' pyproject.toml
fi

if grep -q '^pyOpenSSL = ' pyproject.toml; then
  sed -i 's/^pyOpenSSL = "[^"]*"$/pyOpenSSL = ">=26.2.0,<27.0.0"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a pyOpenSSL = ">=26.2.0,<27.0.0"' pyproject.toml
fi

if grep -q '^click = ' pyproject.toml; then
  sed -i 's/^click = "[^"]*"$/click = ">=8.3.3"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a click = ">=8.3.3"' pyproject.toml
fi

if grep -q '^pyasn1 = ' pyproject.toml; then
  sed -i 's/^pyasn1 = "[^"]*"$/pyasn1 = ">=0.6.4"/' pyproject.toml
else
  sed -i '/^\[tool\.poetry\.dependencies\]/a pyasn1 = ">=0.6.4"' pyproject.toml
fi

"${PYTHON_BIN}" -m pip install -U pip
"${PYTHON_BIN}" -m pip install --ignore-installed "poetry==${POETRY_VERSION}"

export POETRY_VIRTUALENVS_IN_PROJECT=true
# Expose Python headers for any sdist-only transitive on arm64.
export CPPFLAGS="${CPPFLAGS:-} $("${PYTHON_BIN}-config" --includes)"
export LDFLAGS="${LDFLAGS:-} $("${PYTHON_BIN}-config" --ldflags)"
poetry lock
poetry install

cp -a .venv "${PKG_ROOT}/.venv"
cp pyproject.toml "${PKG_ROOT}/pyproject.toml"
cp -a medusa "${PKG_ROOT}/medusa"
cp k8s/docker-entrypoint.sh "${PKG_ROOT}/docker-entrypoint.sh"
cp k8s/medusa.sh "${PKG_ROOT}/bin/medusa"

"${PYTHON_BIN}" - <<PY
from pathlib import Path

entrypoint = Path("${PKG_ROOT}/docker-entrypoint.sh")
text = entrypoint.read_text()
text = text.replace(
    "poetry run python -m medusa.service.grpc.restore",
    "${VENV_PYTHON} -m medusa.service.grpc.restore",
)
text = text.replace(
    "exec poetry run python -m medusa.service.grpc.server server.py &",
    "${VENV_PYTHON} -m medusa.service.grpc.server server.py &",
)
entrypoint.write_text(text)
PY

chmod +x "${PKG_ROOT}/docker-entrypoint.sh"
chmod +x "${PKG_ROOT}/bin/medusa"

# Upstream k8s/medusa.sh ships #!/home/cassandra/.venv/bin/python; point at the
# FHS venv path so usr/bin/medusa works outside the legacy /home/cassandra tree.
read -r medusa_shebang < "${PKG_ROOT}/bin/medusa" || true
case "$medusa_shebang" in
  "#!"*) sed -i "1s|^#!.*|#!${VENV_PYTHON}|" "${PKG_ROOT}/bin/medusa" ;;
esac
grep -q "^#!${VENV_PYTHON}$" "${PKG_ROOT}/bin/medusa"

find "${PKG_ROOT}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${PKG_ROOT}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

for f in "${PKG_ROOT}/.venv/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
    "#!${SRC}"*) sed -i "1s|#!${SRC}/.venv|#!${PKG_ROOT}/.venv|" "$f" ;;
  esac
done

test -x "${PKG_ROOT}/bin/medusa"
ln -sf ../lib/k8ssandra-medusa/bin/medusa "${TARGET_DIR}/usr/bin/medusa"

mkdir -p /opt/docker/sbom/k8ssandra-medusa
chmod -R 0777 /opt/docker/sbom
