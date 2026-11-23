#!/usr/bin/env python3
"""Write an SPDX 2.3 document for third-party code inlined into Open Liberty bundles.

Open Liberty repackages third-party libraries into its own OSGi bundles. The
pom.properties in every bundle names a groupId=dev coordinate that matches no
real package, so a jar scanner cannot see what is inside. This script maps the
classes in each shipped jar back to upstream Maven (and npm) coordinates and
fails when it cannot:

  * a third-party Java package that matches no row of packages.tsv fails;
  * a matched package needs a version from the bundle's embedded pom.xml (plus
    bundle-inputs.tsv), or from its bnd project in the pinned source checkout,
    or it must be compiled from Liberty's own source tree; otherwise it fails;
  * a coordinate that is not published as named needs a coordinates.tsv row;
  * every emitted row needs a license from license-overrides.tsv, its npm
    lockfile, or wlp/NOTICES, and every NOTICES component needs a shipped row,
    an automatic explanation, or a notices-allowlist.tsv row;
  * a table row that matches nothing fails, so the tables cannot go stale.

Only the Python standard library is used.
"""

import argparse
import collections
import io
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

POM_NS = {"m": "http://maven.apache.org/POM/4.0.0"}
OWN_PREFIXES = ("com.ibm.", "io.openliberty.", "wlp.")
# IBM open-source libraries released on their own (NOTICES lists them); their
# packages sit under an OWN_PREFIXES root but are third-party to Open Liberty.
IBM_OPEN_SOURCE = ("com.ibm.asyncutil",)


class Failure(Exception):
    pass


def read_tsv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.split("\t")
            rows.append((n, cols))
    return rows


# ---------------------------------------------------------------------------
# Tables


class Tables:
    def __init__(self, d):
        self.packages = {}
        for n, cols in read_tsv(os.path.join(d, "packages.tsv")):
            if len(cols) != 2:
                raise Failure(f"packages.tsv:{n}: want 2 columns")
            self.packages[cols[0]] = set(cols[1].split(","))
        self.coords = []
        for n, cols in read_tsv(os.path.join(d, "coordinates.tsv")):
            if len(cols) != 4:
                raise Failure(f"coordinates.tsv:{n}: want 4 columns")
            ga, vre, action, why = cols
            self.coords.append((n, ga, re.compile(vre), action, why))
        self.families = {}
        for n, cols in read_tsv(os.path.join(d, "license-families.tsv")):
            if len(cols) != 2:
                raise Failure(f"license-families.tsv:{n}: want 2 columns")
            self.families[cols[0]] = cols[1]
        self.overrides = []
        for n, cols in read_tsv(os.path.join(d, "license-overrides.tsv")):
            if len(cols) != 4:
                raise Failure(f"license-overrides.tsv:{n}: want 4 columns")
            name, vre, spdx, why = cols
            self.overrides.append((n, name, re.compile(vre), spdx, why))
        self.allow = {}
        for n, cols in read_tsv(os.path.join(d, "notices-allowlist.tsv")):
            if len(cols) != 2:
                raise Failure(f"notices-allowlist.tsv:{n}: want 2 columns")
            self.allow[norm(cols[0])] = cols[1]
        self.resources = []
        for n, cols in read_tsv(os.path.join(d, "resources.tsv")):
            if len(cols) != 2:
                raise Failure(f"resources.tsv:{n}: want 2 columns")
            self.resources.append((re.compile(cols[0]), cols[1]))
        self.inputs = collections.defaultdict(list)
        for n, cols in read_tsv(os.path.join(d, "bundle-inputs.tsv")):
            if len(cols) != 3 or cols[1].count(":") != 2:
                raise Failure(f"bundle-inputs.tsv:{n}: want bsn, g:a:v, evidence")
            self.inputs[cols[0]].append((n, *cols[1].split(":")))
        self.used_inputs = set()
        self.kept = set()
        self.used_coords = set()
        self.used_overrides = set()
        self.used_allow = set()

    def lookup(self, pkg):
        """Longest-prefix match. 'a.b!' matches only package a.b."""
        if pkg + "!" in self.packages:
            return self.packages[pkg + "!"]
        parts = pkg.split(".")
        for i in range(len(parts), 0, -1):
            pre = ".".join(parts[:i])
            if pre in self.packages:
                return self.packages[pre]
        return None

    def normalize(self, g, a, v, strict=True):
        """Return (g, a, v) for a real coordinate, or None for IBM-internal ones.
        Bundle poms are strict; bnd build inputs only supply versions for public
        candidates, so an unknown IBM coordinate there is skipped."""
        ga = f"{g}:{a}"
        for n, cga, vre, action, _why in self.coords:
            if cga == ga and vre.fullmatch(v):
                self.used_coords.add(n)
                if action == "internal":
                    return None
                if action == "public":
                    return (g, a, v)
                if action == "keep":
                    self.kept.add(f"{g}:{a}:{v}")
                    return (g, a, v)
                if action.startswith("version:"):
                    return (g, a, vre.sub(action[len("version:"):], v))
                if action.startswith("as:"):
                    ng, na, nv = action[len("as:"):].split(":")
                    return (ng, na, vre.sub(nv, v))
                raise Failure(f"coordinates.tsv:{n}: unknown action {action}")
        if looks_internal(g, v):
            if not strict:
                return None
            raise Failure(
                f"{ga}:{v} looks like an IBM build coordinate and has no coordinates.tsv row"
            )
        return (g, a, v)


