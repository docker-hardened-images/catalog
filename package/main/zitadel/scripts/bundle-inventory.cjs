#!/usr/bin/env node
// Bundle inventory for the ZITADEL console and the statik-embedded Login V1,
// notification and internal/static trees.
//
// The Go buildinfo cataloger sees Go modules only. The console bundle embeds
// npm code that appears in no package manifest the scanner reads, so this
// script derives the inventory from what the bundler actually emitted:
//
//   1. every esbuild metafile input with bytesInOutput > 0 (see stats.json
//      from `ng build --stats-json`), plus the global script in angular.json;
//   2. every file that Angular copied from console/src/assets into dist/console;
//   3. every file under the three statik-embedded trees.
//
// Each contributing path maps to exactly one component. Anything unmapped,
// anything without license text, and any reconciliation mismatch is fatal.
//
// usage:
//   node bundle-inventory.cjs \
//     --console-dir <console> --workspace-root <root> --metafile <stats.json> \
//     --dist-dir <dist/console> --statik-dirs <a,b,c> --license-dir <dir> \
//     --version <zitadel version> --line-awesome-version <v> \
//     --protobuf-js-version <v> --buf-lock <proto/buf.lock> \
//     --out-sbom <file> --out-notices <file>

'use strict'

const fs = require('node:fs')
const path = require('node:path')

// ---------------------------------------------------------------- arguments

function parseArgs(argv) {
  const out = {}
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]
    if (!key.startsWith('--') || argv[i + 1] === undefined) {
      die(`bad argument near ${key}`)
    }
    out[key.slice(2)] = argv[i + 1]
  }
  const required = [
    'console-dir', 'workspace-root', 'metafile', 'dist-dir', 'statik-dirs',
    'license-dir', 'version', 'line-awesome-version', 'protobuf-js-version',
    'buf-lock', 'out-sbom', 'out-notices',
  ]
  for (const key of required) {
    if (!out[key]) {
      die(`missing --${key}`)
    }
  }
  return out
}

function die(msg) {
  console.error(`bundle-inventory: ${msg}`)
  process.exit(1)
}

const args = parseArgs(process.argv.slice(2))
const consoleDir = path.resolve(args['console-dir'])
const workspaceRoot = path.resolve(args['workspace-root'])
const distDir = path.resolve(args['dist-dir'])
const licenseDir = path.resolve(args['license-dir'])
const zitadelVersion = args.version
const statikDirs = args['statik-dirs'].split(',').map(d => path.resolve(d))

// -------------------------------------------------------------- license inputs

const pinnedLicenses = {
  apache: readRequired(path.join(licenseDir, 'Apache-2.0.txt')),
  ofl: readRequired(path.join(licenseDir, 'OFL-1.1.txt')),
  lineAwesome: readRequired(path.join(licenseDir, 'line-awesome-LICENSE.md')),
  protobufJs: readRequired(path.join(licenseDir, 'protobuf-javascript-LICENSE.md')),
  grpcGateway: readRequired(path.join(licenseDir, 'grpc-gateway-LICENSE')),
  mitZitadel: readRequired(path.join(licenseDir, 'MIT-zitadel.txt')),
}

function readRequired(file) {
  if (!fs.existsSync(file)) {
    die(`license input missing: ${file}`)
  }
  const text = fs.readFileSync(file, 'utf8')
  if (text.trim() === '') {
    die(`license input empty: ${file}`)
  }
  return text
}

// buf.lock pins the BSR modules whose generated code ships in the console.
const bufCommits = parseBufLock(args['buf-lock'])

function parseBufLock(file) {
  const commits = {}
  let repo = null
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const r = line.match(/^\s+repository:\s*(\S+)/)
    if (r) {
      repo = r[1]
    }
    const c = line.match(/^\s+commit:\s*([0-9a-f]+)/)
    if (c && repo) {
      commits[repo] = c[1]
      repo = null
    }
  }
  for (const need of ['protoc-gen-validate', 'googleapis', 'grpc-gateway']) {
    if (!commits[need]) {
      die(`buf.lock has no commit for ${need}`)
    }
  }
  return commits
}

// -------------------------------------------------------------- components

// key: name@version -> {name, version, purl, licenseDeclared, text, notices[]}
const components = new Map()
// Files that are shipped but correspond to no SPDX row (brand marks).
const brandMarks = new Set()
const unmapped = []

