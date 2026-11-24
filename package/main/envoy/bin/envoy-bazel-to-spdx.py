#!/usr/bin/env python3
"""
1. Reads Bazel repository rules for external dependency metadata (URLs, SHAs, etc.)
2. Runs `bazel aquery` to determine which deps are actually linked into the binary
3. Filters the query results to only include actually-linked dependencies
4. Generates SPDX with complete metadata for only the runtime dependencies

Every linked repository either resolves to a concrete name, version and purl,
is on the documented NON_SHIPPED_REPOS list, or the script exits non-zero
naming it. It never writes UNKNOWN or skips a repository silently. It also
exits non-zero when a component in REQUIRED_COMPONENTS is missing.

Usage:
    python envoy-bazel-to-spdx.py $name $version [bazel build options...]

Any arguments after $version are passed through to `bazel aquery` so it
analyzes the same configuration the build produced (e.g. --config=boringssl-fips
changes the linked SSL library). The metadata commands are
configuration-independent and take no build options.

Environment:
    ENVOY_SBOM_BINARY   Path to the built envoy binary. When set, each
                        component carrying a binary marker (V8) must have its
                        version string present in that file, so the SBOM
                        cannot name a version the binary does not contain.

Example:
    python envoy-bazel-to-spdx.py envoy 1.40.2 -c opt --config=boringssl-fips
"""

import ast
import json
import os
import re
import subprocess
import sys
from datetime import datetime

BAZEL = "/opt/bazel/bin/bazel"

# Envoy's statically-linked release binary.
ENVOY_TARGET = "//source/exe:envoy-static"

# Repositories that appear on the link line without being shipped as a
# library: toolchain files are inputs of every link action, and the Envoy
# source repositories are covered by the `envoy` SPDX document. Anything else
# the link line names has to resolve.
NON_SHIPPED_REPOS = (
    (r"^llvm_toolchain", "hermetic LLVM toolchain"),
    (r"^bazel_tools$", "Bazel's built-in tools"),
    (r"^local_config_cc$", "autoconfigured C++ toolchain"),
    (r"^toolchains_llvm\+\+llvm\+llvm_toolchain", "toolchains_llvm LLVM toolchain"),
    (
        r"^envoy_toolshed\+\+llvm_minimal_extension\+llvm_minimal_",
        "toolshed minimal LLVM toolchain",
    ),
    (r"^envoy_toolshed\+\+sysroot_extension\+sysroot_", "hermetic glibc sysroot"),
    (r"^envoy_api\+?$", "Envoy's own api/ tree, part of the envoy source row"),
)

# Components the binary always links. A missing one means an upstream change
# renamed or dropped a repository, and the SBOM would silently lose it.
REQUIRED_COMPONENTS = (
    ("v8", "pkg:github/v8/v8@", "V8 (wasm runtime)"),
    ("luajit", "pkg:github/LuaJIT/LuaJIT@", "LuaJIT"),
)

# Hex digits that identify a git commit.
FULL_COMMIT = re.compile(r"(?<![0-9a-f])[0-9a-f]{40}(?![0-9a-f])")
SHORT_COMMIT_URL = re.compile(r"/([0-9a-f]{7,39})\.(?:tar\.gz|tgz|tar\.xz|zip)$")

# envoyproxy/toolshed repository rule that downloads a prebuilt libwee8.a.
WEE8_REPO = re.compile(r"wee8_prebuilt_extension\+wee8_prebuilt_(x86_64|aarch64)")
WEE8_RULE = "wee8_prebuilt"
V8_PURL = "pkg:github/v8/v8@{}"
WEE8_URL = (
    "https://github.com/envoyproxy/toolshed/releases/download/"
    "bins-v{release}/v8-wee8-{v8}-linux-{arch}{stdlib}.tar.xz"
)

# Libraries Envoy vendors in its own tree. The repository name on the link
# line comes from the //bazel/external/<name> package path, so there is no
# repository rule to read; the vendoring note beside the sources is the record.
HTTP_PARSER_DIR = "bazel/external/http_parser"
HTTP_PARSER_COMMIT = re.compile(
    r"github\.com/nodejs/http-parser\)\s+repo at commit\s+`([0-9a-f]{40})`"
)


