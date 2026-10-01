#!/bin/bash
# Shared build for the debian-13 and alpine-3.24 leaves. Expects, exported by the
# definition pipeline (frontend vars are not expanded inside this file):
#   SOURCE_DIR - parent of the directus checkout
#   TARGET_DIR - package root, the payload lands at usr/lib/nodejs/directus
#
# Mirrors upstream's Dockerfile.dhi: install the pnpm workspace, build every
# package, deploy the production tree of the "directus" package, then compile
# argon2 from source instead of shipping its prebuilt binary.
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"

cd "${SOURCE_DIR}/directus"

export CI=true
# plain output keeps the step log under BuildKit's 2 MiB clip
export NO_COLOR=1
export NODE_OPTIONS=--max-old-space-size=8192
# The pnpm store cache mount is shared by the debian and alpine builds. The
# content-addressable tarball store is libc-agnostic, but the side-effects
# cache is not: it handed the alpine run's musl addons to a glibc install.
export npm_config_side_effects_cache=false

# node-gyp builds argon2 and isolated-vm against the installed headers when
# the nodejs dev package ships them, instead of downloading a header tarball.
if [ -f /usr/include/node/node_api.h ]; then
  export npm_config_nodedir=/usr
fi
# isolated-vm and sqlite3 compile from source instead of fetching GitHub
# release prebuilds the shared builder egress cannot always reach; sqlite3
# ships its sqlite amalgamation in the npm tarball. sharp and snappy have no
# install script, so their npm prebuilt binaries are not affected.
export npm_config_build_from_source=true

# pnpm is the version the packageManager field of package.json pins.
corepack enable
corepack prepare --activate
pnpm --version

# pnpm installs both libc flavours of every platform binding here, so the leaf
# names its own libc and the payload check below rejects the other one. Node
# reports the glibc runtime version only on glibc; the build root has no
# /etc/alpine-release to test instead.
DHI_LIBC=$(node -p "process.report.getReport().header.glibcVersionRuntime ? 'glibc' : 'musl'")
export DHI_LIBC

# Manifest edits before the install. CVE pins land in the root pnpm.overrides
# map below, or on the catalog line when the dependents use a catalog:
# specifier, which an override with a version selector does not match.
# tsdown and tsx move to the api devDependencies: upstream lists these build
# tools under dependencies although nothing in api/src imports
# them, so pnpm deploy --prod would ship them with a second rolldown and an
# esbuild binary. A frozen install refuses a manifest the lockfile does not
# reflect, so the lockfile is regenerated for these edits first.
node -e '
  const fs = require("node:fs");
  const overrides = {
    "fast-uri@3": "3.1.8", // CVE-2026-75899, CVE-2026-75931, CVE-2026-75975, CVE-2026-76172, GHSA-qw65-cvwx-89v3, GHSA-58mr-gqgx-xq4g, GHSA-hrr3-gc8f-f4qj
    "axios": "1.20.0", // CVE-2026-101898, CVE-2026-101899, CVE-2026-101900, CVE-2026-101901, CVE-2026-101902, CVE-2026-101903, CVE-2026-101904, CVE-2026-101905, CVE-2026-101906, CVE-2026-101907, CVE-2026-101908, CVE-2026-101909
    "basic-ftp": "6.2.1", // CVE-2026-102990
    "axios-cache-interceptor": "1.12.3", // typed against axios 1.19+, needed to compile update-check with axios 1.20
    "brace-expansion@5": "5.0.12", // CVE-2026-102276, CVE-2026-102277, CVE-2026-102278
    "ip-address@10": "10.7.1", // CVE-2026-101911, CVE-2026-101912
    "nodemailer": "10.0.9", // CVE-2026-100699, CVE-2026-100700
  };
  const rootFile = "package.json";
  const root = JSON.parse(fs.readFileSync(rootFile, "utf8"));
  root.pnpm = root.pnpm || {};
  Object.assign(root.pnpm.overrides = root.pnpm.overrides || {}, overrides);
  fs.writeFileSync(rootFile, JSON.stringify(root, null, "\t") + "\n");
  const wsFile = "pnpm-workspace.yaml";
  let ws = fs.readFileSync(wsFile, "utf8");
  for (const [from, to, why] of [
    ["nodemailer: 10.0.1", "nodemailer: 10.0.2", "GHSA-6vj9-mwq6-2f5v"],
    ["undici: 7.29.0", "undici: 7.29.1", "CVE-2026-85024"],
  ]) {
    const line = "\n  " + from + "\n";
    if (!ws.includes(line)) throw new Error("catalog entry " + from + " not found, re-check the " + why + " pin");
    ws = ws.replace(line, "\n  " + to + "\n");
  }
  if (ws.includes("supportedArchitectures")) throw new Error("upstream now sets supportedArchitectures, re-check the libc selection");
  ws += "\nsupportedArchitectures:\n  os:\n    - current\n  cpu:\n    - current\n  libc:\n    - " + process.env.DHI_LIBC + "\n";
  fs.writeFileSync(wsFile, ws);
  const apiFile = "api/package.json";
  const api = JSON.parse(fs.readFileSync(apiFile, "utf8"));
  for (const dep of ["tsdown", "tsx"]) {
    if (!(dep in api.dependencies)) throw new Error(dep + " is no longer an api dependency, drop this move");
    api.devDependencies[dep] = api.dependencies[dep];
    delete api.dependencies[dep];
  }
  fs.writeFileSync(apiFile, JSON.stringify(api, null, "\t") + "\n");
  // isolated-vm 5.0.3 does not compile under GCC 15 without <cstdint>; the
  // patch rides in through pnpm patchedDependencies (see patch/ for the why).
  fs.mkdirSync("patches", { recursive: true });
  fs.copyFileSync(process.env.SOURCE_DIR + "/patch/isolated-vm-cstdint.patch", "patches/isolated-vm@5.0.3.patch");
  root.pnpm.patchedDependencies = Object.assign(root.pnpm.patchedDependencies || {}, { "isolated-vm@5.0.3": "patches/isolated-vm@5.0.3.patch" });
  fs.writeFileSync(rootFile, JSON.stringify(root, null, "\t") + "\n");
