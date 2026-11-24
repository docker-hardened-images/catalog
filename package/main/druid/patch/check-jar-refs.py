#!/usr/bin/env python3
"""Fail when a patched jar has class or member references the original did not.

Usage: check-jar-refs.py --prefix PKG/ [--prefix ...] [--with CALLER.jar ...]
                         ORIGINAL.jar PATCHED.jar
       check-jar-refs.py --self-test

--with adds jars whose classes call into the patched jar (hadoop-client-api for
hadoop-client-runtime, iceberg-core for iceberg-bundled-guava); their references
are checked against the patched jar the same way.

Every field and method reference in every class is resolved against the classes
in the same jar, walking superclasses and interfaces. A reference whose owner,
or one of the owner's ancestors, lives outside the jar is treated as resolved
(the JDK or Druid's classpath supplies it). A class reference is reported as
missing only when its name starts with one of the --prefix values, the relocated
namespaces this jar owns, and its package exists in one of the two jars. Pre-existing dangling references in the original jar
(optional dependencies upstream never bundled) are ignored: only references that
the swap introduced fail the check.
"""
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def parse_class(data):
    if data[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError("not a class file")
    pos = 8
    (count,) = struct.unpack_from(">H", data, pos)
    pos += 2
    cp = [None] * count
    i = 1
    while i < count:
        tag = data[pos]
        pos += 1
        if tag == 1:
            (n,) = struct.unpack_from(">H", data, pos)
            cp[i] = data[pos + 2:pos + 2 + n].decode("utf-8", "replace")
            pos += 2 + n
        elif tag in (3, 4):
            pos += 4
        elif tag in (5, 6):
            pos += 8
            i += 1
        elif tag in (7, 8, 16, 19, 20):
            cp[i] = (tag, struct.unpack_from(">H", data, pos)[0])
            pos += 2
        elif tag in (9, 10, 11, 12, 17, 18):
            cp[i] = (tag,) + struct.unpack_from(">HH", data, pos)
            pos += 4
        elif tag == 15:
            pos += 3
        else:
            raise ValueError(f"unknown constant pool tag {tag}")
        i += 1

    def cls(idx):
        return cp[cp[idx][1]] if idx else None

    _, this, sup, nif = struct.unpack_from(">HHHH", data, pos)
    pos += 8
    interfaces = [cls(struct.unpack_from(">H", data, pos + 2 * k)[0]) for k in range(nif)]
    pos += 2 * nif

    def members(pos):
        (n,) = struct.unpack_from(">H", data, pos)
        pos += 2
        out = set()
        for _ in range(n):
            _, name, desc, nattr = struct.unpack_from(">HHHH", data, pos)
            pos += 8
            out.add((cp[name], cp[desc]))
            for _ in range(nattr):
                (alen,) = struct.unpack_from(">I", data, pos + 2)
                pos += 6 + alen
        return out, pos

    fields, pos = members(pos)
    methods, pos = members(pos)

    classrefs, memberrefs = set(), set()
    for e in cp:
        if not isinstance(e, tuple):
            continue
        if e[0] == 7:
            name = cp[e[1]].lstrip("[")
            if name.startswith("L") and name.endswith(";"):
                name = name[1:-1]
            if len(name) > 1:
                classrefs.add(name)
        elif e[0] in (9, 10, 11):
            owner = cp[cp[e[1]][1]].lstrip("[")
            if owner.startswith("L"):
                continue
            nt = cp[e[2]]
            kind = "field" if e[0] == 9 else "method"
            memberrefs.add((owner, kind, cp[nt[1]], cp[nt[2]]))
    return cls(this), {"super": cls(sup), "interfaces": interfaces,
                       "field": fields, "method": methods}, classrefs, memberrefs


def load(*jars):
    index, refs = {}, []
    for jar in jars:
        load_into(jar, index, refs)
    return index, refs


def load_into(jar, index, refs):
    with zipfile.ZipFile(jar) as z:
        for info in z.infolist():
            if not info.filename.endswith(".class") or info.filename.startswith("META-INF/"):
                continue
            if info.filename.endswith("module-info.class"):
                continue
            name, meta, classrefs, memberrefs = parse_class(z.read(info))
            index.setdefault(name, meta)
            refs.append((name, classrefs, memberrefs))


# Every class reaches java/lang/Object, so it cannot count as "outside the jar,
# assume resolved" like other external ancestors do.
OBJECT_METHODS = {
    ("<init>", "()V"), ("getClass", "()Ljava/lang/Class;"), ("hashCode", "()I"),
    ("equals", "(Ljava/lang/Object;)Z"), ("clone", "()Ljava/lang/Object;"),
    ("toString", "()Ljava/lang/String;"), ("notify", "()V"), ("notifyAll", "()V"),
    ("wait", "()V"), ("wait", "(J)V"), ("wait", "(JI)V"), ("finalize", "()V"),
}


def resolves(index, owner, kind, name, desc, seen=None):
    seen = seen if seen is not None else set()
    if owner in seen:
        return False
    seen.add(owner)
    if owner == "java/lang/Object":
        return kind == "method" and (name, desc) in OBJECT_METHODS
    meta = index.get(owner)
    if meta is None:
        return True
    if (name, desc) in meta[kind]:
        return True
    parents = [meta["super"]] + meta["interfaces"]
    return any(p and resolves(index, p, kind, name, desc, seen) for p in parents)


def package(name):
    return name.rpartition("/")[0]


def unresolved(loaded, prefixes, packages):
    index, refs = loaded
    out = set()
    for src, classrefs, memberrefs in refs:
        for c in classrefs:
            if c not in index and c.startswith(prefixes) and package(c) in packages:
                out.add((src, f"class {c}"))
        for owner, kind, name, desc in memberrefs:
            if owner.startswith(prefixes) and owner not in index:
                continue
            if not resolves(index, owner, kind, name, desc):
                out.add((src, f"{kind} {owner}.{name}{desc}"))
    return {r for _, r in out}, out, len(index)


def check(original, patched, prefixes, callers=()):
    old, new_jar = load(original, *callers), load(patched, *callers)
    # A missing class in a package neither jar ships is an optional external
    # dependency (YAML support, zstd, ...) that upstream never bundled either.
    packages = {package(n) for n in old[0]} | {package(n) for n in new_jar[0]}
    before, _, _ = unresolved(old, prefixes, packages)
    after, detail, n = unresolved(new_jar, prefixes, packages)
    new = after - before
    for src, ref in sorted(detail):
        if ref in new:
            print(f"unresolved: {src} -> {ref}", file=sys.stderr)
    print(f"{patched}: {n} classes, {len(after)} unresolved references, {len(new)} new")
    return 1 if new else 0


def self_test():
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)

        def jar(name, sources, extra=None):
            src, out = t / name / "src", t / name / "out"
            for rel, body in sources.items():
                (src / rel).parent.mkdir(parents=True, exist_ok=True)
                (src / rel).write_text(body)
            out.mkdir(parents=True)
            if sources:
                subprocess.run(["javac", "-d", str(out)] + [str(src / r) for r in sources], check=True)
            path = t / f"{name}.jar"
            with zipfile.ZipFile(path, "w") as z:
                for root in [out] + ([extra] if extra else []):
                    for f in root.rglob("*.class"):
                        z.write(f, f.relative_to(root).as_posix())
            return path

        lib = "package shaded.lib; public class Lib { public int m(int x) { return x; } }"
        caller = "package app; public class Caller { int f() { return new shaded.lib.Lib().m(1); } }"
        good = jar("good", {"app/Caller.java": caller, "shaded/lib/Lib.java": lib})
        app = t / "app-only"
        (app / "app").mkdir(parents=True)
        (app / "app" / "Caller.class").write_bytes((t / "good" / "out" / "app" / "Caller.class").read_bytes())
        same = jar("same", {"shaded/lib/Base.java": "package shaded.lib; public class Base { public int m(int x) { return x; } }",
                            "shaded/lib/Lib.java": "package shaded.lib; public class Lib extends Base { }"}, app)
        bad = jar("bad", {"shaded/lib/Lib.java": "package shaded.lib; public class Lib { public long m(long x) { return x; } }"}, app)
        gone = jar("gone", {}, app)
        optional = jar("optional", {
            "shaded/lib/Lib.java": lib,
            "shaded/lib/Yaml.java": "package shaded.lib; public class Yaml { Object y() { return new shaded.opt.Parser(); } }",
            "shaded/opt/Parser.java": "package shaded.opt; public class Parser { }"}, app)
        with zipfile.ZipFile(optional) as z:
            kept = {n: z.read(n) for n in z.namelist() if not n.startswith("shaded/opt/")}
        with zipfile.ZipFile(optional, "w") as z:
            for n, b in kept.items():
                z.writestr(n, b)
        prefixes = ("shaded/",)
        callers = t / "callers.jar"
        with zipfile.ZipFile(callers, "w") as z:
            z.write(app / "app" / "Caller.class", "app/Caller.class")
        lib_good = jar("lib-good", {"shaded/lib/Lib.java": lib})
        lib_bad = jar("lib-bad", {"shaded/lib/Lib.java": "package shaded.lib; public class Lib { }"})
        assert check(lib_good, lib_bad, prefixes, [callers]) == 1, "caller jar references must be checked"
        assert check(lib_good, lib_good, prefixes, [callers]) == 0, "unchanged jar must pass with callers"
        assert check(good, optional, prefixes) == 0, "optional external package must not fail"
        assert check(good, same, prefixes) == 0, "inherited member must resolve"
        assert check(good, bad, prefixes) == 1, "changed descriptor must fail"
        assert check(good, gone, prefixes) == 1, "removed class must fail"
        assert check(bad, bad, prefixes) == 0, "pre-existing gaps must not fail"
    print("self-test passed")
    return 0


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    prefixes, callers, args = [], [], list(argv)
    while len(args) > 2 and args[0] in ("--prefix", "--with"):
        (prefixes if args[0] == "--prefix" else callers).append(args[1])
        args = args[2:]
    if len(args) != 2 or not prefixes:
        print(__doc__, file=sys.stderr)
        return 2
    return check(args[0], args[1], tuple(prefixes), callers)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
