'use strict';

const fs = require('fs');
const path = require('path');
const Module = require('module');

const root = path.resolve(process.argv[2] || '');
const entry = path.join(root, 'api/server/index.js');
if (!fs.existsSync(entry)) {
  console.error(`usage: node check-module-graph.cjs <staged-root> (missing ${entry})`);
  process.exit(1);
}

require(path.join(root, 'node_modules/module-alias'))({
  base: path.join(root, 'api'),
});

const requireRe = /require\(\s*['"]([^'"]+)['"]\s*\)/g;
const seen = new Set();
const failures = [];

function dropped(resolved) {
  const rel = path.relative(root, resolved);
  if (rel.startsWith('..')) {
    return false;
  }
  if (/^packages\/[^/]+\/src\//.test(rel)) {
    return true;
  }
  if (rel.startsWith('client/src/') || rel.startsWith('e2e/') || rel.startsWith('api/test/')) {
    return true;
  }
  if (rel.endsWith('.ts') || rel.endsWith('.tsx')) {
    return true;
  }
  return false;
}

function walk(file) {
  if (seen.has(file)) {
    return;
  }
  seen.add(file);
  let src;
  try {
    src = fs.readFileSync(file, 'utf8');
  } catch (err) {
    failures.push(`${file}: ${err.message}`);
    return;
  }
  const creq = Module.createRequire(file);
  requireRe.lastIndex = 0;
  let match;
  while ((match = requireRe.exec(src))) {
    const spec = match[1];
    if (spec.startsWith('node:')) {
      continue;
    }
    let resolved;
    try {
      resolved = creq.resolve(spec);
    } catch (err) {
      failures.push(`${path.relative(root, file)} -> ${spec}: ${err.message}`);
      continue;
    }
    if (dropped(resolved)) {
      failures.push(`${path.relative(root, file)} -> ${spec} resolved into dropped path ${resolved}`);
      continue;
    }
    if (!resolved.startsWith(root) || resolved.includes(`${path.sep}node_modules${path.sep}`)) {
      continue;
    }
    if (/\.(cjs|mjs|js|json)$/.test(resolved)) {
      walk(resolved);
    }
  }
}

function collect(dir) {
  if (!fs.existsSync(dir)) {
    return;
  }
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === '__tests__' || entry.name === 'test') {
        continue;
      }
      collect(full);
      continue;
    }
    if (/\.(cjs|mjs|js)$/.test(entry.name) && !entry.name.endsWith('.spec.js')) {
      walk(full);
    }
  }
}

walk(path.join(root, 'api/server/index.js'));
collect(path.join(root, 'config'));

if (failures.length) {
  console.error(`[ERROR] module graph has ${failures.length} failure(s)`);
  for (const line of failures.slice(0, 40)) {
    console.error(line);
  }
  process.exit(1);
}

console.log(`module graph ok (${seen.size} files)`);
