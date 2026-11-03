#!/bin/bash
# Shared build for the debian-13 and alpine-3.24 leaves. Expects, exported by the
# definition pipeline (frontend vars are not expanded inside this file):
#   SOURCE_DIR - parent of the sorry-cypress checkout
#   TARGET_DIR - package root, the payload lands at usr/lib/nodejs/sorry-cypress-director
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"

cd "${SOURCE_DIR}/sorry-cypress"

# Upstream's Dockerfile copies only these four workspace packages into its build. A
# root production install with api and dashboard present would ship React and MUI.
rm -rf packages/api packages/dashboard

# pm2 wraps the service upstream; the hardened image runs node directly.
# @azure/identity, graphql and clone-deep are declared but imported by no source file.
node -e '
  const fs = require("fs");
  const file = "packages/director/package.json";
  const DIRECT = { "@octokit/rest": "20.1.2", "@octokit/auth-app": "6.1.4" };
  const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
  for (const d of ["pm2", "@azure/identity", "graphql", "clone-deep"]) delete pkg.dependencies[d];
  Object.assign(pkg.dependencies, DIRECT);
  fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
'

# Root yarn resolutions pin vulnerable transitive dependencies. Each pin stays inside
# the range its dependents declare, except axios (director declares ^0.21.3), qs
# (express declares ~6.15.1), the form-data 3.x copy under @types/node-fetch, and
# decode-uri-component (query-string declares ^0.2.2; 0.5.0 keeps the single-function API).
node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  Object.assign(pkg.resolutions, {
    // CVE-2023-45857, CVE-2025-27152, CVE-2025-62718, CVE-2026-25639, CVE-2026-40175,
    // CVE-2026-42033, CVE-2026-42034, CVE-2026-42035, CVE-2026-42036, CVE-2026-42038,
    // CVE-2026-42039, CVE-2026-42040, CVE-2026-42041, CVE-2026-42042, CVE-2026-42043,
    // CVE-2026-44486, CVE-2026-44487, CVE-2026-44490, CVE-2026-44492, CVE-2026-44495,
    // CVE-2026-44496, CVE-2026-67316, CVE-2026-67319, CVE-2026-101909, CVE-2026-101902
    "axios": "0.34.0",
    // CVE-2024-29041, CVE-2024-43796 and, through its send, serve-static and cookie,
    // CVE-2024-43799, CVE-2024-43800, CVE-2024-47764
    "express": "4.22.2",
    // CVE-2024-45590, CVE-2026-12590
    "body-parser": "1.20.8",
    // CVE-2024-45296, CVE-2024-52798, CVE-2026-4867
    "express/path-to-regexp": "0.1.13",
    // CVE-2025-15284, CVE-2026-2391, CVE-2026-82417
    "qs": "6.16.0",
    // CVE-2025-7783, CVE-2026-12143
    "form-data": "4.0.6",
    // CVE-2025-12816, CVE-2025-66030, CVE-2025-66031, CVE-2026-33891, CVE-2026-33894,
    // CVE-2026-33895, CVE-2026-33896 (replaces the 1.3.0 resolution upstream carries)
    "node-forge": "1.4.0",
    // CVE-2025-13465, CVE-2026-2950, CVE-2026-4800
    "lodash": "4.18.1",
    // CVE-2026-25896, CVE-2026-26278, CVE-2026-27942, CVE-2026-33036, CVE-2026-33349
    "fast-xml-parser": "4.5.7",
    // CVE-2026-45822
    "decode-uri-component": "0.5.0",
    // CVE-2021-43138
    "async": "3.2.6",
    // CVE-2025-9287
    "cipher-base": "1.0.7",
    // CVE-2025-9288
    "sha.js": "2.4.12",
    // CVE-2025-6545, CVE-2025-6547, CVE-2026-102414
    "pbkdf2": "3.1.7",
    // CVE-2026-90711 (express ~2.0.7 allows 2.0.8)
    "proxy-addr": "2.0.8",
    // CVE-2024-42459, CVE-2024-42460, CVE-2024-42461, CVE-2024-48948, CVE-2024-48949
    "elliptic": "6.6.1",
    // CVE-2023-46234
    "browserify-sign": "4.2.6",
    // CVE-2023-26159, CVE-2024-28849, CVE-2026-111755, CVE-2026-111756
    "follow-redirects": "1.16.1",
    // CVE-2022-23539, CVE-2022-23540, CVE-2022-23541 (jsonwebtoken 9 via universal-github-app-jwt)
    "universal-github-app-jwt": "1.2.0",
    "jsonwebtoken": "9.0.3",
    // CVE-2025-65945
    "jws": "4.0.1",
    // CVE-2025-25288 (@octokit/plugin-paginate-rest), CVE-2025-25290 (@octokit/request) via @octokit/rest 20 and @octokit/auth-app 6.
    // endpoint 9.0.6 (GHSA-x4c5-c7rf-jjgv, CVE-2025-25285) and request-error 5.1.1 (GHSA-xx4v-prfh-6cgc, CVE-2025-25289) are the patched CJS backports; Scout only knows the 10.x/6.x fix line, so it still flags them and they carry a not_affected VEX on the image.
    "@octokit/request": "8.4.1",
    // CVE-2026-2739: bump the ^4 bn.js tree to 4.12.5, keep browserify-sign on its own 5.2.5 (already >= 5.2.3).
    "bn.js": "4.12.5",
    "browserify-sign/bn.js": "5.2.5",
    // CVE-2026-3449
    "@tootallnate/once": "2.0.1",
    // CVE-2017-16137: the vulnerable 4.x debug copies are under the proxy agents and retry-request; yarn v1 scoped keys do not reach them, so bump all debug to 4.4.3 (the express-family 2.6.9 copies are already fixed and move up harmlessly).
    "debug": "4.4.3",
    // build only: the 4.0.3 upstream resolves cannot parse the axios 0.34 typings
    "typescript": "4.7.4"
  });
  fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