def looks_internal(g, v):
    if g.startswith(("com.ibm.", "io.openliberty.", "dev")) or g == "dev":
        return True
    return bool(re.search(r"(?i)(ibm|was-|\.was|_[0-9a-f]{10})", v))


# ---------------------------------------------------------------------------
# Jars


def manifest(z):
    try:
        raw = z.read("META-INF/MANIFEST.MF").decode("utf-8", "replace")
    except KeyError:
        return {}
    raw = raw.replace("\r\n", "\n").replace("\n ", "")
    out = {}
    for line in raw.split("\n"):
        if ": " in line:
            k, v = line.split(": ", 1)
            out[k] = v
    return out


def class_packages(names):
    pk = set()
    for n in names:
        if n.endswith(".class") and "/" in n and not n.startswith(("META-INF/", "OSGI-INF/")):
            pk.add(n.rsplit("/", 1)[0].replace("/", "."))
    return pk


def pom_deps(z, names):
    deps = []
    for n in names:
        if n.startswith("META-INF/maven/") and n.endswith("/pom.xml"):
            root = ET.fromstring(z.read(n))
            for d in root.findall("m:dependencies/m:dependency", POM_NS):
                g = d.findtext("m:groupId", namespaces=POM_NS)
                a = d.findtext("m:artifactId", namespaces=POM_NS)
                v = d.findtext("m:version", namespaces=POM_NS)
                if g and a and v:
                    deps.append((g, a, v))
    return deps


class Jar:
    def __init__(self, path, rel):
        self.rel = rel
        with zipfile.ZipFile(path) as z:
            names = z.namelist()
            self.manifest = manifest(z)
            self.deps = pom_deps(z, names)
            self.packages = class_packages(names)
            self.resources = [n for n in names if not n.endswith("/")]
            self.lockfiles = {}
            for n in names:
                if n.endswith("package-lock.json"):
                    self.lockfiles[n] = json.loads(z.read(n))
            for n in names:
                if n.endswith(".jar"):
                    with zipfile.ZipFile(io.BytesIO(z.read(n))) as inner:
                        self.packages |= class_packages(inner.namelist())
        bsn = self.manifest.get("Bundle-SymbolicName", "")
        self.bsn = bsn.split(";")[0].strip()

    def third_party(self):
        return sorted(
            p for p in self.packages if not p.startswith(OWN_PREFIXES) or p.startswith(IBM_OPEN_SOURCE)
        )


# ---------------------------------------------------------------------------
# bnd projects in the source checkout


BND_LINE = re.compile(r"^([-\w.]+)\s*[:=]\s*(.*)$")


