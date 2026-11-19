"""Inventory the npm packages compiled into locust's web UI bundles.

The shipped dist/ is built without source maps. A second build with
--sourcemap into a scratch directory yields the same code plus maps whose
"sources" name every node_modules file that reached a bundle. This script
checks that the scratch code matches dist/, derives the bundled package set
from the maps, checks it against yarn.lock and the committed list, copies
each package's license and notice files, and writes a package.json tree for
the SBOM step. Any mismatch exits non-zero.
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

MAP_COMMENT = re.compile(rb"\n?//# sourceMappingURL=[^\n<]*")
NOTICE_PREFIXES = ("license", "licence", "notice")


def fail(message):
    sys.exit("webui-inventory: " + message)


def strip_map_comment(data):
    stripped, count = MAP_COMMENT.subn(b"", data)
    if count != 1:
        fail("expected one sourceMappingURL comment, found %d" % count)
    return stripped


def check_same_code(dist, scratch):
    shipped = sorted(dist.glob("assets/src-*.js"))
    if len(shipped) != 1:
        fail("expected one dist/assets/src-*.js, found %d" % len(shipped))
    rebuilt = scratch / "ui" / "assets" / shipped[0].name
    if strip_map_comment(rebuilt.read_bytes()) != shipped[0].read_bytes():
        fail("%s differs from the shipped bundle" % rebuilt)
    report = scratch / "report" / "report.html"
    if strip_map_comment(report.read_bytes()) != (dist / "report.html").read_bytes():
        fail("%s differs from the shipped report.html" % report)
    maps = [rebuilt.with_name(rebuilt.name + ".map")]
    maps += sorted((scratch / "report").glob("report-*.js.map"))
    if len(maps) != 2 or not all(m.is_file() for m in maps):
        fail("expected the ui and report source maps, found %s" % maps)
    return maps


def package_dir(source):
    parts = source.parts
    idx = max(i for i, part in enumerate(parts) if part == "node_modules")
    name = parts[idx + 1]
    end = idx + 2
    if name.startswith("@"):
        end = idx + 3
    return Path(*parts[:end])


def collect(maps, webui):
    found = {}
    for map_path in maps:
        for source in json.loads(map_path.read_text())["sources"]:
            if "node_modules/" not in source:
                continue
            resolved = (map_path.parent / source).resolve()
            pkg = package_dir(resolved)
            meta = json.loads((pkg / "package.json").read_text())
            key = "%s@%s" % (meta["name"], meta["version"])
            rel = pkg.relative_to(webui.resolve())
            if found.setdefault(key, rel) != rel:
                fail("%s resolves to %s and %s" % (key, found[key], rel))
    if not found:
        fail("no node_modules sources in the source maps")
    return found


def locked_resolutions(yarn_lock):
    text = yarn_lock.read_text()
    return set(re.findall(r'^  resolution: "(.+?)@npm:([^"]+)"$', text, re.M))


def copy_notices(pkg, dest):
    copied = 0
    for entry in sorted(pkg.iterdir()):
        if entry.is_file() and entry.name.lower().startswith(NOTICE_PREFIXES):
            dest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, dest / entry.name)
            if entry.name.lower().startswith(("license", "licence")) and entry.stat().st_size:
                copied += 1
        elif entry.is_dir() and entry.name == "licenses":
            shutil.copytree(entry, dest / "licenses")
    if not copied:
        fail("%s ships no non-empty license file" % pkg)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--webui", required=True, type=Path)
    parser.add_argument("--scratch", required=True, type=Path)
    parser.add_argument("--bundled", required=True, type=Path)
    parser.add_argument("--doc-out", required=True, type=Path)
    parser.add_argument("--sbom-out", required=True, type=Path)
    args = parser.parse_args()

    maps = check_same_code(args.webui / "dist", args.scratch)
    found = collect(maps, args.webui)

    locked = locked_resolutions(args.webui / "yarn.lock")
    for key in found:
        name, _, version = key.rpartition("@")
        if (name, version) not in locked:
            fail("%s has no yarn.lock resolution" % key)

    want = {
        line.strip()
        for line in args.bundled.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    }
    if set(found) != want:
        fail(
            "bundled set changed: added %s, removed %s"
            % (sorted(set(found) - want), sorted(want - set(found)))
        )

    if args.doc_out.exists() or args.sbom_out.exists():
        fail("output directories must not exist yet")
    args.doc_out.mkdir(parents=True)
    shutil.copy2(args.webui / "LICENSE", args.doc_out / "LICENSE")
    for key, rel in sorted(found.items()):
        pkg = args.webui / rel
        copy_notices(pkg, args.doc_out / key)
        target = args.sbom_out / rel / "package.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pkg / "package.json", target)
    print("webui-inventory: %d bundled packages" % len(found))


if __name__ == "__main__":
    main()
