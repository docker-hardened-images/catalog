"""Check the locust wheel built from the sdist.

Usage: check-wheel.py WHEEL VERSION

Fails unless locust/_version.py carries VERSION and locust/webui holds exactly
the built front end: dist/auth.html, dist/index.html, dist/report.html and
dist/assets/*, with at least one dist/assets/src-*.js.
"""

import re
import sys
import zipfile

WEBUI_FILES = {"dist/auth.html", "dist/index.html", "dist/report.html"}


def main():
    wheel, version = sys.argv[1:]
    with zipfile.ZipFile(wheel) as archive:
        names = archive.namelist()
        version_py = archive.read("locust/_version.py").decode()
    if not re.search(r"^__version__ = version = '%s'$" % re.escape(version), version_py, re.M):
        sys.exit("check-wheel: locust/_version.py does not carry %s:\n%s" % (version, version_py))
    webui = {n[len("locust/webui/"):] for n in names if n.startswith("locust/webui/")}
    assets = {n for n in webui if n.startswith("dist/assets/")}
    if webui - assets != WEBUI_FILES:
        sys.exit("check-wheel: unexpected locust/webui entries: %s" % sorted(webui - assets - WEBUI_FILES))
    if not any(re.fullmatch(r"dist/assets/src-[^/]+\.js", n) for n in assets):
        sys.exit("check-wheel: no dist/assets/src-*.js in the wheel")
    print("check-wheel: %d locust/webui files" % len(webui))


if __name__ == "__main__":
    main()