function addComponent(c) {
  const key = `${c.name}@${c.version}`
  const existing = components.get(key)
  if (existing) {
    if (existing.purl !== c.purl || existing.licenseDeclared !== c.licenseDeclared) {
      die(`conflicting rows for ${key}`)
    }
    return existing
  }
  const row = {
    name: c.name,
    version: c.version,
    purl: c.purl,
    licenseDeclared: c.licenseDeclared,
    text: c.text || '',
    notices: c.notices || [],
    sources: new Set(),
  }
  components.set(key, row)
  return row
}

function slug(name) {
  return name.replace(/^@/, '').replace(/[\/+]/g, '-')
}

// -------------------------------------------------------------- npm packages

const npmCache = new Map()

// Resolve a file under node_modules to its package root and manifest.
function npmComponentFor(absFile) {
  const real = fs.realpathSync(absFile)
  const marker = `${path.sep}node_modules${path.sep}`
  const idx = real.lastIndexOf(marker)
  if (idx < 0) {
    return null
  }
  const after = real.slice(idx + marker.length).split(path.sep)
  const segs = after[0].startsWith('@') ? after.slice(0, 2) : after.slice(0, 1)
  const root = real.slice(0, idx + marker.length) + segs.join(path.sep)
  if (npmCache.has(root)) {
    return npmCache.get(root)
  }
  const pkgFile = path.join(root, 'package.json')
  if (!fs.existsSync(pkgFile)) {
    die(`no package.json for bundled file ${absFile} (root ${root})`)
  }
  const pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'))
  if (!pkg.name || !pkg.version) {
    die(`package.json without name/version: ${pkgFile}`)
  }
  const licenseDeclared = typeof pkg.license === 'string'
    ? pkg.license
    : (pkg.license && pkg.license.type) || 'NOASSERTION'
  const entries = fs.readdirSync(root).sort()
  const licenseFile = entries.find(f => /^(LICEN[CS]E|COPYING)([.-].*)?$/i.test(f))
  const notices = entries
    .filter(f => /^NOTICE/i.test(f))
    .map(f => fs.readFileSync(path.join(root, f), 'utf8'))
  const text = licenseFile ? fs.readFileSync(path.join(root, licenseFile), 'utf8') : ''
  const row = addComponent({
    name: pkg.name,
    version: pkg.version,
    purl: `pkg:npm/${pkg.name.replace('@', '%40')}@${pkg.version}`,
    licenseDeclared,
    text,
    notices,
  })
  npmCache.set(root, row)
  return row
}

// --------------------------------------------------------- font name tables

// Minimal TrueType name-table reader: returns {family, version, copyright}
// from the Windows (platform 3) records. Used to set font versions from the
// shipped bytes instead of a hand list.
function readFontName(file) {
  const buf = fs.readFileSync(file)
  const numTables = buf.readUInt16BE(4)
  let nameOff = -1
  for (let i = 0; i < numTables; i++) {
    const rec = 12 + i * 16
    if (buf.toString('latin1', rec, rec + 4) === 'name') {
      nameOff = buf.readUInt32BE(rec + 8)
    }
  }
  if (nameOff < 0) {
    die(`no name table in ${file}`)
  }
  const count = buf.readUInt16BE(nameOff + 2)
  const strOff = nameOff + buf.readUInt16BE(nameOff + 4)
  const want = {}
  for (let i = 0; i < count; i++) {
    const r = nameOff + 6 + i * 12
    const platform = buf.readUInt16BE(r)
    const nameId = buf.readUInt16BE(r + 6)
    if (platform !== 3 || ![0, 1, 5].includes(nameId) || want[nameId]) {
      continue
    }
    const len = buf.readUInt16BE(r + 8)
    const off = buf.readUInt16BE(r + 10)
    const raw = buf.subarray(strOff + off, strOff + off + len)
    want[nameId] = swapUtf16(raw)
  }
  const v = (want[5] || '').match(/([0-9]+(?:\.[0-9]+)+)/)
  if (!v) {
    die(`no version in name table of ${file}`)
  }
  return {family: want[1] || '', version: v[1], copyright: want[0] || ''}
}

// Platform 3 name strings are UTF-16BE.
function swapUtf16(raw) {
  return Buffer.from(raw).swap16().toString('utf16le')
}