'

# minio 7.0.33 declares engines node >8 <=19 and yarn refuses to install it on
# nodejs-24. The payload is pure JavaScript, so the engines check is bypassed.
# minio 7.1.4 lifts the cap but its typings break the director tsc type-check.
rm -rf node_modules packages/*/node_modules
yarn install --non-interactive --ignore-engines --network-timeout 600000
test -x node_modules/esbuild/bin/esbuild

yarn workspace @sorry-cypress/common build
yarn workspace @sorry-cypress/mongo build
yarn workspace @sorry-cypress/logger build
yarn workspace @sorry-cypress/director build
yarn workspace @sorry-cypress/director test

# A relink over the dev tree leaves dangling .bin links, so the prod install starts clean.
rm -rf node_modules packages/*/node_modules
yarn install --production --non-interactive --ignore-engines --network-timeout 600000
rm -f node_modules/.yarn-integrity

for d in pm2 typescript @babel/core @babel/cli jest esbuild turbo husky wsrun eslint @azure/identity graphql clone-deep; do
  test -z "$(find . -path "*/node_modules/${d}" -not -path '*/.cache/*')"
done
test ! -e node_modules/.bin/pm2-runtime
# the vulnerable copies these resolutions target must be gone (multiple versions coexist per name)
for bad in bn.js@4.12.0 debug@4.2.0; do
  n="${bad%@*}"; v="${bad##*@}"
  test -z "$(find . -path "*/node_modules/${n}/package.json" -exec node -p "require(process.argv[1]).version" {} \; | grep -x "${v}")"
done

for pin in axios@0.34.0 express@4.22.2 body-parser@1.20.8 path-to-regexp@0.1.13 qs@6.16.0 form-data@4.0.6 node-forge@1.4.0 lodash@4.18.1 fast-xml-parser@4.5.7 async@3.2.6 cipher-base@1.0.7 sha.js@2.4.12 pbkdf2@3.1.7 proxy-addr@2.0.8 elliptic@6.6.1 browserify-sign@4.2.6 follow-redirects@1.16.1 universal-github-app-jwt@1.2.0 jsonwebtoken@9.0.3 jws@4.0.1 @octokit/rest@20.1.2 @octokit/auth-app@6.1.4 @octokit/request@8.4.1 @octokit/plugin-paginate-rest@11.4.4-cjs.2 @tootallnate/once@2.0.1 decode-uri-component@0.5.0; do
  name="${pin%@*}"
  want="${pin##*@}"
  found="$(find . -path "*/node_modules/${name}/package.json" -exec node -p "require(process.argv[1]).version" {} \; | sort -u | tr '\n' ' ')"
  test "${found}" = "${want} "
done


dest="${TARGET_DIR}/usr/lib/nodejs/sorry-cypress-director"
mkdir -p "${dest}/packages"
cp -a node_modules package.json "${dest}/"
for p in common mongo logger director; do
  mkdir -p "${dest}/packages/${p}"
  cp -a "packages/${p}/dist" "packages/${p}/package.json" "${dest}/packages/${p}/"
  if [ -d "packages/${p}/node_modules" ]; then cp -a "packages/${p}/node_modules" "${dest}/packages/${p}/"; fi
done
find "${dest}" -type d \( -name __tests__ -o -name .github -o -name example -o -name examples -o -name doc -o -name docs \) -prune -exec rm -rf {} +
# test and tests only inside node_modules; the common package requires its own dist/tests module at runtime
find "${dest}" -type d -path '*/node_modules/*' \( -name test -o -name tests \) -prune -exec rm -rf {} +
find "${dest}" -type f \( -name '*.map' -o -name '*.ts' -o -name '*.md' -o -name '*.markdown' \) -delete
test -z "$(find "${dest}" -path '*/.aws/*')"
test -z "$(find "${dest}" -xtype l)"
node -e "require('${dest}/packages/common'); require('${dest}/packages/mongo'); require('${dest}/packages/logger')"
node --check "${dest}/packages/director/dist/index.js"

# The out-of-range decode-uri-component 0.5.0 must still decode for its query-string consumer.
node -e '
  const dec = require("'"${dest}"'/node_modules/decode-uri-component");
  const f = dec.default || dec;
  if (f("a%20b") !== "a b") throw new Error("decode-uri-component 0.5.0 broke decoding");
'

# The hook reporters call axios({method, url, headers, data}); prove the pinned
# axios completes that request against a loopback listener.
node -e '
  const http = require("http");
  const axios = require(process.argv[1] + "/node_modules/axios");
  const srv = http.createServer((req, res) => {
    let body = "";
    req.on("data", (c) => { body += c; });
    req.on("end", () => { res.setHeader("content-type", "application/json"); res.end(body); });
  });
  srv.listen(0, "127.0.0.1", async () => {
    const url = "http://127.0.0.1:" + srv.address().port + "/hook";
    try {
      const r = await axios({ method: "post", url, headers: { "content-type": "application/json" }, data: { ok: true } });
      if (r.status !== 200 || r.data.ok !== true) throw new Error("unexpected response " + r.status);
    } finally { srv.close(); }
  });
' "${dest}"

mkdir -p "${TARGET_DIR}/usr/bin"
printf '#!/usr/bin/node\nrequire("/usr/lib/nodejs/sorry-cypress-director/packages/director/dist/index.js");\n' > "${TARGET_DIR}/usr/bin/sorry-cypress-director"
chmod 0755 "${TARGET_DIR}/usr/bin/sorry-cypress-director"
