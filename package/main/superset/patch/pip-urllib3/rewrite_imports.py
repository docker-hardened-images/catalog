#!/usr/bin/env python3
"""Rewrite urllib3 imports the way pip's vendoring tool does.

Pip applies tools/vendoring patches first, then rewrites ``import idna`` and
``import urllib3`` into the ``pip._vendor`` namespace. Run this on the copied
urllib3 tree after those patches.
"""

import re
import sys
from pathlib import Path

NAMESPACE = "pip._vendor"
LIBS = ("idna", "urllib3")


def rewrite(text: str, item: Path) -> str:
    for lib in LIBS:
        text = re.sub(
            rf"^(\s*)import {lib}(\s|$)",
            rf"\1from {NAMESPACE} import {lib}\2",
            text,
            flags=re.MULTILINE,
        )
        text = re.sub(
            rf"^(\s*)import {lib}(\.\S+)(?=\s+as)",
            rf"\1import {NAMESPACE}.{lib}\2",
            text,
            flags=re.MULTILINE,
        )
        match = re.search(rf"^\s*(import {lib}\.\S+)", text, flags=re.MULTILINE)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            raise SystemExit(f"{item}:{line}: cannot rewrite {match.group(1)}")
        text = re.sub(
            rf"^(\s*)from {lib}(\.|\s)",
            rf"\1from {NAMESPACE}.{lib}\2",
            text,
            flags=re.MULTILINE,
        )
    return text


def require(path: Path, needle: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle not in text:
        raise SystemExit(f"{path}: missing {needle!r}")


def main() -> None:
    root = Path(sys.argv[1])
    if not root.is_dir():
        raise SystemExit(f"not a directory: {root}")
    backups = sorted(root.rglob("*.orig"))
    if backups:
        listed = ", ".join(str(path.relative_to(root)) for path in backups)
        raise SystemExit(f"patch left backup files: {listed}")
    for item in sorted(root.rglob("*.py")):
        item.write_text(rewrite(item.read_text(encoding="utf-8"), item), encoding="utf-8")

    if not (root / "LICENSE.txt").is_file():
        raise SystemExit(f"missing bundled license: {root / 'LICENSE.txt'}")
    require(
        root / "contrib/emscripten/__init__.py",
        "import pip._vendor.urllib3.connection as urllib3_connection",
    )
    require(root / "contrib/pyopenssl.py", "from pip._vendor import idna")
    require(root / "util/url.py", "from pip._vendor import idna")
    require(root / "response.py", "brotli = None")
    request = (root / "util/request.py").read_text(encoding="utf-8")
    if "import brotli" in request or 'ACCEPT_ENCODING += ",br"' in request:
        raise SystemExit("unvendored Brotli support is still enabled")
    for item in root.rglob("*.py"):
        for line_no, line in enumerate(item.read_text(encoding="utf-8").splitlines(), 1):
            if re.match(r"\s*(import|from) idna(\s|\.|$)", line):
                raise SystemExit(f"{item}:{line_no}: idna import was not rewritten: {line}")
            if re.match(r"\s*import urllib3(\s|\.|$)", line):
                raise SystemExit(f"{item}:{line_no}: urllib3 import was not rewritten: {line}")


if __name__ == "__main__":
    main()
