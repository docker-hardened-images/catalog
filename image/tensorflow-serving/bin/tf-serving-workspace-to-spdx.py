#!/usr/bin/env python3
"""
Parse workspace.bzl to extract dependencies and generate SPDX documents.

This script parses the Starlark file using Python's AST module to identify
http_archive and new_git_repository calls, then constructs SPDX documents with PURLs.

This script is specifically tailored to TensorFlow Serving's dependency structure.
TensorFlow Serving conveniently defines nearly all external dependencies in a single
workspace.bzl file, which enables straightforward parsing. However, this approach
is not generalizable to other Bazel projects, which can organize dependencies
across multiple Starlark files with arbitrary import structures and nesting.

Bazel provides limited native tooling for generating comprehensive SBOMs. While some
SBOM generation capabilities exist (such as rules_license and third-party tools),
they typically require upstream projects to adopt specific Bazel rules and patterns,
which is not universally practiced.

Assumptions:
- All relevant dependencies are defined in tensorflow_serving/workspace.bzl
- Dependencies use either http_archive or new_git_repository rules
- Dependency sources are hosted on GitHub
- Version information can be extracted from URLs or must be manually mapped in
  KNOWN_COMMIT_VERSIONS when commit hashes are used
- License information is manually curated in KNOWN_LICENSES
- The Starlark syntax is similar enough to Python for ast.parse() to handle
- Dependencies not included in the final binary are explicitly listed in SKIP_DEPS
"""

from dataclasses import dataclass
import ast
import json
import re

# These are dependencies that are not included in the final binary
SKIP_DEPS = ["bazel_skylib", "rules_pkg"]

# Known commit-to-version mappings
# Add entries here when a dependency uses a commit hash without a version tag
KNOWN_COMMIT_VERSIONS = {
    # darts_clone: 0.32 is value of DARTS_VERSION in include/darts.h at this commit
    "e40ce4627526985a7767444b6ed6893ab6ff8983": "0.32+e40ce462",
    # com_google_glog: commit between v0.3.5 and v0.4.0, using 0.3.5 as base version
    "028d37889a1e80e8a07da1b8945ac706259e5fd8": "0.3.5+028d3788",
    # org_boost: commit is tagged as 1.75.0
    "b7b1371294b4bdfc8d85e49236ebced114bc1d8f": "1.75.0",
}

# Known licenses for each dependency (by dependency name)
KNOWN_LICENSES = {
    "com_github_tencent_rapidjson": "MIT",
    "com_github_libevent_libevent": "BSD-3-Clause",
    "icu": "Unicode-3.0",
    "org_tensorflow_text": "Apache-2.0",
    "com_google_sentencepiece": "Apache-2.0",
    "darts_clone": "BSD-2-Clause",
    "com_google_glog": "BSD-3-Clause",
    "org_tensorflow_decision_forests": "Apache-2.0",
    "ydf": "Apache-2.0",
    "org_boost": "BSL-1.0",
}


class DependencyExtractor(ast.NodeVisitor):
    def __init__(self):
        self.dependencies = []

    def visit_Call(self, node):
        """Visit function call nodes to find http_archive and new_git_repository."""
        if isinstance(node.func, ast.Name):
            if node.func.id in ("http_archive", "new_git_repository"):
                dep_info = self._extract_dependency_info(node)
                if dep_info:
                    self.dependencies.append(dep_info)
        self.generic_visit(node)

    def _extract_dependency_info(self, node) -> dict | None:
        """Extract kwargs from a function call node."""
        dep_type = node.func.id
        info = {"type": dep_type}

        for keyword in node.keywords:
            if keyword.arg:
                value = self._extract_value(keyword.value)
                info[keyword.arg] = value

        return info

    def _extract_value(self, node):
        if isinstance(node, ast.Constant):
            return node.value
        elif isinstance(node, ast.List):
            return [self._extract_value(elt) for elt in node.elts]
        return None