def parse_bnd(text):
    props = {}
    lines = text.replace("\r\n", "\n").split("\n")
    buf = ""
    for line in lines:
        s = line.strip()
        if not buf and (not s or s.startswith("#")):
            continue
        if s.endswith("\\"):
            buf += s[:-1] + " "
            continue
        buf += s
        m = BND_LINE.match(buf.strip())
        if m:
            props[m.group(1)] = m.group(2).strip()
        buf = ""
    return props


class Source:
    def __init__(self, root):
        self.dev = os.path.join(root, "dev")
        if not os.path.isdir(self.dev):
            raise Failure(f"{self.dev} is not a directory")
        self.cnf = {}
        for name in ("build.bnd", "bnd.bnd"):
            p = os.path.join(self.dev, "cnf", name)
            if os.path.exists(p):
                with open(p, encoding="utf-8", errors="replace") as f:
                    self.cnf.update(parse_bnd(f.read()))
        self.projects = {}  # bsn -> list of (projectdir, props)
        for proj in os.listdir(self.dev):
            pdir = os.path.join(self.dev, proj)
            main = os.path.join(pdir, "bnd.bnd")
            if not os.path.isfile(main):
                continue
            with open(main, encoding="utf-8", errors="replace") as f:
                base = parse_bnd(f.read())
            subs = []
            if "-sub" in base:
                for fn in sorted(os.listdir(pdir)):
                    if fn.endswith(".bnd") and fn != "bnd.bnd":
                        with open(os.path.join(pdir, fn), encoding="utf-8", errors="replace") as f:
                            sp = dict(base)
                            sp.update(parse_bnd(f.read()))
                            subs.append(sp)
            for props in subs or [base]:
                bsn = props.get("Bundle-SymbolicName", proj).split(";")[0].strip()
                bsn = self.expand(bsn, props)
                self.projects.setdefault(bsn, []).append((proj, props))
        self.src_dirs = set()
        for proj in os.listdir(self.dev):
            s = os.path.join(self.dev, proj, "src")
            if os.path.isdir(s):
                self.src_dirs.add(s)

    def expand(self, value, props, depth=0):
        if depth > 20:
            return value

        def rep(m):
            body = m.group(1)
            if ";" in body:
                return "${" + self.expand(body, props, depth + 1) + "}"
            if body in props:
                return self.expand(props[body], props, depth + 1)
            if body in self.cnf:
                return self.expand(self.cnf[body], props, depth + 1)
            return m.group(0)

        prev = None
        while prev != value:
            prev = value
            value = re.sub(r"\$\{([^${}]+)\}", rep, value)
        return value

    def coordinates(self, bsn, seen=None):
        """Map g:a -> set(versions) for Maven inputs the bnd project names,
        following Liberty bundles named on -buildpath."""
        seen = seen if seen is not None else set()
        if bsn in seen:
            return {}, []
        seen.add(bsn)
        out = collections.defaultdict(set)
        bundles = []
        for _proj, props in self.projects.get(bsn, []):
            text = " ".join(f"{k}: {v}" for k, v in props.items())
            text = self.expand(text, props)
            for m in re.finditer(r"\$\{repo;([^;:}\s]+):([^;:}\s]+)(?::[^;}\s]*)?;([^;}\s]+)", text):
                g, a, v = m.groups()
                if re.fullmatch(r"[0-9][\w.\-]*", v):
                    out[f"{g}:{a}"].add(v)
            for key in ("-buildpath", "-testpath"):
                if key == "-testpath":
                    continue
                raw = self.expand(props.get(key, ""), props)
                for entry in split_bnd_list(raw):
                    fields = [x.strip() for x in entry.split(";")]
                    name = fields[0]
                    attrs = dict(
                        x.split("=", 1) for x in fields[1:] if "=" in x
                    )
                    ver = attrs.get("version", "").strip('"')
                    if ":" in name:
                        g, a = name.split(":")[:2]
                        if re.fullmatch(r"[0-9][\w.\-]*", ver):
                            out[f"{g}:{a}"].add(ver)
                    elif name and not name.startswith(("..", "/")):
                        bundles.append(name)
        return out, bundles

    def in_tree(self, pkg):
        """A package is Liberty's own fork when its .java files are in the tree;
        a directory holding only subpackages (io/grpc for io.grpc.servlet) is not."""
        rel = pkg.replace(".", "/")
        for s in self.src_dirs:
            d = os.path.join(s, rel)
            if os.path.isdir(d) and any(fn.endswith(".java") for fn in os.listdir(d)):
                return True
        return False


