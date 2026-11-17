const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const sbomDir = process.argv[3];
const sourcePurl = process.argv[4];

if (!root || !sbomDir || !sourcePurl) {
  console.error('usage: node check-sbom.cjs <staged-root> <sbom-dir> <source-purl>');
  process.exit(1);
}

function walk(dir, predicate, acc) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, predicate, acc);
    } else if (predicate(entry.name)) {
      acc.push(full);
    }
  }
  return acc;
}

const identities = new Set();
const sbomFiles = walk(sbomDir, (name) => name.endsWith('.json'), []);
if (sbomFiles.length === 0) {
  console.error(`[ERROR] no SBOM documents under ${sbomDir}`);
  process.exit(1);
}

for (const file of sbomFiles) {
  const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const pkg of doc.packages || []) {
    if (pkg.name && pkg.versionInfo) {
      identities.add(`${pkg.name}@${pkg.versionInfo}`);
    }
    for (const ref of pkg.externalRefs || []) {
      if (ref.referenceLocator) {
        identities.add(ref.referenceLocator);
      }
    }
  }
}

function npmCandidates(name, version) {
  const names = [name];
  const lower = name.toLowerCase();
  if (lower !== name) {
    names.push(lower);
  }
  const candidates = [];
  for (const current of names) {
    candidates.push(`${current}@${version}`);
    candidates.push(`pkg:npm/${current}@${version}`);
    if (current.startsWith('@')) {
      const slash = current.indexOf('/');
      const scope = current.slice(0, slash);
      const rest = current.slice(slash + 1);
      const encodedScope = encodeURIComponent(scope);
      candidates.push(`pkg:npm/${encodedScope}/${rest}@${version}`);
      candidates.push(`pkg:npm/${encodedScope}/${encodeURIComponent(rest)}@${version}`);
    } else if (current.includes('/')) {
      candidates.push(`pkg:npm/${encodeURIComponent(current)}@${version}`);
    }
  }
  return candidates;
}

function covered(name, version) {
  return npmCandidates(name, version).some((candidate) => identities.has(candidate));
}

if (!identities.has(sourcePurl)) {
  console.error(`[ERROR] source purl missing from SBOM: ${sourcePurl}`);
  process.exit(1);
}

const sourceVersion = sourcePurl.slice(sourcePurl.lastIndexOf('@') + 1);
const applicationVersions = new Set([sourceVersion, `v${sourceVersion}`]);

function isApplicationManifest(manifest, version) {
  const rel = path.relative(root, manifest);
  return !rel.split(path.sep).includes('node_modules') && applicationVersions.has(version);
}

const manifests = walk(root, (name) => name === 'package.json', []);
if (manifests.length === 0) {
  console.error(`[ERROR] no package.json under ${root}`);
  process.exit(1);
}

function readPackage(manifest) {
  let pkg;
  try {
    pkg = JSON.parse(fs.readFileSync(manifest, 'utf8'));
  } catch (err) {
    console.error(`[ERROR] invalid package.json ${manifest}: ${err.message}`);
    process.exit(1);
  }
  if (!pkg || typeof pkg !== 'object' || Array.isArray(pkg)) {
    console.error(`[ERROR] package.json is not an object: ${manifest}`);
    process.exit(1);
  }
  return pkg;
}

function identityOf(pkg) {
  const hasName = typeof pkg.name === 'string' && pkg.name !== '';
  const hasVersion = pkg.version !== undefined && pkg.version !== null && String(pkg.version) !== '';
  return {
    hasName,
    hasVersion,
    name: hasName ? pkg.name : '',
    version: hasVersion ? String(pkg.version) : '',
  };
}

function owningPackage(manifest) {
  let dir = path.dirname(path.dirname(manifest));
  const stop = path.dirname(root);
  while (dir.startsWith(root) && dir !== stop) {
    const candidate = path.join(dir, 'package.json');
    if (fs.existsSync(candidate)) {
      const ident = identityOf(readPackage(candidate));
      if (ident.hasName && ident.hasVersion) {
        return { manifest: candidate, ...ident };
      }
    }
    dir = path.dirname(dir);
  }
  return null;
}

const missing = [];
let versioned = 0;
let unversioned = 0;
let stubs = 0;

for (const manifest of manifests) {
  const ident = identityOf(readPackage(manifest));
  if (ident.hasName && ident.hasVersion && isApplicationManifest(manifest, ident.version)) {
    continue;
  }
  if (ident.hasName && ident.hasVersion) {
    versioned += 1;
    if (!covered(ident.name, ident.version)) {
      missing.push(`${ident.name}@${ident.version} ${manifest}`);
    }
    continue;
  }
  if (ident.hasName) {
    unversioned += 1;
    if (!covered(ident.name, 'UNKNOWN')) {
      missing.push(`${ident.name}@UNKNOWN ${manifest}`);
    }
    continue;
  }
  stubs += 1;
  const owner = owningPackage(manifest);
  if (!owner || !covered(owner.name, owner.version)) {
    missing.push(`unowned ${manifest}`);
  }
}

if (missing.length > 0) {
  console.error('[ERROR] shipped package.json missing from SBOM:');
  for (const item of missing) {
    console.error(item);
  }
  process.exit(1);
}

console.log(
  `sbom covers ${versioned} versioned packages, ${unversioned} unversioned names, ${stubs} stubs, and includes ${sourcePurl}`,
);
