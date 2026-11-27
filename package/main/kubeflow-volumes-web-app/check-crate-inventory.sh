#!/bin/bash
# Compare the Cargo.lock of the cryptography sdist against
# cryptography-cargo-inventory.txt and leave a copy of that Cargo.lock in
# ${SOURCE_DIR}/cargo-sbom for the cargo SBOM step.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the sdist, the lock and the inventory
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"

INVENTORY="${SOURCE_DIR}/cryptography-cargo-inventory.txt"
LOCK="${SOURCE_DIR}/requirements-lock.txt"

read -r _ crypto_version < <(grep -E '^cryptography [0-9.]+$' "${INVENTORY}")
test -n "${crypto_version}"
grep -qE "^cryptography==${crypto_version} " "${LOCK}"

sdist="${SOURCE_DIR}/cryptography-${crypto_version}.tar.gz"
test -f "${sdist}"

work="${SOURCE_DIR}/cryptography-sdist"
mkdir -p "${work}"
tar -xzf "${sdist}" -C "${work}" "cryptography-${crypto_version}/Cargo.lock"
cargo_lock="${work}/cryptography-${crypto_version}/Cargo.lock"

# The workspace crates (cryptography-rust and friends) are lock records too,
# so the diff below also catches a workspace version change.
awk '
  /^\[\[package\]\]/ { if (name != "") print name, version; name = ""; version = "" }
  /^name = /         { name = $3; gsub(/"/, "", name) }
  /^version = /      { version = $3; gsub(/"/, "", version) }
  END                { if (name != "") print name, version }
' "${cargo_lock}" | sort > "${work}/lock-records.txt"

grep -E '^[a-z0-9_-]+ [0-9][^ ]* (linked|build|local) ' "${INVENTORY}" \
  | awk '{ print $1, $2 }' | sort > "${work}/inventory-records.txt"

test "$(wc -l < "${work}/lock-records.txt")" -gt 0
if ! diff -u "${work}/inventory-records.txt" "${work}/lock-records.txt"; then
  echo "cryptography Cargo.lock differs from cryptography-cargo-inventory.txt" >&2
  exit 1
fi

mkdir -p "${SOURCE_DIR}/cargo-sbom"
cp "${cargo_lock}" "${SOURCE_DIR}/cargo-sbom/Cargo.lock"