def extract_version_from_url(url: str) -> str | None:
    patterns = [
        r"(\d+\.\d+\.\d+)",
        r"/release-(\d+-\d+)",  # e.g. release-64-2 (icu)
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def get_version_from_commit(commit: str, dep_name: str) -> str:
    if commit in KNOWN_COMMIT_VERSIONS:
        return KNOWN_COMMIT_VERSIONS[commit]
    else:
        raise ValueError(
            f"Unknown version for commit {commit} in dependency '{dep_name}'. "
            f"Please add this commit to KNOWN_COMMIT_VERSIONS"
            f"with its corresponding version."
        )


@dataclass
class GitHubInfo:
    owner: str
    repo: str


def parse_github_url(url: str) -> GitHubInfo | None:
    match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
    if match:
        return GitHubInfo(owner=match.group(1), repo=match.group(2))
    return None


def create_spdx_package(dep_info: dict) -> dict:
    """Create an SPDX package entry from dependency information."""
    dep_type = dep_info["type"]
    name = dep_info["name"]

    if dep_type == "http_archive":
        url = dep_info.get("url")
        urls = dep_info.get("urls")
        if urls and isinstance(urls, list):
            # Use the URL that is a github URL
            url = next((u for u in urls if parse_github_url(u)), None)

        if not url:
            raise ValueError(f"URL is missing for http_archive dependency '{name}'")

        github_info = parse_github_url(url)
        if not github_info:
            raise ValueError(
                f"URL is not a GitHub URL for http_archive dependency '{name}'"
            )

        version = extract_version_from_url(url)
        if not version:
            # Try to extract commit from URL
            commit_match = re.search(r"([a-f0-9]{40})", url)
            if not commit_match:
                raise ValueError(
                    f"Cannot find version or commit for http_archive dependency '{name}'"
                )
            commit = commit_match.group(1)
            version = get_version_from_commit(commit, name)
    elif dep_type == "new_git_repository":
        github_info = parse_github_url(dep_info["remote"])
        if not github_info:
            raise ValueError(
                f"new_git_repository dependency '{name}' is not a GitHub repository"
            )
        version = get_version_from_commit(dep_info["commit"], name)
    else:
        raise ValueError(
            f"Unsupported dependency type '{dep_type}' for dependency '{name}'"
        )

    if not version:
        raise ValueError(
            f"Could not determine version for http_archive dependency '{name}'"
        )

    purl = f"pkg:github/{github_info.owner}/{github_info.repo}@{version}"
    license = KNOWN_LICENSES.get(name, "NOASSERTION")

    return {
        "name": name,
        "SPDXID": f"SPDXRef-{name}",
        "versionInfo": version,
        "filesAnalyzed": False,
        "licenseConcluded": "NOASSERTION",
        "licenseDeclared": license,
        "externalRefs": [
            {
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": purl,
            }
        ],
    }


def main():
    with open("tensorflow_serving/workspace.bzl", "r") as f:
        content = f.read()

    # Parse as Python AST (Starlark is similar enough to Python for basic parsing)
    try:
        tree = ast.parse(content)
    except SyntaxError as e:
        print(f"Error parsing file: {e}")
        return

    extractor = DependencyExtractor()
    extractor.visit(tree)

    packages = []
    for dep in extractor.dependencies:
        if dep["name"] in SKIP_DEPS:
            continue
        packages.append(create_spdx_package(dep))

    # Create single SPDX document with all packages
    spdx_document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": "SPDX document for TensorFlow Serving dependencies",
        "documentNamespace": "tensorflow-serving-dependencies",
        "creationInfo": {
            "creators": ["Organization: Docker, Inc.", "Tool: dhi/build"],
            "created": "1970-01-01T00:00:00Z",
        },
        "packages": packages,
    }

    print(json.dumps(spdx_document, indent=2))


if __name__ == "__main__":
    main()
