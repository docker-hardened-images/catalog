"""Check the SBOM fragments staged under opt/docker/sbom.

Usage: check-sboms.py SBOM_DIR VERSION WEBUI_BUNDLED LLHTTP_COMMIT

Fails unless locust/ names pkg:pypi/locust@VERSION, locust-webui/ names exactly
the npm packages in WEBUI_BUNDLED, and locust-llhttp/ names the llhttp commit.
"""

import re
import sys
from pathlib import Path


def text(directory):
    found = sorted(p for p in Path(directory).rglob("*") if p.is_file())
    if not found or not all(p.stat().st_size for p in found):
        sys.exit("check-sboms: %s is missing or has empty files" % directory)
    return "".join(p.read_text() for p in found)


def main():
    sbom_dir, version, bundled, llhttp_commit = sys.argv[1:]
    root = Path(sbom_dir)

    if "pkg:pypi/locust@%s" % version not in text(root / "locust"):
        sys.exit("check-sboms: locust SBOM lacks pkg:pypi/locust@%s" % version)

    want = set()
    for line in Path(bundled).read_text().splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        if entry.startswith("@"):
            entry = "%40" + entry[1:]
        want.add("pkg:npm/" + entry)
    have = set(re.findall(r"pkg:npm/[^\"?#\s]+", text(root / "locust-webui")))
    if have != want:
        sys.exit("check-sboms: web UI SBOM differs: extra %s, missing %s" % (sorted(have - want), sorted(want - have)))

    if "pkg:github/nodejs/llhttp@%s" % llhttp_commit not in text(root / "locust-llhttp"):
        sys.exit("check-sboms: llhttp SBOM lacks pkg:github/nodejs/llhttp@%s" % llhttp_commit)
    print("check-sboms: ok (%d npm packages)" % len(have))


if __name__ == "__main__":
    main()