// Each bundled font family maps to one row. Version comes from the bytes.
const fontFamilies = {
  lato: {dirRel: 'resources/fonts/lato', name: 'Lato', license: 'OFL-1.1', text: () => {
    const f = path.join(statikDirs[0], 'resources/fonts/lato/OFL.txt')
    return fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : pinnedLicenses.ofl
  }},
  raleway: {dirRel: 'resources/fonts/Raleway', name: 'Raleway', license: 'OFL-1.1', text: () => pinnedLicenses.ofl},
  'pt-sans': {dirRel: 'resources/fonts/PT_Sans', name: 'PT Sans', license: 'OFL-1.1', text: () => pinnedLicenses.ofl},
  roboto: {dirRel: 'resources/fonts/Roboto', name: 'Roboto', license: 'Apache-2.0', text: () => pinnedLicenses.apache},
}

function fontRow(family) {
  const spec = fontFamilies[family]
  const dirs = [path.join(consoleDir, 'src/assets/fonts', family)]
  for (const s of statikDirs) {
    dirs.push(path.join(s, spec.dirRel))
  }
  const dir = dirs.find(d => fs.existsSync(d))
  if (!dir) {
    return null
  }
  const ttf = fs.readdirSync(dir).filter(f => /\.ttf$/i.test(f)).sort()[0]
  if (!ttf) {
    die(`no .ttf in ${dir}`)
  }
  const meta = readFontName(path.join(dir, ttf))
  return addComponent({
    name: spec.name,
    version: meta.version,
    purl: `pkg:generic/${slug(spec.name.toLowerCase().replace(/ /g, '-'))}@${meta.version}`,
    licenseDeclared: spec.license,
    text: spec.text(),
  })
}

// ------------------------------------------------ fixed-version source rows

const zitadelProto = addComponent({
  name: '@zitadel/proto',
  version: zitadelVersion,
  purl: `pkg:dhi/zitadel-proto@${zitadelVersion}`,
  licenseDeclared: 'MIT',
  text: pinnedLicenses.mitZitadel,
})
const zitadelClient = addComponent({
  name: '@zitadel/client',
  version: zitadelVersion,
  purl: `pkg:dhi/zitadel-client@${zitadelVersion}`,
  licenseDeclared: 'MIT',
  text: pinnedLicenses.mitZitadel,
})
const mdi = {
  name: 'material-design-icons-vendored',
  version: zitadelVersion,
  purl: `pkg:generic/material-design-icons-vendored@${zitadelVersion}`,
  licenseDeclared: 'Apache-2.0',
  text: pinnedLicenses.apache,
}
const lineAwesome = addComponent({
  name: 'line-awesome',
  version: args['line-awesome-version'],
  purl: `pkg:generic/line-awesome@${args['line-awesome-version']}`,
  licenseDeclared: 'MIT',
  text: pinnedLicenses.lineAwesome,
})

// Proto-origin code compiled into the console. Each vendored module is its own row.
const protoOrigin = {
  'google-protobuf-wkt': {
    name: 'protobuf-well-known-types', version: args['protobuf-js-version'],
    purl: `pkg:generic/protobuf-well-known-types@${args['protobuf-js-version']}`,
    licenseDeclared: 'BSD-3-Clause', text: pinnedLicenses.protobufJs,
  },
  googleapis: {
    name: 'googleapis', version: bufCommits.googleapis,
    purl: `pkg:generic/googleapis@${bufCommits.googleapis}`,
    licenseDeclared: 'Apache-2.0', text: pinnedLicenses.apache,
  },
  validate: {
    name: 'protoc-gen-validate', version: bufCommits['protoc-gen-validate'],
    purl: `pkg:generic/protoc-gen-validate@${bufCommits['protoc-gen-validate']}`,
    licenseDeclared: 'Apache-2.0', text: pinnedLicenses.apache,
  },
  openapiv2: {
    name: 'grpc-gateway-openapiv2-options', version: bufCommits['grpc-gateway'],
    purl: `pkg:generic/grpc-gateway-openapiv2-options@${bufCommits['grpc-gateway']}`,
    licenseDeclared: 'BSD-3-Clause', text: pinnedLicenses.grpcGateway,
  },
}

// ---------------------------------------------------------- classification

function classifyProtoOrigin(rel) {
  // rel is the path under the generated root, e.g. google/protobuf/any_pb.js
  if (rel.startsWith('google/protobuf/')) {
    return protoOrigin['google-protobuf-wkt']
  }
  if (rel.startsWith('google/')) {
    return protoOrigin.googleapis
  }
  if (rel.startsWith('validate/')) {
    return protoOrigin.validate
  }
  if (rel.startsWith('protoc-gen-openapiv2/')) {
    return protoOrigin.openapiv2
  }
  return null
}

