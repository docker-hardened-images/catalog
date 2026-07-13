#!/usr/lib/httpbin/bin/python
import os
import sys

_BIN = os.path.dirname(os.path.realpath(__file__))


def _version():
    import httpbin

    with open(os.path.join(os.path.dirname(httpbin.__file__), "VERSION")) as fh:
        return fh.read().strip()


def main():
    args = sys.argv[1:]
    if args and args[0] == "version":
        print("httpbin " + _version())
        return 0
    os.execv(os.path.join(_BIN, "gunicorn"), ["gunicorn", *args])


if __name__ == "__main__":
    sys.exit(main())