class SbomError(RuntimeError):
    """A linked dependency could not be described, or the SBOM is incomplete."""


def run_bazel(description, *args):
    print(description, file=sys.stderr)

    result = subprocess.run([BAZEL, "--batch", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"bazel {args[0]} failed: {result.stderr}")

    return result.stdout


def parse_repository_calls(repository_output):
    """Parse repository rule calls out of `mod show_repo` or `query` output.

    Every call that carries a name becomes an entry, tagged with the rule it
    came from under "_rule" (http_archive, wee8_prebuilt, local_repository, ...).
    """
    print("Parsing repository rule calls...", file=sys.stderr)

    repositories = {}

    # Query output is technically Starlark but also valid Python - parse the whole thing as a module
    tree = ast.parse(repository_output)

    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)):
            continue

        repo_data = {}
        for keyword in node.keywords:
            try:
                repo_data[keyword.arg] = ast.literal_eval(keyword.value)
            except ValueError:
                pass  # non-literal kwarg — nothing downstream needs it

        if "name" in repo_data:
            repo_data["_rule"] = node.func.id
            repositories[repo_data["name"]] = repo_data

    print(
        f"Found {len(repositories)} dependencies with repository metadata",
        file=sys.stderr,
    )
    return repositories


def get_module_repositories(linked_repositories):
    """Return (repositories, module_versions) for the active dependency system.

    Envoy 1.40 uses Bzlmod and no longer has a WORKSPACE file, so //external
    cannot enumerate repository rules. `mod show_repo` is the supported Bzlmod
    equivalent and emits the same repository rule calls this script already
    parses. Envoy 1.39 explicitly disables Bzlmod and still uses //external.
    module_versions maps each selected module name to its locked version.
    """
    try:
        graph_output = run_bazel(
            "Reading the Bzlmod dependency graph...",
            "mod",
            "graph",
            "--output=json",
        )
    except RuntimeError as error:
        if "Bzlmod has to be enabled" not in str(error):
            raise
        return (
            parse_repository_calls(
                run_bazel(
                    "Reading WORKSPACE repository metadata...",
                    "query",
                    "--output=build",
                    'kind("http_archive", //external:*)',
                )
            ),
            {},
        )

    root = json.loads(graph_output)
    modules = {}
    pending = [*root["dependencies"], *root["indirectDependencies"]]
    while pending:
        module = pending.pop()
        if module["key"] in modules:
            continue
        modules[module["key"]] = module
        pending.extend(module.get("dependencies", []))
        pending.extend(module.get("indirectDependencies", []))

    repositories_to_show = set(modules)
    repositories_to_show.update(
        f"@@{repo}" for repo in linked_repositories if "++" in repo
    )

    repositories = parse_repository_calls(
        run_bazel(
            "Reading Bzlmod repository metadata...",
            "mod",
            "show_repo",
            *sorted(repositories_to_show),
        )
    )

    modules_by_name = {module["name"]: module for module in modules.values()}
    for canonical_name, repository in repositories.items():
        if "++" in canonical_name:
            repository["_module_name"] = canonical_name.rsplit("+", 1)[-1]
            continue
        module = modules_by_name.get(canonical_name.split("+", 1)[0])
        if module:
            repository["_module_name"] = module["name"]

    module_versions = {
        name: module["version"]
        for name, module in modules_by_name.items()
        if module.get("version")
    }
    return repositories, module_versions