// Map one console-relative source path to a component row (or null if it
// ships with no row, or is first-party code covered by the pkg:dhi row).
function classifyConsolePath(rel, from) {
  const p = rel.replace(/\/+$/, '')

  if (p.startsWith('src/app/proto/generated/')) {
    const sub = p.slice('src/app/proto/generated/'.length)
    const row = classifyProtoOrigin(sub)
    if (row) {
      return addRow(row, from)
    }
    return null
  }

  if (p.startsWith('../packages/zitadel-proto/') || p.startsWith('../packages/zitadel-client/')) {
    const pkgName = p.startsWith('../packages/zitadel-proto/') ? 'zitadel-proto' : 'zitadel-client'
    const rest = p.slice(`../packages/${pkgName}/`.length)
    if (rest.startsWith('es/')) {
      const row = classifyProtoOrigin(rest.slice(3))
      if (row) {
        return addRow(row, from)
      }
    }
    return addRow(pkgName === 'zitadel-proto' ? zitadelProto : zitadelClient, from)
  }

  if (p.includes('node_modules/')) {
    const abs = path.resolve(consoleDir, p)
    if (!fs.existsSync(abs)) {
      die(`bundled path does not exist: ${p}`)
    }
    return addRow(npmComponentFor(abs), from)
  }

  if (p.startsWith('src/assets/')) {
    const a = p.slice('src/assets/'.length)
    if (a.startsWith('fonts/')) {
      const family = a.split('/')[1]
      if (fontFamilies[family]) {
        return addRow(fontRow(family), from)
      }
      die(`unclassified font: ${p}`)
    }
    if (a.startsWith('icons/line-awesome/')) {
      return addRow(lineAwesome, from)
    }
    // Vendored Material Design Icons subset. Neither the tree nor pnpm-lock.yaml
    // pins an upstream version, so the row is keyed by the zitadel tag that
    // vendored the bytes and its purl names the vendored copy.
    if (a.startsWith('mdi/')) {
      return addRow(mdi, from)
    }
    if (a.startsWith('images/idp/') || a.startsWith('images/smtp/')) {
      brandMarks.add(p)
      return null
    }
    // First-party: translations, the apps/docs image copy, root logos, and the
    // ZITADEL favicon and tile icons directly under icons/ and images/.
    if (a.startsWith('i18n/') || a.startsWith('docs/') || !a.includes('/') ||
        /^icons\/[^/]+$/.test(a) || /^images\/[^/]+$/.test(a)) {
      return null
    }
    die(`unclassified asset: ${p}`)
  }

  if (p.startsWith('src/')) {
    return null
  }

  // apps/docs content (frameworks.json, tech logos) is Apache-2.0 under this
  // repository's LICENSING.md and is covered by the zitadel row.
  if (p.startsWith('../apps/docs/')) {
    return null
  }

  if (p.startsWith('angular:') || p === '') {
    return null
  }

  unmapped.push(`${from}: ${p}`)
  return null
}

function addRow(row, from) {
  if (!row) {
    return null
  }
  // Fixed-version rows are plain descriptions until registered here.
  const registered = row.sources instanceof Set ? row : addComponent(row)
  if (from) {
    registered.sources.add(from)
  }
  return registered
}

// Angular copies these from console/src/assets into dist; map them by source.
function classifyDistAsset(rel, from) {
  return classifyConsolePath(`src/assets/${rel}`, from)
}

// ------------------------------------------------------- metafile inputs

const meta = JSON.parse(fs.readFileSync(args.metafile, 'utf8'))
const contributing = new Set()
const outputKeys = new Set(Object.keys(meta.outputs || {}))

for (const out of Object.values(meta.outputs || {})) {
  for (const [input, info] of Object.entries(out.inputs || {})) {
    if (info.bytesInOutput > 0) {
      contributing.add(input)
    }
  }
}

if (contributing.size === 0) {
  die('metafile has no contributing inputs')
}

