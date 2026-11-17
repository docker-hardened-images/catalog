// Derives the exact npm inventory of the keel web UI from the built bundle and
// checks it against the shipped files. Node built-ins only.
//
// Modes:
//   node ui-inventory.mjs inventory <uiDir> <outDir>
//       Writes <outDir>/ui-inventory.json and <outDir>/sbom-root/node_modules/<pkg>/package.json
//       for exactly the inventoried components. Fails on any unattributed shipped file.
//   node ui-inventory.mjs check-sbom <uiDir> <outDir> <spdx.json>
//       Fails unless the pkg:npm rows of the SBOM equal ui-inventory.json exactly.
//   node ui-inventory.mjs notices <uiDir> <outDir>
//       Copies each inventoried component's root license files to
//       <outDir>/npm/<name>@<version>/ and fails if a component has none or
//       declares no usable license.

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [mode, uiArg, outArg, extra] = process.argv.slice(2);
if (!mode || !uiArg || !outArg) {
  console.error("usage: ui-inventory.mjs <inventory|check-sbom|notices> <uiDir> <outDir> [spdx.json]");
  process.exit(2);
}

const ui = path.resolve(uiArg);
const out = path.resolve(outArg);
const dist = path.join(ui, "dist");
const assets = path.join(dist, "assets");

function die(msg) {
  console.error("ui-inventory: " + msg);
  process.exit(1);
}

function walk(dir, skipNodeModules = false) {
  const files = [];
  if (!fs.existsSync(dir)) return files;
  const stack = [dir];
  while (stack.length) {
    const d = stack.pop();
    for (const ent of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, ent.name);
      if (ent.isDirectory()) {
        if (skipNodeModules && ent.name === "node_modules") continue;
        stack.push(p);
      } else if (ent.isFile()) {
        files.push(p);
      }
    }
  }
  return files.sort();
}

// Nearest package root for a path inside node_modules: the segments up to the
// innermost node_modules entry (plus the scope segment), so nested copies
// resolve to their own package.
function pkgRootFromPath(file) {
  const parts = path.resolve(file).split(path.sep);
  let idx = -1;
  for (let i = 0; i < parts.length; i++) if (parts[i] === "node_modules") idx = i;
  if (idx < 0 || idx + 1 >= parts.length) return null;
  let end = idx + 2;
  if (parts[idx + 1].startsWith("@")) end = idx + 3;
  return parts.slice(0, end).join(path.sep);
}

function readPkg(root) {
  const file = path.join(root, "package.json");
  if (!fs.existsSync(file)) die("no package.json for " + root);
  const pj = JSON.parse(fs.readFileSync(file, "utf8"));
  let license = "";
  if (typeof pj.license === "string") license = pj.license;
  else if (pj.license && typeof pj.license.type === "string") license = pj.license.type;
  if (!pj.name || !pj.version) die("package.json without name or version at " + root);
  return { name: pj.name, version: pj.version, license, root };
}

// Minimal SPDX-expression shape check (ids, AND/OR/WITH, parentheses).
function looksLikeSpdx(expr) {
  if (!expr || expr === "UNKNOWN" || expr === "SEE LICENSE IN LICENSE") return false;
  const tokens = expr.match(/\(|\)|[A-Za-z0-9.+-]+(?:-\d)?|[A-Za-z0-9.+-]+/g);
  if (!tokens) return false;
  return /^[A-Za-z0-9.+()\s-]+$/.test(expr) && tokens.length > 0;
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function sortedComponents(comps) {
  return [...comps.values()]
    .map((c) => ({ name: c.name, version: c.version, license: c.license, root: c.root, via: [...c.via].sort() }))
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : a.version < b.version ? -1 : a.version > b.version ? 1 : 0));
}

