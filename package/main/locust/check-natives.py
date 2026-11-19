"""Check the source-built native extensions in the locust venv.

Run with the venv's interpreter.

  check-natives.py list-so DIST...   print the .so files the named dists installed
  check-natives.py check ZMQ_VERSION link and import checks for the rebuilt natives

"check" fails unless each rebuilt extension links the system library it was
built against, no vendored-library directory survived, and the modules import
and work. No distribution in the venv may ship an auditwheel *.libs directory:
every native library comes from a system package.
"""

import subprocess
import sys
import sysconfig
from importlib.metadata import files
from pathlib import Path

NEEDED = {
    "zmq/backend/cython/_zmq.*.so": ["libzmq.so.5"],
    "gevent/libev/corecext.*.so": ["libev.so.4"],
    "gevent/libev/_corecffi.*.so": ["libev.so.4"],
    "gevent/libuv/_corecffi.*.so": ["libuv.so.1"],
    "gevent/resolver/cares.*.so": ["libcares.so.2"],
    "_brotli.*.so": ["libbrotlienc.so.1", "libbrotlidec.so.1"],
    "geventhttpclient/_parser.*.so": [],
    "greenlet/_greenlet.*.so": ["libstdc++.so.6"],
}


def fail(message):
    sys.exit("check-natives: " + message)


def needed(path):
    out = subprocess.run(["readelf", "-d", str(path)], check=True, capture_output=True, text=True).stdout
    return {line.split("[", 1)[1].split("]", 1)[0] for line in out.splitlines() if "(NEEDED)" in line}


def list_so(dists):
    for dist in dists:
        found = [f for f in files(dist) or [] if str(f).endswith(".so")]
        if not found:
            fail("%s installed no .so files" % dist)
        for f in found:
            print(f.locate())


def check(zmq_version):
    site = Path(sysconfig.get_paths()["purelib"])
    for pattern, libs in NEEDED.items():
        matches = sorted(site.glob(pattern))
        if len(matches) != 1:
            fail("expected one %s, found %s" % (pattern, matches))
        have = needed(matches[0])
        missing = [lib for lib in libs if lib not in have]
        if missing:
            fail("%s does not link %s (NEEDED: %s)" % (matches[0], missing, sorted(have)))
    vendored = sorted(p.name for p in site.glob("*.libs"))
    if vendored:
        fail("%s ships vendored libraries: %s" % (site, vendored))

    import brotli
    import gevent.libev.corecext
    import gevent.resolver.cares
    import geventhttpclient
    import zmq

    if zmq.zmq_version() != zmq_version:
        fail("pyzmq loads libzmq %s, want %s" % (zmq.zmq_version(), zmq_version))
    data = b"locust " * 1000
    if brotli.decompress(brotli.compress(data)) != data:
        fail("brotli round trip changed the data")
    del gevent, geventhttpclient
    print("check-natives: ok")


def main():
    if len(sys.argv) < 3:
        fail("usage: check-natives.py list-so DIST... | check ZMQ_VERSION")
    if sys.argv[1] == "list-so":
        list_so(sys.argv[2:])
    elif sys.argv[1] == "check":
        check(sys.argv[2])
    else:
        fail("unknown command %s" % sys.argv[1])


if __name__ == "__main__":
    main()