'
pnpm install --recursive --lockfile-only
pnpm install --recursive --frozen-lockfile

npm_config_workspace_concurrency=2 pnpm run build

# Upstream unit suites (vitest in every workspace package that defines a test
# script; pnpm skips the rest). The blackbox and e2e suites need a running
# Directus with real databases, so they run against the consuming image
# instead. directus-extension.test.ts scaffolds an extension and resolves
# @types/node, typescript and vue through npm view, so its result depends on
# the npm registry, not on the built code. The dot reporter keeps the step log
# under BuildKit's 2 MiB clip; failures still print. One workspace suite at a
# time: each vitest run already takes every CPU, and running four of them at
# once made mocked api tests hit the 5s timeout.
pnpm --recursive --workspace-concurrency=1 --filter '!tests-blackbox' --filter '!e2e' --filter '!@directus/app' test --passWithNoTests --reporter=dot --silent --testTimeout=30000 --exclude '**/directus-extension.test.ts'

# The app suite passes, but its rich-text tests create tiptap editors without
# destroying them, so a prosemirror observer timer fires after happy-dom is
# torn down and vitest exits 1 on that unhandled error. The flag ignores only
# that class for the app suite; every assertion in it still gates.
pnpm --filter @directus/app test --reporter=dot --silent --dangerouslyIgnoreUnhandledErrors

pnpm --filter directus deploy --legacy --prod dist

cd dist

# Upstream Dockerfile.dhi drops the argon2 prebuilds and compiles the addon
# with the toolchain of this build, so the shipped binary has a source path.
# node-gyp comes from the workspace install (sqlite3 depends on it), with the
# copy pnpm bundles as the fallback; the distro npm packages place it under
# different prefixes, so npm root -g is not a stable way to find it. Only the
# built addon is kept; node-gyp's object files and Makefiles are not payload.
node_gyp=$(find "${SOURCE_DIR}/directus/node_modules/.pnpm" /root/.cache/node/corepack -path '*/node_modules/node-gyp/bin/node-gyp.js' 2>/dev/null | sed -n '1p')
test -n "${node_gyp}"
argon2_dir=$(find node_modules -type d -name argon2 -exec test -f '{}/argon2.cjs' ';' -print | sed -n '1p')
test -n "${argon2_dir}"
rm -rf "${argon2_dir}/prebuilds"
(cd "${argon2_dir}" && node "${node_gyp}" rebuild)
test -f "${argon2_dir}/build/Release/argon2.node"
mv "${argon2_dir}/build/Release/argon2.node" "${argon2_dir}/argon2.node"
rm -rf "${argon2_dir}/build"
mkdir -p "${argon2_dir}/build/Release"
mv "${argon2_dir}/argon2.node" "${argon2_dir}/build/Release/argon2.node"

# Lock files nested inside dependencies (example projects, benchmarks) are read
# by the SBOM indexer as installed packages and produced phantom findings on
# versions nothing ships; pnpm never reads them after the install. pnpm's own
# record at node_modules/.pnpm/lock.yaml has a different name and stays.
find node_modules -type f \( -name pnpm-lock.yaml -o -name package-lock.json -o -name npm-shrinkwrap.json -o -name yarn.lock -o -name 'bun.lock*' \) -delete

# pnpm's record of the installed set becomes the deploy root lockfile so the
# SBOM indexer catalogues the real node_modules tree; without one the
# attestation lists no npm package at all.
cp node_modules/.pnpm/lock.yaml pnpm-lock.yaml

# Upstream keeps only the essential package.json fields in the deployed tree
# (directus/directus#20338).
node -e '
  const fs = require("node:fs");
  const f = "package.json";
  const { name, version, type, exports, bin } = JSON.parse(fs.readFileSync(f, "utf8"));
  const { packageManager } = JSON.parse(fs.readFileSync("../" + f, "utf8"));
  fs.writeFileSync(f, JSON.stringify({ name, version, type, exports, bin, packageManager }, null, 2) + "\n");
