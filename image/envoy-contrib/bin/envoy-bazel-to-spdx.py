#!/usr/bin/env python3
"""
1. Runs `bazel query` to get all external dependencies with full metadata (URLs, SHAs, etc.)
2. Runs `bazel aquery` to determine which deps are actually linked into the binary
3. Filters the query results to only include actually-linked dependencies
4. Generates SPDX with complete metadata for only the runtime dependencies

Usage:
    python envoy-bazel-to-spdx.py $name $version [bazel build options...]

Any arguments after $version are passed through to `bazel aquery` so it
analyzes the same configuration the build produced (e.g. --config=boringssl-fips
changes both the linked SSL library and the contrib extension set). The
metadata `bazel query` is configuration-independent and takes no build options.

Example:
    python envoy-bazel-to-spdx.py envoy-contrib 1.39.0 -c opt --config=boringssl-fips
"""

import ast
import json
import re
import subprocess
import sys
from datetime import datetime

BAZEL = "/opt/bazel/bin/bazel"

# Envoy's statically-linked contrib release binary. Same entry lib as
# //source/exe:envoy-static plus SELECTED_CONTRIB_EXTENSIONS, so aquery over it
# picks up the extra archives the contrib extensions link in.
ENVOY_TARGET = "//contrib/exe:envoy-static"


def run_bazel(description, *args):
    print(description, file=sys.stderr)

    result = subprocess.run([BAZEL, "--batch", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"bazel {args[0]} failed: {result.stderr}")

    return result.stdout


def parse_http_archive_calls(query_output):
    print("Parsing http_archive calls...", file=sys.stderr)

    repositories = {}

    # Query output is technically Starlark but also valid Python - parse the whole thing as a module
    tree = ast.parse(query_output)

    # Walk the AST and find all Call nodes with func name 'http_archive'
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "http_archive"):
            continue

        repo_data = {}
        for keyword in node.keywords:
            try:
                repo_data[keyword.arg] = ast.literal_eval(keyword.value)
            except ValueError:
                pass  # non-literal kwarg — nothing downstream needs it

        if "name" in repo_data:
            repositories[repo_data["name"]] = repo_data

    print(f"Found {len(repositories)} dependencies from bazel query", file=sys.stderr)
    return repositories


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
            if target in all_repositories:
                repos.add(target)
                continue
            candidates = [
                repo
                for repo in all_repositories
                if len(repo) >= 3 and (repo in target or target in repo)
            ]
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


def parse_aquery_output(aquery_output, all_repositories):
    """Parse aquery output to extract linked dependencies."""
    print("Parsing aquery Linking action output...", file=sys.stderr)

    # format is something like:
    # action 'Linking envoy'
    #   Mnemonic: CppLink
    #   Target: //contrib/exe:envoy-static
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
    inputs_str = match.group(1).strip()

    # Extract external/<repo>/ directory segments from input files (the
    # trailing slash keeps files that sit directly under an external/ segment,
    # like contrib/vcl's genrule archives, from being taken for repo names).
    external_deps = set()
    input_files = [f.strip() for f in inputs_str.split(",") if f.strip()]
    for input_file in input_files:
        matches = re.findall(r"external/([^/]+)/", input_file)
        external_deps.update(matches)

    # Add statically linked archives that carry no external/<repo> segment.
    external_deps.update(resolve_archive_repos(input_files, all_repositories))

    # Filter out build tools
    filtered_deps = {
        dep
        for dep in external_deps
        if not dep.startswith("llvm_toolchain")
        and dep != "bazel_tools"
        and dep != "local_config_cc"
    }

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


def extract_version_from_metadata(repo_data):
    urls = get_urls(repo_data)
    candidates = ([repo_data["strip_prefix"]] if "strip_prefix" in repo_data else []) + urls

    # Semantic versions (e.g. "protobuf-3.21.12", "download/v2.6.0/") and
    # date-based versions (e.g. "re2-2024-07-02")
    for candidate in candidates:
        for pattern in (r"[-_/]v?(\d+\.\d+(?:\.\d+){0,2})", r"[-_/](\d{4}-\d{2}-\d{2})"):
            if match := re.search(pattern, candidate):
                return match.group(1)

    # Try commit SHA in URLs (e.g., "archive/{sha}.tar.gz")
    for url in urls:
        if match := re.search(r"/([a-f0-9]{40})(?:\.|/)", url):
            print(
                f"WARNING: Using commit SHA as version for {repo_data}",
                file=sys.stderr,
            )
            return match.group(1)[:12]  # Short SHA

    print(f"WARNING: No version extracted for {repo_data}", file=sys.stderr)
    return "UNKNOWN"


def create_purl(dep_name, repo_data, version):
    # Look for a GitHub URL
    for url in get_urls(repo_data):
        github_match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
        if github_match:
            org = github_match.group(1)
            repo = github_match.group(2)
            return f"pkg:github/{org}/{repo}@{version}"

    # For non-GitHub URLs, use generic type
    print(f"WARNING: Using generic purl for {repo_data}", file=sys.stderr)
    return f"pkg:generic/{dep_name}@{version}"


def generate_spdx(linked_deps, all_repositories, name, version):
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

    for i, dep in enumerate(linked_deps, start=1):
        repo_data = all_repositories.get(dep)
        if not repo_data:
            print(f"WARNING: No metadata found for {dep}. Skipping.", file=sys.stderr)
            continue

        urls = get_urls(repo_data)
        # The purl must carry the dependency's own version, not the Envoy
        # release version, or advisory matching can never hit.
        dep_version = extract_version_from_metadata(repo_data)

        package = {
            "SPDXID": f"SPDXRef-Package-{i}",
            "name": dep,
            "versionInfo": dep_version,
            "downloadLocation": urls[0] if urls else "NOASSERTION",
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": "NOASSERTION",
            "copyrightText": "NOASSERTION",
            "externalRefs": [
                {
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceType": "purl",
                    "referenceLocator": create_purl(dep, repo_data, dep_version),
                }
            ],
        }

        spdx_doc["packages"].append(package)

    print(
        f"Found {len(spdx_doc['packages'])} dependencies with metadata", file=sys.stderr
    )
    return spdx_doc


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

    # Get all dependencies with bazel query
    query_output = run_bazel(
        "Running bazel query to get all http_archive dependency metadata...",
        "query",
        "--output=build",
        'kind("http_archive", //external:*)',
    )
    all_repositories = parse_http_archive_calls(query_output)

    # Get actually-linked dependencies with aquery
    aquery_output = run_bazel(
        "Running bazel aquery to find actually-linked dependencies...",
        "aquery",
        *bazel_opts,
        f'outputs(".*envoy-static$", {ENVOY_TARGET})',
    )
    linked_deps = parse_aquery_output(aquery_output, all_repositories)

    # Generate SPDX with filtered deps
    spdx_doc = generate_spdx(linked_deps, all_repositories, name, version)

    json.dump(spdx_doc, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
