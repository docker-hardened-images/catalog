const fs = require('fs')
const path = require('path')

const outPath = process.env.BROWSER_SBOM
const pkgVersion = process.env.PKG_VERSION
if (!outPath || !pkgVersion) {
  console.error('BROWSER_SBOM and PKG_VERSION are required')
  process.exit(1)
}

const mapPath = 'dist/bundle.js.map'
if (!fs.existsSync(mapPath)) {
  console.error('missing ' + mapPath)
  process.exit(1)
}

const map = JSON.parse(fs.readFileSync(mapPath, 'utf8'))
const sources = map.sources || []
const found = new Map()

function addPackageJson(pjPath) {
  const meta = JSON.parse(fs.readFileSync(pjPath, 'utf8'))
  if (!meta.name || !meta.version) {
    return
  }
  const key = meta.name + '@' + meta.version
  if (found.has(key)) {
    return
  }
  let license = 'NOASSERTION'
  if (typeof meta.license === 'string' && meta.license) {
    license = meta.license
  } else if (meta.license && typeof meta.license.type === 'string') {
    license = meta.license.type
  }
  found.set(key, { name: meta.name, version: meta.version, license: license })
}

function owningPackageJson(src) {
  const s = String(src).split('?')[0].split('#')[0]
  const marker = 'node_modules/'
  const first = s.indexOf(marker)
  if (first < 0) {
    return null
  }
  const parts = s.slice(first).split('/')
  let pj = null
  for (let i = 0; i < parts.length; i++) {
    if (parts[i] !== 'node_modules') {
      continue
    }
    const nameStart = i + 1
    if (nameStart >= parts.length || !parts[nameStart]) {
      continue
    }
    const scoped = parts[nameStart].startsWith('@')
    const nameEnd = scoped ? nameStart + 2 : nameStart + 1
    if (nameEnd > parts.length || !parts[nameEnd - 1]) {
      continue
    }
    const nested = parts.slice(0, nameEnd).join('/') + '/package.json'
    const top = 'node_modules/' + parts.slice(nameStart, nameEnd).join('/') + '/package.json'
    if (fs.existsSync(nested)) {
      pj = nested
    } else if (fs.existsSync(top)) {
      pj = top
    }
  }
  return pj
}

for (const src of sources) {
  const pj = owningPackageJson(src)
  if (pj) {
    addPackageJson(pj)
  }
}

const elk = 'node_modules/elkjs/package.json'
if (fs.existsSync('dist/elk-worker.min.js') && fs.existsSync(elk)) {
  addPackageJson(elk)
}

if (found.size < 20) {
  console.error('bundled package count ' + found.size)
  console.error(sources.slice(0, 40).join('\n'))
  process.exit(1)
}

const required = [
  ['lodash', '4.18.1'],
  ['moment', '2.31.0'],
  ['prismjs', '1.30.0'],
  ['@babel/runtime', '7.26.10'],
  ['react-router', '6.30.6'],
  ['react-router-dom', '6.30.6'],
  ['@remix-run/router', '1.23.4'],
]
for (const pair of required) {
  const name = pair[0]
  const version = pair[1]
  const versions = []
  for (const pkg of found.values()) {
    if (pkg.name === name) {
      versions.push(pkg.version)
    }
  }
  if (versions.length !== 1 || versions[0] !== version) {
    console.error('bundled ' + name + ' versions ' + versions.join(',') + ' want ' + version)
    process.exit(1)
  }
}

function purl(name, version) {
  if (name.startsWith('@')) {
    const parts = name.slice(1).split('/')
    return 'pkg:npm/' + encodeURIComponent('@' + parts[0]) + '/' + encodeURIComponent(parts[1]) + '@' + encodeURIComponent(version)
  }
  return 'pkg:npm/' + encodeURIComponent(name) + '@' + encodeURIComponent(version)
}

function spdxId(name, version) {
  const raw = name + '-' + version
  let id = 'SPDXRef-Package'
  for (const ch of raw) {
    if (/[A-Za-z0-9.-]/.test(ch)) {
      id += ch
    } else {
      id += '-'
    }
  }
  return id
}

const packages = []
const relationships = []
const seenIds = new Set()
const sorted = Array.from(found.values()).sort((a, b) => (a.name + '@' + a.version).localeCompare(b.name + '@' + b.version))
for (const pkg of sorted) {
  let id = spdxId(pkg.name, pkg.version)
  while (seenIds.has(id)) {
    id += '-2'
  }
  seenIds.add(id)
  const tarball = pkg.name.startsWith('@') ? pkg.name.split('/')[1] : pkg.name
  packages.push({
    name: pkg.name,
    SPDXID: id,
    versionInfo: pkg.version,
    downloadLocation: 'https://registry.npmjs.org/' + pkg.name + '/-/' + tarball + '-' + pkg.version + '.tgz',
    filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION',
    licenseDeclared: pkg.license,
    externalRefs: [{
      referenceCategory: 'PACKAGE-MANAGER',
      referenceType: 'purl',
      referenceLocator: purl(pkg.name, pkg.version),
    }],
  })
  relationships.push({
    spdxElementId: 'SPDXRef-DOCUMENT',
    relationshipType: 'DESCRIBES',
    relatedSpdxElement: id,
  })
}

const doc = {
  spdxVersion: 'SPDX-2.3',
  dataLicense: 'CC0-1.0',
  SPDXID: 'SPDXRef-DOCUMENT',
  name: 'marquez-web-browser',
  documentNamespace: 'https://dhi.docker.com/spdx/marquez-web-browser-' + pkgVersion,
  creationInfo: {
    created: '1970-01-01T00:00:00Z',
    creators: ['Organization: Docker, Inc.', 'Tool: dhi/build'],
  },
  packages: packages,
  relationships: relationships,
}

const body = JSON.stringify(doc)
const targets = [
  '/opt/docker/sbom/marquez-web-browser/.spdx.marquez-web-browser.json',
  outPath,
]
for (const target of targets) {
  fs.mkdirSync(path.dirname(target), { recursive: true })
  fs.writeFileSync(target, body, { mode: 0o644 })
}
console.log('browser sbom packages ' + packages.length)