def split_bnd_list(raw):
    out, depth, cur = [], 0, ""
    for ch in raw:
        if ch == '"':
            depth ^= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return [x for x in out if x]


# ---------------------------------------------------------------------------
# NOTICES


def parse_notices(path, tables):
    """Return {component-name: set(SPDX ids)} from wlp/NOTICES."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    sections = re.split(r"\n\+{20,}\n", text)
    names = collections.defaultdict(set)
    seen_families = set()
    for sec in sections:
        m = re.search(
            r"The Program includes some or all of the following that IBM obtained\s+under the (.+?):\n",
            sec,
        )
        if not m:
            continue
        family = re.sub(r"\s+", " ", m.group(1)).strip()
        if family not in tables.families:
            raise Failure(f"NOTICES family {family!r} has no license-families.tsv row")
        seen_families.add(family)
        spdx = tables.families[family]
        body = sec[m.end():]
        listing = re.split(r"\n\s*\n", body.lstrip("\n"), maxsplit=1)[0]
        for name in listing_names(listing):
            names[norm(name)].add(spdx)
    if not names:
        raise Failure("parsed no components from NOTICES")
    return names, seen_families


def norm(name):
    return re.sub(r"[/_\s]+", "-", name.strip().lower())


def listing_names(listing):
    """NOTICES listings are wrapped comma lists, one item per line followed by
    "(Copyright ...)" notes, or "Display Name [artifactId]" items whose display
    names may contain commas. Bracketed artifactIds win over display names."""
    prev = None
    while prev != listing:
        prev, listing = listing, re.sub(r"\([^()]*\)", "", listing)
    out = []
    for line in listing.split("\n"):
        # 26.0.0.11 truncates one note: "asm (Copyright (c) 2000-2011 INRIA\".
        line = re.sub(r"\(.*$", "", line)
        if ")" in line:
            raise Failure(f"unbalanced parentheses in NOTICES line: {line[:200]!r}")
        line = re.sub(r"https?://\S+", "", line).strip()
        pending = []
        for piece in line.split(","):
            piece = piece.strip()
            m = re.search(r"\[([^\]]+)\]", piece)
            if m:
                # Unbracketed pieces before it were the display name's own commas.
                pending = []
                out.append(re.sub(r"-[0-9][\w.\-]*\.tgz$", "", m.group(1).strip()))
            elif piece:
                pending.append(piece if " " in piece else piece.split(":")[-1])
        out.extend(pending)
    return out


def unversioned(name):
    """apidom-ns-openapi-3-1 -> apidom-ns-openapi, as NOTICES lists it."""
    return re.sub(r"(-[0-9][0-9a-z]*)+$", "", norm(name))


# ---------------------------------------------------------------------------
# Main resolution


class Result:
    def __init__(self):
        self.maven = collections.defaultdict(set)  # (g,a,v) -> jars
        self.npm = collections.defaultdict(set)  # (name, v) -> jars
        self.npm_license = {}  # (name, v) -> lockfile license
        self.forks = collections.defaultdict(set)  # pkg -> jars
        self.internal = collections.defaultdict(set)  # g:a:v -> jars
        self.declared = collections.defaultdict(set)  # g:a:v named by a pom -> jars
        self.errors = []


def resolve(wlp, source, tables):
    res = Result()
    jars = {}
    for dirpath, _dirs, files in os.walk(wlp):
        for fn in files:
            if fn.endswith(".jar"):
                p = os.path.join(dirpath, fn)
                jars[os.path.relpath(p, wlp)] = Jar(p, os.path.relpath(p, wlp))
    by_bsn = collections.defaultdict(list)
    for j in jars.values():
        if j.bsn:
            by_bsn[j.bsn].append(j)

    def own_coords(j, inputs=None):
        real, internal = collections.defaultdict(set), set()
        for g, a, v in j.deps:
            n = tables.normalize(g, a, v)
            if n is None:
                internal.add(f"{g}:{a}")
                res.internal[f"{g}:{a}:{v}"].add(j.rel)
            else:
                real[f"{n[0]}:{n[1]}"].add(n[2])
                res.declared[f"{n[0]}:{n[1]}:{n[2]}"].add(j.rel)
        if inputs is not None:
            for row, g, a, v in tables.inputs.get(j.bsn, []):
                n = tables.normalize(g, a, v)
                if n is None:
                    raise Failure(f"bundle-inputs.tsv:{row}: {g}:{a}:{v} normalizes to an internal coordinate")
                real[f"{n[0]}:{n[1]}"].add(n[2])
                inputs[f"{n[0]}:{n[1]}"] = row
        return real, internal

    def bnd_coords(bsn, seen):
        out, bundles = source.coordinates(bsn, seen)
        out = {k: set(v) for k, v in out.items()}
        for b in bundles:
            for sj in by_bsn.get(b, []):
                r, _ = own_coords(sj)
                for k, v in r.items():
                    out.setdefault(k, set()).update(v)
            sub = bnd_coords(b, seen)
            for k, v in sub.items():
                out.setdefault(k, set()).update(v)
        return out

    for rel in sorted(jars):
        j = jars[rel]
        inputs = {}
        real, internal = own_coords(j, inputs)
        bnd = None
        for pkg in j.third_party():
            cands = tables.lookup(pkg) or set()
            hit = cands & set(real)
            if hit:
                for ga in hit:
                    if ga in inputs:
                        tables.used_inputs.add(inputs[ga])
                    for v in real[ga]:
                        g, a = ga.split(":")
                        res.maven[(g, a, v)].add(rel)
                continue
            kept = [ga for ga in real for v in real[ga] if f"{ga}:{v}" in tables.kept]
            if kept:
                # A fork with no public artifact (coordinates.tsv "keep") owns the
                # classes no public coordinate explains.
                for ga in kept:
                    g, a = ga.split(":")
                    for v in real[ga]:
                        res.maven[(g, a, v)].add(rel)
                continue
            if internal:
                # The bundle pom names an IBM build (coordinates.tsv "internal");
                # classes no public coordinate explains come from it.
                continue
            if not cands:
                if source.in_tree(pkg):
                    res.forks[pkg].add(rel)
                    continue
                res.errors.append(f"{rel}: third-party package {pkg} matches no packages.tsv row")
                continue
            if bnd is None:
                bnd = bnd_coords(j.bsn, set()) if j.bsn else {}
                normalized = collections.defaultdict(set)
                for ga, vs in bnd.items():
                    g, a = ga.split(":")
                    for v in vs:
                        n = tables.normalize(g, a, v, strict=False)
                        if n:
                            normalized[f"{n[0]}:{n[1]}"].add(n[2])
                bnd = normalized
            hit = cands & set(bnd)
            if hit:
                for ga in hit:
                    for v in bnd[ga]:
                        g, a = ga.split(":")
                        res.maven[(g, a, v)].add(rel)
                continue
            if source.in_tree(pkg):
                res.forks[pkg].add(rel)
                continue
            res.errors.append(
                f"{rel}: no version for {pkg} (candidates {','.join(sorted(cands))}; bundle {j.bsn or '-'})"
            )
        for path_re, ga in tables.resources:
            if any(path_re.search(r) for r in j.resources):
                if ga not in real:
                    res.errors.append(f"{rel}: resource rule for {ga} but the bundle pom does not name it")
                    continue
                g, a = ga.split(":")
                for v in real[ga]:
                    res.maven[(g, a, v)].add(rel)
        for name, lock in j.lockfiles.items():
            for key, lic in lock_packages(lock).items():
                res.npm[key].add(f"{rel}!{name}")
                if lic:
                    res.npm_license[key] = lic
        if j.bsn:
            for proj, _props in source.projects.get(j.bsn, []):
                lp = os.path.join(source.dev, proj, "package-lock.json")
                if os.path.exists(lp) and not j.lockfiles:
                    with open(lp, encoding="utf-8") as f:
                        for key, lic in lock_packages(json.load(f)).items():
                            res.npm[key].add(f"{rel} (dev/{proj}/package-lock.json)")
                            if lic:
                                res.npm_license[key] = lic
    return res


def lock_packages(lock):
    """(name, version) -> license for runtime packages of an npm lockfile."""
    out = {}
    pk = lock.get("packages")
    if isinstance(pk, dict):
        for path, meta in pk.items():
            if not path or meta.get("dev") or meta.get("devOptional"):
                continue
            name = meta.get("name") or path.split("node_modules/")[-1]
            ver = meta.get("version")
            if name and ver:
                out[(name, ver)] = lock_license(meta.get("license"))
    else:
        def walk(deps):
            for name, meta in (deps or {}).items():
                if meta.get("dev"):
                    continue
                if meta.get("version"):
                    out[(name, meta["version"])] = None
                walk(meta.get("dependencies"))

        walk(lock.get("dependencies"))
    return out


def lock_license(value):
    if isinstance(value, dict):
        value = value.get("type")
    if isinstance(value, list):
        value = " OR ".join(v.get("type", "") if isinstance(v, dict) else str(v) for v in value)
    if not isinstance(value, str) or not value or value.upper().startswith(("SEE ", "UNLICENSED")):
        return None
    return value

def notice_keys(name):
    base = name.split("/")[-1]
    return {norm(name), norm(base), unversioned(base)}


def license_for(name, version, notices, tables, errors, declared=None):
    """Precedence: license-overrides.tsv, the npm lockfile's own license field,
    then NOTICES. NOTICES carries no versions, so a component it lists under
    several families needs an override."""
    for n, oname, vre, spdx, _why in tables.overrides:
        if oname == name and vre.fullmatch(version):
            tables.used_overrides.add(n)
            return spdx
    if declared:
        return declared
    fams = set()
    for k in notice_keys(name):
        fams |= notices.get(k, set())
    if not fams:
        errors.append(f"{name}@{version}: not listed in NOTICES and no license-overrides.tsv row")
        return None
    if len(fams) == 1:
        return next(iter(fams))
    errors.append(
        f"{name}@{version}: NOTICES lists several families ({', '.join(sorted(fams))}); add a license-overrides.tsv row"
    )
    return None


def spdx_id(s):
    return "SPDXRef-" + re.sub(r"[^A-Za-z0-9.\-]", "-", s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wlp", required=True)
    ap.add_argument("--source", required=True)
    ap.add_argument("--tables", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--report", required=True)
    args = ap.parse_args()

    tables = Tables(args.tables)
    source = Source(args.source)
    notices, families = parse_notices(os.path.join(args.wlp, "NOTICES"), tables)
    res = resolve(args.wlp, source, tables)
    errors = list(res.errors)

    packages = []
    covered = set()
    for (g, a, v) in sorted(res.maven):
        lic = license_for(a, v, notices, tables, errors)
        covered.update(notice_keys(a))
        packages.append((f"{g}:{a}", v, f"pkg:maven/{g}/{a}@{v}", lic))
    for (n, v) in sorted(res.npm):
        lic = license_for(n, v, notices, tables, errors, res.npm_license.get((n, v)))
        covered.update(notice_keys(n))
        scope, _, base = n.rpartition("/")
        purl = f"pkg:npm/{scope.replace('@', '%40')}/{base}@{v}" if scope else f"pkg:npm/{n}@{v}"
        packages.append((n, v, purl, lic))

    for c in sorted(res.internal):
        if notice_keys(c.split(":")[1]) & set(notices):
            errors.append(f"{c}: NOTICES lists it as third-party code; make its coordinates.tsv row keep, not internal")
    emitted = {f"{g}:{a}:{v}" for (g, a, v) in res.maven}
    internal_names = {norm(c.split(":")[1]) for c in res.internal}
    declared_only = {norm(c.split(":")[1]) for c in res.declared if c not in emitted}
    explained = {}
    for name in sorted(notices):
        if name in covered:
            continue
        if name in internal_names:
            explained[name] = "IBM build coordinate (coordinates.tsv internal)"
            continue
        if name in declared_only:
            explained[name] = "a bundle pom declares it but no class of it ships"
            continue
        if name in tables.allow:
            tables.used_allow.add(name)
            continue
        errors.append(
            f"NOTICES lists {name!r} but no shipped component row matches it and it is not in notices-allowlist.tsv"
        )

    for n, ga, _vre, _a, _w in tables.coords:
        if n not in tables.used_coords:
            errors.append(f"coordinates.tsv:{n}: {ga} row matched nothing; remove it")
    for bsn, rows in tables.inputs.items():
        for n, g, a, v in rows:
            if n not in tables.used_inputs:
                errors.append(f"bundle-inputs.tsv:{n}: {bsn} {g}:{a}:{v} explains no package; remove it")
    for n, name, _vre, _s, _w in tables.overrides:
        if n not in tables.used_overrides:
            errors.append(f"license-overrides.tsv:{n}: {name} row matched nothing; remove it")
    for name in tables.allow:
        if name not in tables.used_allow:
            errors.append(f"notices-allowlist.tsv: {name} is now covered or gone; remove it")

    with open(args.report, "w", encoding="utf-8") as f:
        f.write(f"maven rows: {len(res.maven)}\nnpm rows: {len(res.npm)}\n")
        f.write(f"NOTICES families: {', '.join(sorted(families))}\n")
        f.write("\n# Packages compiled from Liberty's own source tree (no upstream coordinate)\n")
        for pkg in sorted(res.forks):
            f.write(f"{pkg}\t{','.join(sorted(res.forks[pkg]))}\n")
        f.write("\n# NOTICES names with no SBOM row, explained without notices-allowlist.tsv\n")
        for name in sorted(explained):
            f.write(f"{name}\t{explained[name]}\n")
        f.write("\n# IBM build coordinates named by bundle poms (no public artifact)\n")
        for c in sorted(res.internal):
            f.write(f"{c}\n")
        f.write("\n# Errors\n")
        for e in errors:
            f.write(e + "\n")

    if errors:
        for e in errors:
            print("ERROR:", e, file=sys.stderr)
        print(f"{len(errors)} errors; see {args.report}", file=sys.stderr)
        return 1

    ids = set()
    doc_pkgs, rels = [], []
    for name, v, purl, lic in packages:
        sid = spdx_id(f"{name}-{v}")
        while sid in ids:
            sid += "-x"
        ids.add(sid)
        doc_pkgs.append(
            {
                "SPDXID": sid,
                "name": name,
                "versionInfo": v,
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": False,
                "licenseDeclared": lic,
                "licenseConcluded": "NOASSERTION",
                "externalRefs": [
                    {
                        "referenceCategory": "PACKAGE-MANAGER",
                        "referenceType": "purl",
                        "referenceLocator": purl,
                    }
                ],
            }
        )
        rels.append(
            {
                "spdxElementId": "SPDXRef-DOCUMENT",
                "relationshipType": "DESCRIBES",
                "relatedSpdxElement": sid,
            }
        )
    doc = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"SPDX document for {args.name} {args.version}",
        "documentNamespace": f"https://dhi.docker.com/spdx/{args.name}-{args.version}",
        "creationInfo": {
            "created": "1970-01-01T00:00:00Z",
            "creators": ["Organization: Docker, Inc.", "Tool: package/main/open-liberty/sbom/bundled_sbom.py"],
        },
        "packages": doc_pkgs,
        "relationships": rels,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Failure as e:
        print("ERROR:", e, file=sys.stderr)
        sys.exit(1)