// Angular's synthetic global-script input resolves to the angular.json scripts list.
function globalScriptFiles() {
  const angular = JSON.parse(fs.readFileSync(path.join(consoleDir, 'angular.json'), 'utf8'))
  const project = Object.values(angular.projects)[0]
  const opts = (project.architect || project.targets).build.options
  return (opts.scripts || []).map(s => s.replace(/^\.\//, ''))
}

for (let input of contributing) {
  if (input.startsWith('angular:script/global:')) {
    for (const f of globalScriptFiles()) {
      classifyConsolePath(f, input)
    }
    continue
  }
  if (input.startsWith('angular:styles/global:')) {
    continue
  }
  input = input.replace(/^angular:css-resource:/, '')
  classifyConsolePath(input, 'metafile')
}

// ---------------------------------------------------- dist asset walk

function walk(dir, base = dir) {
  const out = []
  for (const e of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, e.name)
    if (e.isDirectory()) {
      out.push(...walk(full, base))
    } else {
      out.push(path.relative(base, full).split(path.sep).join('/'))
    }
  }
  return out
}

const distFiles = walk(distDir)
const topLevelFirstParty = /^(index\.html|favicon\.ico|manifest\.webmanifest|prerendered-routes\.json|3rdpartylicenses\.txt)$/
const generatedName = /^(main|polyfills|scripts|styles|chunk)-[A-Z0-9]+\.(js|css)$/

for (const rel of distFiles) {
  if (rel.startsWith('assets/')) {
    classifyDistAsset(rel.slice('assets/'.length), `dist:${rel}`)
    continue
  }
  if (topLevelFirstParty.test(rel) || generatedName.test(rel) || rel.endsWith('.map')) {
    continue
  }
  if (outputKeys.has(rel)) {
    continue
  }
  unmapped.push(`dist file not in metafile outputs: ${rel}`)
}

if (unmapped.length) {
  console.error('unmapped bundle paths:')
  for (const u of unmapped) {
    console.error(`  ${u}`)
  }
  process.exit(1)
}

// ----------------------------------------------- statik-embedded trees

const statikRules = [
  [/^resources\/fonts\/lato\//, () => fontRow('lato')],
  [/^resources\/fonts\/Roboto\//, () => fontRow('roboto')],
  [/^resources\/fonts\/Raleway\//, () => fontRow('raleway')],
  [/^resources\/fonts\/PT_Sans\//, () => fontRow('pt-sans')],
  [/^resources\/fonts\/lgn-icons\//, () => lineAwesome],
  [/^resources\/images\/idp\//, () => null],
]
const statikFirstParty = [
  /^templates\//,
  /^i18n\//,
  /^scripts\//,
  /^resources\/scripts\//,
  /^resources\/themes\//,
  /^resources\/images\/(?!idp\/)/,
  /^config\//,
  /^database\//,
  /^mock\//,
  /^s3\//,
  /^storage\.go$/,
  /\.go$/,
  /\.(html|mjml|yaml|json|css|scss|svg|ttf|woff2?|map)$/,
]

const statikUnmapped = []
for (const dir of statikDirs) {
  for (const rel of walk(dir)) {
    const hit = statikRules.find(([re]) => re.test(rel))
    if (hit) {
      const row = hit[1]()
      if (row) {
        addRow(row, `statik:${rel}`)
      } else {
        brandMarks.add(`statik:${rel}`)
      }
      continue
    }
    if (statikFirstParty.some(re => re.test(rel))) {
      continue
    }
    statikUnmapped.push(`${dir}/${rel}`)
  }
}

if (statikUnmapped.length) {
  console.error('unclassified statik-embedded files:')
  for (const u of statikUnmapped) {
    console.error(`  ${u}`)
  }
  process.exit(1)
}

// --------------------------------------------------- reconciliation

// (3) every third-party row needs license text.
// Some npm tarballs declare a license but ship no license file. For these exact
// name@version pins the text comes from a pinned input instead (docs/general.md
// allows a pinned license input). A version bump drops the pin and fails here,
// so the new tarball is reviewed before its text is trusted.
const pinnedTextFor = {
  'grpc-web@2.0.2': () => pinnedLicenses.apache,
  '@connectrpc/connect@2.1.2': () => pinnedLicenses.apache,
  '@connectrpc/connect-web@2.1.2': () => pinnedLicenses.apache,
  // Apache-2.0 for the package; its generated well-known types carry Google's BSD-3 notice.
  '@bufbuild/protobuf@2.13.0': () => [pinnedLicenses.apache, pinnedLicenses.protobufJs].join('\n\n'),
  '@ng-icons/core@33.4.0': () => readRequired(path.join(licenseDir, 'ng-icons-LICENSE.md')),
}
for (const row of components.values()) {
  const key = `${row.name}@${row.version}`
  if ((!row.text || row.text.trim() === '') && pinnedTextFor[key]) {
    row.text = pinnedTextFor[key]()
  }
}

const noText = [...components.values()].filter(row => !row.text || row.text.trim() === '')
if (noText.length) {
  console.error('components without shipped license text:')
  for (const row of noText) {
    console.error(`  ${row.name}@${row.version} (declared ${row.licenseDeclared})`)
  }
  process.exit(1)
}

// (4) every "Package:" entry in Angular's extractor output must have a row.
const angularNotices = fs.readFileSync(path.join(distDir, '3rdpartylicenses.txt'), 'utf8')
const angularPackages = [...angularNotices.matchAll(/^Package: (.+)$/gm)].map(m => m[1].trim())
const names = new Set([...components.values()].map(r => r.name))
const missingFromInventory = angularPackages.filter(n => !names.has(n))
if (missingFromInventory.length) {
  die(`Angular lists packages missing from the inventory: ${missingFromInventory.join(', ')}`)
}

// (5) sentinel rows must exist; build-only tools must not.
for (const sentinel of ['@zitadel/proto', '@zitadel/client', '@angular/core', 'google-protobuf', 'grpc-web', 'tinycolor2']) {
  if (!names.has(sentinel)) {
    die(`sentinel row missing: ${sentinel}`)
  }
}
for (const forbidden of ['typescript', 'esbuild', '@angular/cli', '@angular/build', 'sass', '@bufbuild/buf']) {
  if (names.has(forbidden)) {
    die(`build-only tool must not appear in the bundle inventory: ${forbidden}`)
  }
}

// --------------------------------------------------------- SPDX output

const rows = [...components.values()].sort((a, b) => (a.name + '@' + a.version).localeCompare(b.name + '@' + b.version))

function spdxId(row) {
  return `SPDXRef-${(row.name + '-' + row.version).replace(/[^A-Za-z0-9.+-]/g, '-')}`
}

const seen = new Set()
const spdxPackages = []
const relationships = []
for (const row of rows) {
  let id = spdxId(row)
  while (seen.has(id)) {
    id += '-dup'
  }
  seen.add(id)
  spdxPackages.push({
    SPDXID: id,
    name: row.name,
    versionInfo: row.version,
    downloadLocation: 'NOASSERTION',
    filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION',
    licenseDeclared: row.licenseDeclared,
    externalRefs: [{
      referenceCategory: 'PACKAGE-MANAGER',
      referenceType: 'purl',
      referenceLocator: row.purl,
    }],
  })
  relationships.push({
    spdxElementId: 'SPDXRef-DOCUMENT',
    relatedSpdxElement: id,
    relationshipType: 'DESCRIBES',
  })
}

const sbom = {
  spdxVersion: 'SPDX-2.3',
  dataLicense: 'CC0-1.0',
  SPDXID: 'SPDXRef-DOCUMENT',
  name: `SPDX document for zitadel console bundle ${zitadelVersion}`,
  documentNamespace: `https://dhi.docker.com/spdx/zitadel-console-${zitadelVersion}`,
  creationInfo: {
    created: '1970-01-01T00:00:00Z',
    creators: ['Organization: Docker, Inc.', 'Tool: dhi/build'],
  },
  packages: spdxPackages,
  relationships,
}

// Brand marks have no row by design; report them so the build log shows them.
console.log(`brand-mark assets (no SPDX row): ${brandMarks.size}`)

// ------------------------------------------------ THIRD-PARTY-NOTICES

const sections = rows.map(row => {
  const lines = [
    '================================================================',
    `Component: ${row.name}`,
    `Version: ${row.version}`,
    `Declared license: ${row.licenseDeclared}`,
    `Package URL: ${row.purl}`,
    '----------------------------------------------------------------',
    row.text.replace(/\s+$/, ''),
  ]
  for (const n of row.notices) {
    lines.push('----------------------------------------------------------------', 'NOTICE:', n.replace(/\s+$/, ''))
  }
  return lines.join('\n')
})

const notices = [
  `THIRD-PARTY-NOTICES for ZITADEL ${zitadelVersion} (console and embedded UI bundle)`,
  'Generated from the esbuild metafile and the statik trees at build time.',
  '',
  sections.join('\n\n'),
  '',
].join('\n')

fs.mkdirSync(path.dirname(path.resolve(args['out-sbom'])), {recursive: true})
fs.writeFileSync(args['out-sbom'], JSON.stringify(sbom, null, 2) + '\n')
fs.mkdirSync(path.dirname(path.resolve(args['out-notices'])), {recursive: true})
fs.writeFileSync(args['out-notices'], notices)

console.log(`wrote ${rows.length} bundled components to ${args['out-sbom']}`)