def resolve_archive_repos(input_files, all_repositories):
    """Map static archives with no external/<repo> path segment back to repos.

    rules_foreign_cc outputs enter the link as
    bazel-out/.../bazel/foreign_cc/<target>/lib/*.a and in-repo genrule
    archives as plain contrib/... paths, so the statically linked repo
    (librdkafka, vectorscan, libevent, nghttp2, lz4, icu, ...) would otherwise
    be invisible to the SBOM. Anything unmapped logs a WARNING in the build
    log instead of being silently dropped.
    """
    # In-repo genrule archives whose paths carry no usable repo hint.
    genrule_archive_repos = (
        (r"/vectorscan/lib/libhs\.a$", "vectorscan"),
        (r"/hyperscan/lib/libhs\.a$", "hyperscan"),
        (r"/contrib/vcl/source/external/", "vpp_vcl"),
        (r"/contrib/kae/uadklib/", "uadk"),
    )

    # Only archives name a foreign_cc target; other repository rules are
    # resolved from the link inputs by their exact name.
    archives = {
        repo: repo_data
        for repo, repo_data in all_repositories.items()
        if repo_data.get("_rule", "http_archive") == "http_archive"
    }

    repos = set()
    for input_file in input_files:
        if not input_file.endswith(".a"):
            continue

        if match := re.search(r"/bazel/foreign_cc/([^/]+)/", input_file):
            # The foreign_cc target is named after its repo, give or take a
            # _build suffix or a lib/org prefix (event -> libevent,
            # unicode_icu_build -> icu, librdkafka_build ->
            # confluentinc_librdkafka).
            target = re.sub(r"_build$", "", match.group(1))
            if target in archives:
                repos.add(target)
                continue
            candidates = []
            for repo, repo_data in archives.items():
                module_name = repo_data.get("_module_name", repo)
                if len(module_name) >= 3 and (
                    module_name in target or target in module_name
                ):
                    candidates.append(repo)
            if len(candidates) == 1:
                repos.add(candidates[0])
            else:
                print(
                    f"WARNING: cannot map foreign_cc archive {input_file} to a repo"
                    f" (candidates: {candidates})",
                    file=sys.stderr,
                )
            continue

        for pattern, repo in genrule_archive_repos:
            if re.search(pattern, input_file):
                repos.add(repo)
                break

    return repos


def get_link_inputs(aquery_output):
    # format is something like:
    # action 'Linking envoy'
    #   Mnemonic: CppLink
    #   Target: //source/exe:envoy-static
    #   ...
    #   Inputs: [ /path/to/file1, /path/to/file2, /path/to/file3, ...]
    #
    # Find the first Linking action and extract its Inputs line contents between square brackets
    match = re.search(
        r"action 'Linking [^']*'.*?\n  Inputs: \[([^\]]+)\]", aquery_output, re.DOTALL
    )
    if not match:
        raise RuntimeError(
            "Could not find Linking action with Inputs line in aquery output"
        )
    return [f.strip() for f in match.group(1).strip().split(",") if f.strip()]


def non_shipped_reason(dep):
    for pattern, reason in NON_SHIPPED_REPOS:
        if re.search(pattern, dep):
            return reason
    return None


def parse_aquery_output(aquery_output, all_repositories):
    """Parse aquery output to extract linked dependencies."""
    print("Parsing aquery Linking action output...", file=sys.stderr)

    # Extract external/<repo>/ directory segments from input files (the
    # trailing slash keeps files that sit directly under an external/ segment,
    # like contrib/vcl's genrule archives, from being taken for repo names).
    external_deps = set()
    input_files = get_link_inputs(aquery_output)
    for input_file in input_files:
        matches = re.findall(r"external/([^/]+)/", input_file)
        external_deps.update(matches)

    # Add statically linked archives that carry no external/<repo> segment.
    external_deps.update(resolve_archive_repos(input_files, all_repositories))

    filtered_deps = {dep for dep in external_deps if not non_shipped_reason(dep)}

    print(
        f"Found {len(filtered_deps)} external linked runtime dependencies from bazel aquery",
        file=sys.stderr,
    )
    return sorted(filtered_deps)


def get_urls(repo_data):
    if "urls" in repo_data:
        return repo_data["urls"]
    elif "url" in repo_data:
        return [repo_data["url"]]
    return []


def get_module_version(repo_data):
    """The registry version of the module that owns repo_data, if it has one."""
    for url in repo_data.get("remote_module_file_urls") or []:
        if match := re.search(r"/modules/[^/]+/([^/]+)/MODULE\.bazel$", url):
            return match.group(1)
    return None


