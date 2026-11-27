#!/bin/bash
# Build the Angular UI the way upstream's Dockerfile does: the kubeflow common
# library first, then the volumes app against it. Writes dist/default in the
# volumes frontend and the npm production SBOM into the package root.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the kubeflow/notebooks checkout
#   TARGET_DIR  - package root
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"

APPS="${SOURCE_DIR}/notebooks/components/crud-web-apps"
LIB="${APPS}/common/frontend/kubeflow-common-lib"
UI="${APPS}/volumes/frontend"
SBOM_DIR="${TARGET_DIR}/opt/docker/sbom/kubeflow-volumes-web-app-frontend"

export NG_CLI_ANALYTICS=ci
export CYPRESS_INSTALL_BINARY=0

cd "${LIB}"
npm ci
npm run build
test -f dist/kubeflow/package.json
test -d dist/kubeflow/assets

cd "${UI}"
# Upstream's frontend stage copies only package*.json, tsconfig*, angular.json
# and src, so its build never reads this file and uses Angular's default
# browser targets. rm (not rm -f) fails if the file moves.
rm .browserslistrc

npm ci

# npm sbom --omit=dev also drops production dependencies that a dev
# dependency requires too (@angular/core, rxjs, lodash and others here), so
# take the full lockfile SBOM and keep the name@version pairs npm query
# reports as production.
npm query .prod --package-lock-only > "${SOURCE_DIR}/npm-prod.json"
npm sbom --package-lock-only --sbom-format=spdx > "${SOURCE_DIR}/npm-sbom-full.json"
mkdir -p "${SBOM_DIR}"
jq --slurpfile prod "${SOURCE_DIR}/npm-prod.json" '
  ($prod[0] | map(select(.location != "") | "\(.name)@\(.version)")) as $keep
  | .documentDescribes as $roots
  | .packages |= map(select(("\(.name)@\(.versionInfo)" | IN($keep[])) or (.SPDXID | IN($roots[]))))
  | ([.packages[].SPDXID] + ["SPDXRef-DOCUMENT"]) as $ids
  | .relationships |= map(select((.spdxElementId | IN($ids[])) and (.relatedSpdxElement | IN($ids[]))))
' "${SOURCE_DIR}/npm-sbom-full.json" > "${SBOM_DIR}/.spdx.kubeflow-volumes-web-app-frontend.json"
for name in @angular/core rxjs lodash; do
  jq -e --arg n "${name}" 'any(.packages[]; .name == $n)' "${SBOM_DIR}/.spdx.kubeflow-volumes-web-app-frontend.json" > /dev/null
done
if jq -e 'any(.packages[]; .name == "@angular/cli")' "${SBOM_DIR}/.spdx.kubeflow-volumes-web-app-frontend.json" > /dev/null; then
  echo "dev dependency @angular/cli in the production SBOM" >&2
  exit 1
fi

mkdir -p node_modules/kubeflow
cp -a "${LIB}/dist/kubeflow/." node_modules/kubeflow/
npm run build -- --output-path=./dist/default --configuration=production
test -f dist/default/index.html
test -f dist/default/3rdpartylicenses.txt
