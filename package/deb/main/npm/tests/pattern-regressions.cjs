const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { pathToFileURL } = require('node:url')

async function main() {
  const only = process.argv[2] === '--minimatch-only'
  const root = path.resolve(process.argv[only ? 3 : 2])
  const mmRoot = only ? root : path.join(root, 'node_modules/minimatch')
  for (const mod of [require(path.join(mmRoot, 'dist/commonjs/index.js')),
    await import(pathToFileURL(path.join(mmRoot, 'dist/esm/index.js')).href)]) {
    const { Minimatch, minimatch, makeRe, AST } = mod
    assert.equal(typeof makeRe, 'function')
    assert.equal(typeof AST.fromGlob, 'function')
    assert(makeRe('*.js').test('test.js'))
    const pattern = Array(30).fill('**/../a/b').join('/')
    const start = Date.now()
    const bounded = new Minimatch(pattern, { optimizationLevel: 2, braceExpandMax: 64 })
    assert.equal(bounded.set.length, 64)
    assert(Date.now() - start < 5000, 'pattern compilation exceeded its budget')
    const normal = new Minimatch('**/../a/b/**/../c/d', { optimizationLevel: 2 })
    assert.equal(normal.set.length, 4)
    assert(normal.match('../a/b/../c/d'))
    assert(normal.match('x/a/b/y/c/d'))
    const large = new Minimatch('{x,*}/{0..999}', { optimizationLevel: 2 })
    assert.equal(large.set.length, 2000)
    assert(large.match('y/999'))
    assert(!large.match('.y/5'))
    assert(minimatch('src/a.js', '**/*.@(js|ts)'))
  }
  if (!only) {
    const semver = require(path.join(root, 'node_modules/semver'))
    const version = require(path.join(mmRoot, 'package.json')).version
    assert(semver.satisfies(version, '^10.2.5'), 'backport must satisfy npm and glob dependency ranges')
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-glob-abort-'))
    function tree(dir, depth) {
      fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, 'file'), '')
      if (depth) for (const name of ['a', 'b']) tree(path.join(dir, name), depth - 1)
    }
    tree(cwd, 5)
    try {
      for (const g of [require(path.join(root, 'node_modules/glob/dist/commonjs/index.js')),
        await import(pathToFileURL(path.join(root, 'node_modules/glob/dist/esm/index.js')).href)]) {
        for (const mode of ['glob', 'globStream', 'globStreamSync']) {
          const ac = new AbortController(); const reason = new Error('regression-abort'); let reads = 0
          const count = () => { if (++reads === 1) ac.abort(reason) }
          const counted = { ...fs,
            readdir: (...args) => { count(); return fs.readdir(...args) },
            readdirSync: (...args) => { count(); return fs.readdirSync(...args) },
          }
          const opts = { cwd, signal: ac.signal, fs: counted }
          await assert.rejects(async () => {
            if (mode === 'glob') await g.glob('**', opts)
            else await new Promise((resolve, reject) => {
              const stream = g[mode]('**', opts)
              stream.on('error', reject)
              stream.on('end', resolve)
              stream.resume()
            })
          }, error => error === reason)
          const atReject = reads
          await new Promise(resolve => setTimeout(resolve, 150))
          assert.equal(atReject, 1, mode + ' read beyond cancellation')
          assert.equal(reads, atReject, mode + ' continued after rejection')
        }
      }
    } finally { fs.rmSync(cwd, { recursive: true, force: true }) }
  }
  console.log('PATTERN_REGRESSIONS_OK')
}
main().catch(error => { console.error(error); process.exitCode = 1 })