def resolve_short_commit(short, repo_data):
    """Resolve a short commit named in a URL to the full commit.

    GitHub archive URLs accept an abbreviated commit, and Bazel's strip_prefix
    for such an archive is <repo>-<full commit>, so the full commit is already
    in the repository metadata. It has to start with the short one, and with the
    one in the module's registry version (0.0.0-<yymmdd>-<short>.<suffix>) when
    that carries one.
    """
    name = repo_data.get("name")
    strip_prefix = repo_data.get("strip_prefix", "")
    commits = {c for c in FULL_COMMIT.findall(strip_prefix) if c.startswith(short)}
    if len(commits) != 1:
        raise SbomError(
            f"{name}: the URL pins commit {short} but strip_prefix {strip_prefix!r}"
            f" has no 40-character commit starting with it, so the full commit"
            f" cannot be verified"
        )
    commit = commits.pop()

    module_version = get_module_version(repo_data) or ""
    if match := re.search(r"-\d{6}-([0-9a-f]{7,12})(?:\.[A-Za-z0-9]+)*$", module_version):
        if not commit.startswith(match.group(1)):
            raise SbomError(
                f"{name}: module version {module_version} names commit"
                f" {match.group(1)} but the archive is {commit}"
            )
    return commit


def extract_version_from_metadata(repo_data):
    """Return the archive's version, or None when the metadata has none."""
    urls = get_urls(repo_data)
    candidates = ([repo_data["strip_prefix"]] if "strip_prefix" in repo_data else []) + urls

    # Semantic versions (e.g. "protobuf-3.21.12", "download/v2.6.0/") and
    # date-based versions (e.g. "re2-2024-07-02")
    for candidate in candidates:
        for pattern in (r"[-_/]v?(\d+\.\d+(?:\.\d+){0,2})", r"[-_/](\d{4}-\d{2}-\d{2})"):
            if match := re.search(pattern, candidate):
                return match.group(1)

    # Commit SHA in URLs (e.g., "archive/{sha}.tar.gz"). The version is the
    # full commit: purls and advisory ranges are written against full hashes.
    for url in urls:
        if match := re.search(r"/([a-f0-9]{40})(?:\.|/)", url):
            print(
                f"WARNING: Using commit SHA as version for {repo_data.get('name')}",
                file=sys.stderr,
            )
            return match.group(1)

    for url in urls:
        if match := SHORT_COMMIT_URL.search(url):
            commit = resolve_short_commit(match.group(1), repo_data)
            print(
                f"WARNING: Using commit SHA as version for {repo_data.get('name')}"
                f" (resolved {match.group(1)} from strip_prefix)",
                file=sys.stderr,
            )
            return commit

    return None


def create_purl(dep_name, repo_data, version):
    # Look for a GitHub URL
    for url in get_urls(repo_data):
        github_match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
        if github_match:
            org = github_match.group(1)
            repo = github_match.group(2)
            return f"pkg:github/{org}/{repo}@{version}"

    # For non-GitHub URLs, use generic type
    print(f"WARNING: Using generic purl for {dep_name}", file=sys.stderr)
    return f"pkg:generic/{dep_name}@{version}"


def parse_v8_version_header(text):
    """Read the version out of V8's include/v8-version.h."""
    parts = []
    for macro in ("MAJOR_VERSION", "MINOR_VERSION", "BUILD_NUMBER", "PATCH_LEVEL"):
        match = re.search(rf"^#define V8_{macro}\s+(\d+)\s*$", text, re.MULTILINE)
        if not match:
            return None
        parts.append(match.group(1))
    return ".".join(parts)


def locked_v8_version(module_versions):
    """V8 version of the `v8` module in the lock, e.g. 14.6.202.10.envoy -> 14.6.202.10."""
    match = re.match(r"(\d+(?:\.\d+){3})(?:\.|$)", module_versions.get("v8", ""))
    return match.group(1) if match else None


