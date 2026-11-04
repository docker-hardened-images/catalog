"""Assemble the from-source payload requirements.

Third-party dependencies are a static, hash-locked requirements-lock.txt
staged alongside this script -- see its header for the regeneration recipe
and the cve_overrides this build applies above Datadog's own lockfile.

This script's own job is narrower: select which integrations-core checks to
ship, by reimplementing upstream's agent.collect-integrations manifest.json
+ pyproject filter, and strip pymqi from the lock on arm64 (IBM ships no
arm64 MQ redistributable, matching upstream's own arm exclusion of
ibm_mq/ibm_ace below). ddtrace is also stripped: it installs from the
checksummed sdist tree whose Cargo.lock the build patches.
"""
import json, os, re, tomllib
from packaging.specifiers import SpecifierSet

ic = "/build/integrations-core"
mach = os.uname().machine
is_arm = mach in ("aarch64", "arm64")

lock_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements-lock.txt")
with open(lock_path) as f:
    lock = f.read()
stripped = ("ddtrace==", "pymqi==") if is_arm else ("ddtrace==",)
entries = re.split(r"\n(?=\S)", lock.strip())
kept = [e for e in entries if not e.startswith(stripped)]
assert len(entries) - len(kept) == len(stripped)
# python-dateutil builds with setuptools_scm<8.0, which no other sdist
# accepts, so it installs in its own pass with build-constraints-dateutil.txt.
dateutil = [e for e in kept if e.startswith("python-dateutil==")]
assert len(dateutil) == 1
kept = [e for e in kept if e not in dateutil]
with open("/build/requirements-lock-filtered.txt", "w") as f:
    f.write("\n".join(kept) + "\n")
with open("/build/requirements-dateutil.txt", "w") as f:
    f.write(dateutil[0] + "\n")

excluded = {
    "datadog_checks_base", "datadog_checks_dev",
    "datadog_checks_tests_helper", "docker_daemon",
}
if is_arm:
    excluded |= {"ibm_mq", "ibm_ace"}
cfg = os.path.join(ic, ".ddev", "config.toml")
overrides = {}
if os.path.isfile(cfg):
    with open(cfg, "rb") as f:
        overrides = tomllib.load(f).get("overrides", {}).get("manifest", {}).get("platforms", {}) or {}


def supports_py3(d):
    pj = os.path.join(d, "pyproject.toml")
    if not os.path.isfile(pj):
        return False
    with open(pj, "rb") as f:
        rp = tomllib.load(f).get("project", {}).get("requires-python")
    if not rp or rp.strip() in (">=", ">", "<=", "<", "==", "!=", "~=", "==="):
        return True
    try:
        spec = SpecifierSet(rp)
    except Exception:
        return True
    return any(spec.contains("3.%d" % m) for m in range(100))


checks = []
for entry in sorted(os.listdir(ic)):
    p = os.path.join(ic, entry)
    if not os.path.isdir(p) or entry in excluded:
        continue
    mf = os.path.join(p, "manifest.json")
    if os.path.isfile(mf):
        with open(mf) as f:
            tags = json.load(f).get("tile", {}).get("classifier_tags", [])
        if "Supported OS::Linux" not in tags:
            continue
    elif entry in overrides:
        if "linux" not in overrides[entry]:
            continue
    else:
        continue
    if supports_py3(p):
        checks.append(entry)

with open("/build/selected.txt", "w") as f:
    f.write("\n".join(checks) + "\n")
with open("/build/requirements-local.txt", "w") as f:
    f.write("/build/ddtrace\n")
    f.write(ic + "/datadog_checks_base\n")
    for c in checks:
        f.write(ic + "/" + c + "\n")

print("integrations:", len(checks))