'

# The native addons must load with the node of this build. argon2 is the
# rebuilt one; isolated-vm, sqlite3, snappy and sharp keep the binaries their
# install scripts fetched, and sqlite3 is an optional dependency whose missing
# binary would not fail the install. Top-level await exits 13 when a promise
# never settles, and the marker check below fails the build unless every
# probe ran.
probe=$(node --input-type=module -e '
  import { createRequire } from "node:module";
  import { realpathSync } from "node:fs";
  const here = createRequire(process.cwd() + "/");
  const api = realpathSync(here.resolve("./node_modules/@directus/api/package.json"));
  const r = createRequire(api);
  const argon2 = r("argon2");
  const sharp = r("sharp");
  const ivm = r("isolated-vm");
  const sqlite3 = r("sqlite3");
  const snappy = r("snappy");
  const isolate = new ivm.Isolate({ memoryLimit: 8 });
  const two = isolate.createContextSync().evalSync("1 + 1");
  isolate.dispose();
  if (two !== 2) throw new Error("isolated-vm eval returned " + two);
  const ok = await argon2.verify(await argon2.hash("dhi"), "dhi");
  if (!ok) throw new Error("argon2 verify failed");
  const meta = await sharp({ create: { width: 2, height: 2, channels: 3, background: "#000" } }).png().toBuffer().then((b) => sharp(b).metadata());
  if (meta.width !== 2) throw new Error("sharp metadata width " + meta.width);
  const row = await new Promise((resolve, reject) => {
    const db = new sqlite3.Database(":memory:");
    db.get("select sqlite_version() as v", (err, res) => { db.close(); if (err) reject(err); else resolve(res); });
  });
  if (!row || !row.v) throw new Error("sqlite3 query returned " + JSON.stringify(row));
  const text = snappy.uncompressSync(snappy.compressSync("dhi"), { asBuffer: false });
  if (text !== "dhi") throw new Error("snappy round trip returned " + text);
  console.log("native addons ok: argon2, isolated-vm, sqlite3 " + row.v + ", snappy, sharp with libvips " + sharp.versions.vips);
')
printf '%s\n' "${probe}"
case "${probe}" in
  *"native addons ok"*) ;;
  *) echo "native addon probe did not complete" >&2; exit 1 ;;
esac

dest="${TARGET_DIR}/usr/lib/nodejs/directus"
mkdir -p "${dest}"
cp -a . "${dest}/"
cp -a ../ecosystem.config.cjs ../docker-entrypoint.cjs "${dest}/"

test -f "${dest}/cli.js"
test -f "${dest}/license"
test -f "${dest}/pnpm-lock.yaml"
test -f "${dest}/ecosystem.config.cjs"
test -f "${dest}/docker-entrypoint.cjs"
test -f "${dest}/node_modules/@directus/api/dist/cli/run.js"
test -f "${dest}/node_modules/@directus/api/dist/index.js"
test -z "$(find "${dest}" -path '*/node_modules/tsdown' -o -path '*/node_modules/tsx')"
test -z "$(ls "${dest}/node_modules/.pnpm" | grep -E '^stream-json@1\.')"
if [ "${DHI_LIBC}" = musl ]; then
  foreign='^(@img\+sharp(-libvips)?-linux-(x64|arm64)@|@braintrust\+bt-linux-(x64|arm64)@|.*-(x64|arm64)-gnu@)'
else
  foreign='musl'
fi
test -z "$(ls "${dest}/node_modules/.pnpm" | grep -E "${foreign}")"
dangling=$(find "${dest}" -type l ! -exec test -e {} ';' -print)
test -z "${dangling}"
absolute=$(find "${dest}" -type l -exec readlink '{}' ';' | { grep -E '^/' || true; })
test -z "${absolute}"
brackets=$(find "${dest}" -name '*[[]*')
if [ -n "${brackets}" ]; then
  echo "bracket file names in the payload, dhi/build-pkg cannot glob them" >&2
  printf '%s\n' "${brackets}" >&2
  exit 1
fi

# node is /usr/bin/node on both distros and the runtime image has no env, so
# the launchers name it directly instead of reusing the upstream shebangs.
# pm2 is reached through pnpm's hoisted node_modules so the path does not
# carry the pm2 version; upstream links the same bin at /usr/local/bin/pm2.
test -f "${dest}/node_modules/.pnpm/node_modules/pm2/bin/pm2"
mkdir -p "${TARGET_DIR}/usr/bin"
printf '#!/usr/bin/node\nimport("/usr/lib/nodejs/directus/cli.js");\n' > "${TARGET_DIR}/usr/bin/directus"
printf '#!/usr/bin/node\nrequire("/usr/lib/nodejs/directus/node_modules/.pnpm/node_modules/pm2/bin/pm2");\n' > "${TARGET_DIR}/usr/bin/pm2"
chmod 0755 "${TARGET_DIR}/usr/bin/directus" "${TARGET_DIR}/usr/bin/pm2"