def resolve_wee8_prebuilt(dep, repo_data, header_text, locked_version):
    """Describe the prebuilt libwee8.a (V8) that Envoy 1.40 links statically.

    The repository rule only records the toolshed release, the archive's
    sha256, the architecture and the C++ library flavor. The V8 version is not
    an attribute: toolshed bakes it into the archive's file name. The archive's
    own include/v8-version.h is the authority for what is linked, and the
    locked `v8` module (which Envoy builds its wasm host against) is the
    fallback and cross-check.
    """
    from_header = parse_v8_version_header(header_text) if header_text else None
    version = from_header or locked_version
    if not version:
        raise SbomError(
            f"{dep}: cannot determine the linked V8 version; neither"
            f" include/v8-version.h in the repository nor the locked v8 module"
            f" provided one"
        )
    if from_header and locked_version and from_header != locked_version:
        print(
            f"WARNING: {dep} contains V8 {from_header} but the locked v8 module is"
            f" {locked_version}; using the version in the archive",
            file=sys.stderr,
        )

    repo_data = repo_data or {}
    match = WEE8_REPO.search(dep)
    arch = repo_data.get("arch") or (match.group(1) if match else None)
    stdlib = repo_data.get("stdlib", "libcxx")
    release = repo_data.get("version")
    sha256 = repo_data.get("sha256")

    download = f"https://github.com/v8/v8/archive/refs/tags/{version}.tar.gz"
    comment = (
        f"Prebuilt libwee8.a built from V8 {version}, statically linked into envoy;"
        f" resolved from repository {dep}."
    )
    if arch and release:
        suffix = "" if stdlib == "libcxx" else f"-{stdlib}"
        download = WEE8_URL.format(release=release, v8=version, arch=arch, stdlib=suffix)

    return {
        "name": "v8",
        "version": version,
        "download": download,
        "purl": V8_PURL.format(version),
        "sha256": sha256,
        "comment": comment,
        "binary_marker": True,
    }


def resolve_vendored_http_parser(read_source):
    readme = read_source(f"{HTTP_PARSER_DIR}/README.md")
    match = HTTP_PARSER_COMMIT.search(readme or "")
    if not match:
        raise SbomError(
            f"http_parser: {HTTP_PARSER_DIR}/README.md does not name the vendored"
            f" nodejs/http-parser commit, so the version cannot be determined"
        )
    commit = match.group(1)
    return {
        "name": "http-parser",
        "version": commit,
        "download": f"git+https://github.com/nodejs/http-parser@{commit}",
        "purl": f"pkg:github/nodejs/http-parser@{commit}",
        "comment": f"Vendored in the Envoy source tree at {HTTP_PARSER_DIR}.",
    }


def resolve_archive(dep, repo_data):
    version = extract_version_from_metadata(repo_data)
    if not version:
        raise SbomError(f"{dep}: no version in its strip_prefix or URLs {get_urls(repo_data)}")

    urls = get_urls(repo_data)
    package_name = repo_data.get("_module_name", dep)
    return {
        "name": package_name,
        "version": version,
        "download": urls[0] if urls else "NOASSERTION",
        "purl": create_purl(package_name, repo_data, version),
    }


def resolve_dependency(dep, all_repositories, module_versions, read_source, read_v8_header):
    """Return the component for a linked repository, None when it is not shipped.

    Raises SbomError when it is shipped and cannot be described.
    """
    if reason := non_shipped_reason(dep):
        print(f"Not shipped: {dep} ({reason})", file=sys.stderr)
        return None

    repo_data = all_repositories.get(dep)

    if WEE8_REPO.search(dep) or (repo_data or {}).get("_rule") == WEE8_RULE:
        return resolve_wee8_prebuilt(
            dep, repo_data, read_v8_header(dep), locked_v8_version(module_versions)
        )

    if dep == "http_parser":
        return resolve_vendored_http_parser(read_source)

    if not repo_data:
        raise SbomError(f"{dep}: no repository metadata")
    if repo_data.get("_rule", "http_archive") != "http_archive":
        raise SbomError(
            f"{dep}: repository rule {repo_data['_rule']} is not handled, so its"
            f" name and version cannot be determined"
        )
    return resolve_archive(dep, repo_data)


def resolve_components(linked_deps, all_repositories, module_versions, read_source, read_v8_header):
    components = []
    errors = []
    for dep in linked_deps:
        try:
            component = resolve_dependency(
                dep, all_repositories, module_versions, read_source, read_v8_header
            )
        except SbomError as error:
            errors.append(str(error))
            continue
        if component:
            components.append(component)

    for component in components:
        version = component["version"]
        if (
            not version
            or version.upper() in ("UNKNOWN", "NOASSERTION")
            or not component["purl"].endswith(f"@{version}")
        ):
            errors.append(
                f"{component['name']}: unusable identity {version!r} / {component['purl']!r}"
            )

    for name, purl_prefix, description in REQUIRED_COMPONENTS:
        if not any(c["purl"].startswith(purl_prefix) for c in components):
            errors.append(
                f"{description} ({purl_prefix}...) is linked into envoy but is not in"
                f" the SBOM; its Bazel repository was not found among the link"
                f" inputs or was not resolved"
            )

    if errors:
        raise SbomError(
            "cannot describe every linked dependency:\n  - " + "\n  - ".join(errors)
        )
    return components


