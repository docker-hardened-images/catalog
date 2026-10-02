// Asserts shipped ⊆ union(SBOM documents).
//
// Neither emitter is complete alone: syft's javascript cataloger indexed the staged tree but
// omitted @fastify/send, while npm's resolver covers that and under-reports prod (no
// @aws-sdk/client-s3, because `npm install --package-lock-only` regenerates a lossier graph than
// the committed lockfile). Their union covers everything, and this proves it per build rather
// than trusting either tool.
//
// A row also has to carry a pkg:npm PURL that resolves to the same name and version as the row
// itself. A name and version alone are not enough for Scout to match advisories against the row, and
// a PURL naming something else is worse than none: the row looks scanned while the advisories that
// match belong to a different package.
//
// Usage: node verify-sbom-coverage.cjs <staged-node_modules> <spdx.json>...
// Exits non-zero if any shipped package is absent from every document or is listed without a
// pkg:npm PURL, or if a document is missing, unparseable, or contributes no rows -- a silently
// empty emitter would otherwise look identical to full coverage.

const fs = require("fs");
const path = require("path");

const [tree, ...docs] = process.argv.slice(2);
if (!tree || docs.length === 0) {
  console.error("usage: verify-sbom-coverage.cjs <staged-node_modules> <spdx.json>...");
  process.exit(2);
}

// purlMatches reports whether locator is a pkg:npm PURL for exactly name@version. Scoped names are
// percent-encoded in the PURL (@fastify/send becomes %40fastify/send), and the version is separated
// by the last @, after any qualifier or subpath is dropped.
const purlMatches = (locator, name, version) => {
  if (typeof locator !== "string" || !locator.startsWith("pkg:npm/")) return false;

  const body = locator.slice("pkg:npm/".length).split("?")[0].split("#")[0];
  const at = body.lastIndexOf("@");
  if (at <= 0) return false;

  let purlName;
  try {
    purlName = decodeURIComponent(body.slice(0, at));
  } catch {
    return false;
  }

  return purlName === name && body.slice(at + 1) === version;
};

// key -> whether any document lists that key with a pkg:npm PURL.
const listed = new Map();
for (const doc of docs) {
  const parsed = JSON.parse(fs.readFileSync(doc, "utf8"));
  if (!Array.isArray(parsed.packages)) {
    console.error(`${doc}: no top-level packages array -- emitter changed its output shape`);
    process.exit(1);
  }
  let rows = 0;
  for (const pkg of parsed.packages) {
    if (pkg.name && pkg.versionInfo) {
      const key = `${pkg.name}@${pkg.versionInfo}`;
      const purl = (pkg.externalRefs || []).some(
        (ref) => ref.referenceType === "purl" && purlMatches(ref.referenceLocator, pkg.name, pkg.versionInfo),
      );
      listed.set(key, listed.get(key) || purl);
      rows++;
    }
  }
  if (rows === 0) {
    console.error(`${doc}: contributed 0 rows -- treat as a broken emitter, not as coverage`);
    process.exit(1);
  }
  console.log(`${path.basename(doc)}: ${rows} rows`);
}

// A package directory is the one whose path ends in a separator plus the declared name, so
// node_modules/import-local is never mistaken for a package named "local".
const shipped = new Set();
const visited = new Set();
const walk = (dir) => {
  let real;
  try {
    real = fs.realpathSync(dir);
  } catch {
    return;
  }
  if (visited.has(real)) return;
  visited.add(real);

  for (const entry of fs.readdirSync(dir)) {
    const full = path.join(dir, entry);
    try {
      if (!fs.statSync(full).isDirectory()) continue;
    } catch {
      continue;
    }
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(full, "package.json"), "utf8"));
      if (pkg.name && pkg.version && full.endsWith(path.sep + pkg.name)) {
        shipped.add(`${pkg.name}@${pkg.version}`);
      }
    } catch {
      // a directory without a readable package.json is not a package; keep descending
    }
    walk(full);
  }
};
walk(tree);

const gaps = [...shipped].filter((s) => !listed.has(s)).sort();
const noPurl = [...shipped].filter((s) => listed.get(s) === false).sort();
console.log(
  `union ${listed.size} rows, shipped ${shipped.size} packages, gaps ${gaps.length}, ` +
    `without a pkg:npm PURL ${noPurl.length}`,
);
if (gaps.length > 0) {
  console.error(`shipped but absent from every SBOM document:\n  ${gaps.join("\n  ")}`);
}
if (noPurl.length > 0) {
  console.error(`listed without a pkg:npm PURL, so no advisory can match:\n  ${noPurl.join("\n  ")}`);
}
if (gaps.length > 0 || noPurl.length > 0) {
  process.exit(1);
}
