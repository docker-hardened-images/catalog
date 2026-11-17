"""Check that requirements-lock.txt pins exactly what requirements-thirdparty.txt lists.

Usage: check-lock.py <requirements-thirdparty.txt> <requirements-lock.txt>

The lock is compiled from the input file. A name or version that differs
means one of the two files was edited without the other.
"""
import re
import sys


def norm(name):
    return re.sub(r"[-_.]+", "-", name.lower())


want = {}
for line in open(sys.argv[1]):
    m = re.match(r"([^#\s]\S*)==(\S+)", line)
    if m:
        want[norm(m.group(1))] = m.group(2)

got = {}
for m in re.finditer(r"^([A-Za-z0-9][^=\s]*)==(\S+)", open(sys.argv[2]).read(), re.M):
    got[norm(m.group(1))] = m.group(2)

diff = sorted(n for n in set(want) | set(got) if want.get(n) != got.get(n))
for n in diff:
    print(f"{n}: input {want.get(n)}, lock {got.get(n)}", file=sys.stderr)
if diff:
    sys.exit(1)
print(f"lock matches input: {len(got)} packages")
