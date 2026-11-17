#!/usr/bin/env node
// SPDX for the esbuild CLI bundle. The shipped file has no node_modules tree,
// so scanners only see packages named from the metafile inputs.

const fs = require('node:fs')
const path = require('node:path')

const metaPath = process.argv[2]
const outPath = process.argv[3]
const version = process.argv[4]

if (!metaPath || !outPath || !version) {
  console.error('usage: bundle-spdx.cjs <meta.json> <out.json> <version>')
  process.exit(1)
}

const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'))
const esbuildCwd = path.resolve(path.dirname(metaPath), '..')
const found = new Map()

function add(name, ver) {
  if (!name || !ver) {
    return
  }
  if (name === 'socket-cli-monorepo' || name === '.pnpm') {
    return
  }
  if (ver === '0.0.0' || ver.startsWith('0.0.0-')) {
    return
  }
  found.set(`${name}@${ver}`, {name, version: ver})
}

add('socket', version)
add('@socketsecurity/cli', version)

function readPkg(dir) {
  const pkgPath = path.join(dir, 'package.json')
  if (!fs.existsSync(pkgPath)) {
    return null
  }
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'))
    if (!pkg.name || !pkg.version) {
      return null
    }
    return pkg
  } catch {
    return null
  }
}

for (const input of Object.keys(meta.inputs || {})) {
  if (!input.includes('node_modules')) {
    continue
  }
  const abs = path.isAbsolute(input) ? input : path.resolve(esbuildCwd, input)
  let dir = path.dirname(abs)
  for (let i = 0; i < 12; i++) {
    const inModules = dir.includes(`${path.sep}node_modules${path.sep}`) || dir.endsWith(`${path.sep}node_modules`)
    if (inModules) {
      const pkg = readPkg(dir)
      if (pkg) {
        add(pkg.name, pkg.version)
        break
      }
    }
    const parent = path.dirname(dir)
    if (parent === dir) {
      break
    }
    dir = parent
  }
}

const hasLib = [...found.values()].some(pkg => pkg.name === '@socketsecurity/lib')
if (!hasLib) {
  console.error('bundled SBOM is missing @socketsecurity/lib')
  console.error(Object.keys(meta.inputs || {}).slice(0, 40).join('\n'))
  process.exit(1)
}
if (found.size < 8) {
  console.error(`bundled SBOM only found ${found.size} packages`)
  process.exit(1)
}

function spdxId(name, ver) {
  return `SPDXRef-${(name + '-' + ver).replace(/[^A-Za-z0-9.+-]/g, '-')}`
}

const packages = [...found.values()].sort((a, b) => (a.name + a.version).localeCompare(b.name + b.version))
const spdxPackages = []
const relationships = []
const seenIds = new Set()
for (const pkg of packages) {
  let id = spdxId(pkg.name, pkg.version)
  while (seenIds.has(id)) {
    id += '-dup'
  }
  seenIds.add(id)
  // braces is patched in-tree. 3.0.4 is not an npm release, so the component
  // is recorded as this package's DHI purl instead of pkg:npm/braces@<version>.
  const patchedBraces = pkg.name === 'braces'
  const license = pkg.name === 'socket' || pkg.name === '@socketsecurity/cli' ? 'MIT' : 'NOASSERTION'
  const componentVersion = patchedBraces ? version : pkg.version
  const componentPurl = patchedBraces
    ? `pkg:dhi/socket-cli@${version}`
    : `pkg:npm/${pkg.name}@${pkg.version}`
  spdxPackages.push({
    SPDXID: id,
    name: patchedBraces ? 'socket-cli' : pkg.name,
    versionInfo: componentVersion,
    downloadLocation: 'NOASSERTION',
    filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION',
    licenseDeclared: license,
    externalRefs: [
      {
        referenceCategory: 'PACKAGE-MANAGER',
        referenceType: 'purl',
        referenceLocator: componentPurl,
      },
    ],
  })
  relationships.push({
    spdxElementId: 'SPDXRef-DOCUMENT',
    relatedSpdxElement: id,
    relationshipType: 'DESCRIBES',
  })
}

const doc = {
  spdxVersion: 'SPDX-2.3',
  dataLicense: 'CC0-1.0',
  SPDXID: 'SPDXRef-DOCUMENT',
  name: `SPDX document for socket-cli bundle ${version}`,
  documentNamespace: `https://dhi.docker.com/spdx/socket-cli-bundle-${version}`,
  creationInfo: {
    created: '1970-01-01T00:00:00Z',
    creators: ['Organization: Docker, Inc.', 'Tool: dhi/build'],
  },
  packages: spdxPackages,
  relationships,
}

fs.mkdirSync(path.dirname(outPath), {recursive: true})
fs.writeFileSync(outPath, JSON.stringify(doc) + '\n')
console.log(`wrote ${packages.length} bundled packages to ${outPath}`)
