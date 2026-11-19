"""Split a hashed requirements export into a wheel set and per-package files.

Usage: split-lock.py [--bumps BUMPS_JSON] EXPORT WHEELS_OUT SDIST_DIR NAME...

Each NAME's requirement block (pin, markers and --hash lines) is written to
SDIST_DIR/NAME.txt; every other block goes to WHEELS_OUT. Exits non-zero when a
NAME is missing from EXPORT or appears more than once, or when a package in
BUMPS_JSON is not pinned at its bumped version.
"""

import json
import re
import sys
from pathlib import Path

REQUIREMENT = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)==([^ ;\\]+)")


def normalize(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def blocks(text):
    current = []
    for line in text.splitlines(True):
        if REQUIREMENT.match(line) and current:
            yield current
            current = []
        current.append(line)
    if current:
        yield current


def main():
    args = sys.argv[1:]
    bumps = []
    if args[:1] == ["--bumps"]:
        bumps = json.loads(Path(args[1]).read_text())
        args = args[2:]
    export, wheels_out, sdist_dir, *names = args
    if not names:
        sys.exit("split-lock: no package names given")
    wanted = {normalize(name): [] for name in names}
    pins = {}
    kept = []
    for block in blocks(Path(export).read_text()):
        match = REQUIREMENT.match(block[0])
        name = normalize(match.group(1)) if match else None
        if name:
            pins.setdefault(name, []).append(match.group(2))
        if name in wanted:
            wanted[name].append(block)
        else:
            kept.extend(block)
    out = Path(sdist_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, found in wanted.items():
        if len(found) != 1:
            sys.exit("split-lock: %s appears %d times in %s" % (name, len(found), export))
        (out / (name + ".txt")).write_text("".join(found[0]))
    for bump in bumps:
        name = normalize(bump["package"])
        if pins.get(name) != [bump["version"]]:
            sys.exit("split-lock: %s is pinned at %s, not the bumped %s" % (name, pins.get(name), bump["version"]))
    Path(wheels_out).write_text("".join(kept))


if __name__ == "__main__":
    main()