function buildInventory() {
  if (!fs.existsSync(assets)) die("no dist/assets");
  const maps = fs.readdirSync(assets).filter((f) => f.endsWith(".js.map")).sort();
  if (maps.length === 0) die("no dist/assets/*.js.map: build with --sourcemap hidden");
  const jsFiles = fs.readdirSync(assets).filter((f) => f.endsWith(".js"));
  const cssFiles = fs.readdirSync(assets).filter((f) => f.endsWith(".css"));
  if (cssFiles.length !== 1) die("expected exactly one dist/assets/*.css, got " + cssFiles.length);
  if (jsFiles.length === 0) die("no dist/assets/*.js");
  const builtCss = fs.readFileSync(path.join(assets, cssFiles[0]), "utf8");

  const comps = new Map();
  const add = (pkg, via) => {
    const key = pkg.name + "@" + pkg.version;
    if (!comps.has(key)) comps.set(key, { ...pkg, via: new Set() });
    comps.get(key).via.add(via);
  };

  // JS: every source-map source that resolves into node_modules.
  for (const m of maps) {
    const mapPath = path.join(assets, m);
    const map = JSON.parse(fs.readFileSync(mapPath, "utf8"));
    for (const src of map.sources || []) {
      const abs = path.resolve(path.dirname(mapPath), src);
      const root = pkgRootFromPath(abs);
      if (!root) continue;
      add(readPkg(root), "js");
    }
  }

  // CSS: bare @import specifiers in ui/src.
  const importRe = /@import\s+(?:url\()?\s*["']([^"']+)["']/g;
  const cssImports = [];
  for (const f of walk(path.join(ui, "src"))) {
    if (!f.endsWith(".css")) continue;
    const text = fs.readFileSync(f, "utf8");
    for (const match of text.matchAll(importRe)) {
      const spec = match[1];
      if (spec.startsWith(".") || spec.startsWith("/") || /^[a-z]+:/i.test(spec)) continue;
      const name = spec.startsWith("@") ? spec.split("/").slice(0, 2).join("/") : spec.split("/")[0];
      const pkg = readPkg(path.join(ui, "node_modules", name));
      add(pkg, "css");
      cssImports.push({ spec, pkg });
    }
  }

  const list = sortedComponents(comps);
  if (list.length === 0) die("empty inventory");

  // CSS presence checks: the built CSS must carry each CSS component's marker.
  const seenCss = new Set();
  for (const { pkg } of cssImports) {
    const key = pkg.name + "@" + pkg.version;
    if (seenCss.has(key)) continue;
    seenCss.add(key);
    if (pkg.name === "tailwindcss") {
      if (!builtCss.startsWith("/*! tailwindcss v" + pkg.version)) die("built CSS lacks tailwindcss v" + pkg.version + " banner");
      continue;
    }
    const markers = new Set();
    for (const f of walk(pkg.root, true)) {
      if (!f.endsWith(".css")) continue;
      const text = fs.readFileSync(f, "utf8");
      for (const m of text.matchAll(/(--[A-Za-z][\w-]*)\s*:/g)) markers.add(m[1]);
      for (const m of text.matchAll(/@property\s+(--[\w-]+)/g)) markers.add(m[1]);
      for (const m of text.matchAll(/font-family:\s*["']?([^;,"'}]+)/g)) markers.add(m[1].trim());
    }
    const hit = [...markers].some((mk) => mk.length > 2 && builtCss.includes(mk));
    if (!hit) die("no CSS marker of " + pkg.name + "@" + pkg.version + " found in the built CSS");
  }

  // Attribution: every shipped file other than index.html, *.js, *.css and *.map
  // must be byte-identical to a file inside an inventoried package or ui/public.
  const hashes = new Set();
  for (const c of list) {
    for (const f of walk(c.root, true)) hashes.add(sha256(f));
  }
  for (const f of walk(path.join(ui, "public"))) hashes.add(sha256(f));
  for (const f of walk(dist)) {
    const rel = path.relative(dist, f);
    if (rel === "index.html" || /\.(js|css|map)$/.test(rel)) continue;
    if (!hashes.has(sha256(f))) die("unattributed shipped file: " + rel);
  }

  return list;
}

if (mode === "inventory") {
  const list = buildInventory();
  fs.mkdirSync(out, { recursive: true });
  const inv = list.map(({ name, version, license, via }) => ({ name, version, license, via }));
  fs.writeFileSync(path.join(out, "ui-inventory.json"), JSON.stringify(inv, null, 2) + "\n");
  for (const c of list) {
    const dest = path.join(out, "sbom-root", "node_modules", c.name);
    fs.mkdirSync(dest, { recursive: true });
    fs.copyFileSync(path.join(c.root, "package.json"), path.join(dest, "package.json"));
  }
  console.log("ui-inventory: " + list.length + " components");
} else if (mode === "check-sbom") {
  const spdxFile = extra;
  if (!spdxFile) die("check-sbom needs the spdx file");
  const inv = JSON.parse(fs.readFileSync(path.join(out, "ui-inventory.json"), "utf8"));
  const want = inv.map((c) => c.name + "@" + c.version).sort();
  const spdx = JSON.parse(fs.readFileSync(spdxFile, "utf8"));
  const got = [];
  for (const p of spdx.packages || []) {
    for (const r of p.externalRefs || []) {
      if (r.referenceType !== "purl" || !r.referenceLocator.startsWith("pkg:npm/")) continue;
      const body = decodeURIComponent(r.referenceLocator.slice("pkg:npm/".length)).split("?")[0];
      got.push(body);
    }
  }
  got.sort();
  const missing = want.filter((w) => !got.includes(w));
  const extraRows = got.filter((g) => !want.includes(g));
  if (missing.length || extraRows.length) {
    die("SBOM mismatch; missing=" + JSON.stringify(missing) + " extra=" + JSON.stringify(extraRows));
  }
  console.log("ui-inventory: SBOM rows equal inventory (" + got.length + ")");
} else if (mode === "notices") {
  const inv = JSON.parse(fs.readFileSync(path.join(out, "ui-inventory.json"), "utf8"));
  for (const c of inv) {
    const root = path.join(ui, "node_modules", ...c.name.split("/"));
    const dest = path.join(out, "npm", c.name + "@" + c.version);
    if (!looksLikeSpdx(c.license)) die("no usable declared license for " + c.name + "@" + c.version + ": '" + c.license + "'");
    const files = fs.readdirSync(root, { withFileTypes: true }).filter((e) => e.isFile() && /^(licen[cs]e|copying|notice)/i.test(e.name));
    if (files.length === 0) die("no license file at the root of " + c.name + "@" + c.version);
    fs.mkdirSync(dest, { recursive: true });
    for (const f of files) fs.copyFileSync(path.join(root, f.name), path.join(dest, f.name));
  }
  console.log("ui-inventory: notices written for " + inv.length + " components");
} else {
  die("unknown mode " + mode);
}
