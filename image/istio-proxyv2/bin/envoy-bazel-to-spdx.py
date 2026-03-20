#!/usr/bin/env python3
"""
1. Runs `bazel query` to get all external dependencies with full metadata (URLs, SHAs, etc.)
2. Runs `bazel aquery` to determine which deps are actually linked into the binary
3. Filters the query results to only include actually-linked dependencies
4. Generates SPDX with complete metadata for only the runtime dependencies

Usage:
    python envoy-bazel-to-spdx.py $name $version

Example:
    python envoy-bazel-to-spdx.py istio-proxyv2-envoy 1.27.5
"""

import ast
import json
import re
import subprocess
import sys
from datetime import datetime

BAZEL = "/opt/bazel/bin/bazel"


def run_bazel_query():
    print(
        "Running bazel query to get all http_archive dependency metadata...",
        file=sys.stderr,
    )

    cmd = [
        BAZEL,
        "--batch",
        "query",
        "--output=build",
        'kind("http_archive", //external:*)',
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"bazel query failed: {result.stderr}")

    return result.stdout


def run_bazel_aquery():
    print(
        "Running bazel aquery to find actually-linked dependencies...",
        file=sys.stderr,
    )

    cmd = [
        BAZEL,
        "--batch",
        "aquery",
        'outputs(".*envoy$", //:envoy)',
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"bazel aquery failed: {result.stderr}")

    return result.stdout


def parse_http_archive_calls(query_output):
    print("Parsing http_archive calls...", file=sys.stderr)

    repositories = {}

    # Query output is technically Starlark but also valid Python - parse the whole thing as a module
    tree = ast.parse(query_output)

    # Walk the AST and find all Call nodes with func name 'http_archive'
    for node in ast.walk(tree):
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
            call = node.value

            if isinstance(call.func, ast.Name) and call.func.id == "http_archive":
                # Extract keyword arguments into a dict
                repo_data = {}
                for keyword in call.keywords:
                    key = keyword.arg
                    value_node = keyword.value

                    # Extract value based on its type
                    if isinstance(value_node, ast.Constant):
                        repo_data[key] = value_node.value
                    elif isinstance(value_node, ast.List):
                        repo_data[key] = [
                            elem.value if isinstance(elem, ast.Constant) else str(elem)
                            for elem in value_node.elts
                        ]
                    elif isinstance(value_node, ast.Dict):
                        # Handle dict values
                        repo_data[key] = {
                            k.value if isinstance(k, ast.Constant) else str(k): v.value
                            if isinstance(v, ast.Constant)
                            else str(v)
                            for k, v in zip(value_node.keys, value_node.values)
                        }

                if "name" in repo_data:
                    repositories[repo_data["name"]] = repo_data

    print(f"Found {len(repositories)} dependencies from bazel query", file=sys.stderr)
    return repositories


def parse_aquery_output(aquery_output):
    """Parse aquery output to extract linked dependencies."""
    print("Parsing aquery Linking action output...", file=sys.stderr)

    # format is something like:
    # action 'Linking envoy'
    #   Mnemonic: CppLink
    #   Target: //:envoy
    #   ...
    #   Inputs: [ /path/to/file1, /path/to/file2, /path/to/file3, ...]
    #
    # Find the first Linking action and extract its Inputs line contents between square brackets
    inputs_str = None
    match = re.search(
        r"action 'Linking [^']*'.*?\n  Inputs: \[([^\]]+)\]", aquery_output, re.DOTALL
    )
    if match:
        inputs_str = match.group(1).strip()
    if not inputs_str:
        raise RuntimeError(
            "Could not find Linking action with Inputs line in aquery output"
        )

    # Extract external/* patterns from input files.
    external_deps = set()
    input_files = [f.strip() for f in inputs_str.split(",") if f.strip()]
    for input_file in input_files:
        matches = re.findall(r"external/([^/]+)", input_file)
        external_deps.update(matches)

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
    # Try strip_prefix first (e.g., "protobuf-3.21.12" or "re2-2024-07-02")
    if "strip_prefix" in repo_data:
        strip = repo_data["strip_prefix"]
        # Look for semantic version patterns
        version_match = re.search(r"[-_]v?(\d+\.\d+(?:\.\d+)?(?:\.\d+)?)", strip)
        if version_match:
            return version_match.group(1)
        # Look for date-based version patterns (YYYY-MM-DD)
        date_match = re.search(r"[-_](\d{4}-\d{2}-\d{2})", strip)
        if date_match:
            return date_match.group(1)

    urls = get_urls(repo_data)

    # Try URLs (e.g., "releases/download/v3.21.12/" or "releases/download/2024-07-02/")
    for url in urls:
        # Look for semantic version patterns
        version_match = re.search(r"/v?(\d+\.\d+(?:\.\d+)?(?:\.\d+)?)", url)
        if version_match:
            return version_match.group(1)
        # Look for date-based version patterns (YYYY-MM-DD)
        date_match = re.search(r"/(\d{4}-\d{2}-\d{2})", url)
        if date_match:
            return date_match.group(1)

    # Try commit SHA in URLs (e.g., "archive/{sha}.tar.gz")
    for url in urls:
        commit_match = re.search(r"/([a-f0-9]{40})(?:\.|/)", url)
        if commit_match:
            print(
                f"WARNING: Using commit SHA as version for {repo_data}",
                file=sys.stderr,
            )
            return commit_match.group(1)[:12]  # Short SHA

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
        repo_data = all_repositories.get(dep, {})
        urls = get_urls(repo_data)

        if not repo_data:
            print(f"WARNING: No metadata found for {dep}. Skipping.", file=sys.stderr)
            continue

        package = {
            "SPDXID": f"SPDXRef-Package-{i}",
            "name": dep,
            "versionInfo": extract_version_from_metadata(repo_data),
            "downloadLocation": urls[0] if urls else "NOASSERTION",
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": "NOASSERTION",
            "copyrightText": "NOASSERTION",
            "externalRefs": [
                {
                    "referenceCategory": "PACKAGE-MANAGER",
                    "referenceType": "purl",
                    "referenceLocator": create_purl(dep, repo_data, version),
                }
            ],
        }

        spdx_doc["packages"].append(package)

    print(
        f"Found {len(spdx_doc['packages'])} dependencies with metadata", file=sys.stderr
    )
    return spdx_doc


def main():
    if len(sys.argv) != 3:
        print("Usage: python envoy-bazel-to-spdx.py <name> <version>", file=sys.stderr)
        sys.exit(1)

    name = sys.argv[1]
    version = sys.argv[2]

    # Get all dependencies with bazel query
    query_output = run_bazel_query()
    all_repositories = parse_http_archive_calls(query_output)

    # Get actually-linked dependencies with aquery
    aquery_output = run_bazel_aquery()
    linked_deps = parse_aquery_output(aquery_output)

    # Generate SPDX with filtered deps
    spdx_doc = generate_spdx(linked_deps, all_repositories, name, version)

    json.dump(spdx_doc, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