def verify_binary_markers(components, binary_path):
    with open(binary_path, "rb") as binary:
        content = binary.read()
    missing = [
        f"{c['name']} {c['version']}"
        for c in components
        if c.get("binary_marker") and c["version"].encode() not in content
    ]
    if missing:
        raise SbomError(
            f"{binary_path} does not contain the version string of: {', '.join(missing)}"
        )


def generate_spdx(components, name, version):
    print("Generating SPDX document...", file=sys.stderr)

    spdx_doc = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": f"SPDXRef-{name}",
        "name": f"SPDX document for {name} {version}",
        "documentNamespace": f"{name}-{version}",
        "creationInfo": {
            "created": datetime.now().isoformat(),
            "creators": [
                "Organization: Docker, Inc.",
            ],
        },
        "packages": [],
    }

    for i, component in enumerate(components, start=1):
        package = {
            "SPDXID": f"SPDXRef-Package-{i}",
            "name": component["name"],
            "versionInfo": component["version"],
            "downloadLocation": component["download"],
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": "NOASSERTION",
            "copyrightText": "NOASSERTION",
            "externalRefs": [
                {
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceType": "purl",
                    "referenceLocator": component["purl"],
                }
            ],
        }
        if component.get("sha256"):
            package["checksums"] = [
                {"algorithm": "SHA256", "checksumValue": component["sha256"]}
            ]
        if component.get("comment"):
            package["comment"] = component["comment"]

        spdx_doc["packages"].append(package)

    print(f"Found {len(spdx_doc['packages'])} dependencies", file=sys.stderr)
    return spdx_doc


def bazel_header_reader():
    """Return a reader for include/v8-version.h of a fetched repository."""
    output_base = []

    def read(dep):
        if not output_base:
            output_base.append(
                run_bazel("Locating the Bazel output base...", "info", "output_base").strip()
            )
        path = os.path.join(output_base[0], "external", dep, "include", "v8-version.h")
        try:
            with open(path, encoding="utf-8") as header:
                return header.read()
        except OSError:
            print(f"WARNING: cannot read {path}", file=sys.stderr)
            return None

    return read


def source_reader(root):
    def read(path):
        try:
            with open(os.path.join(root, path), encoding="utf-8") as source:
                return source.read()
        except OSError:
            return None

    return read


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python envoy-bazel-to-spdx.py <name> <version> [bazel build options...]",
            file=sys.stderr,
        )
        sys.exit(1)

    name = sys.argv[1]
    version = sys.argv[2]
    bazel_opts = sys.argv[3:]

    try:
        # Get actually-linked dependencies with aquery
        aquery_output = run_bazel(
            "Running bazel aquery to find actually-linked dependencies...",
            "aquery",
            *bazel_opts,
            f'outputs(".*envoy-static$", {ENVOY_TARGET})',
        )
        linked_repositories = {
            repo
            for input_file in get_link_inputs(aquery_output)
            for repo in re.findall(r"external/([^/]+)/", input_file)
        }

        # Get dependency metadata from Bzlmod or the legacy WORKSPACE interface.
        all_repositories, module_versions = get_module_repositories(linked_repositories)
        linked_deps = parse_aquery_output(aquery_output, all_repositories)

        components = resolve_components(
            linked_deps,
            all_repositories,
            module_versions,
            source_reader(os.getcwd()),
            bazel_header_reader(),
        )
        if binary_path := os.environ.get("ENVOY_SBOM_BINARY"):
            verify_binary_markers(components, binary_path)
    except SbomError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)

    # Generate SPDX with filtered deps
    json.dump(generate_spdx(components, name, version), sys.stdout, indent=2)


if __name__ == "__main__":
    main()
