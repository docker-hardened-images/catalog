"""Regression tests for bin/envoy-bazel-to-spdx.py. They need no Bazel.

Run with: python3 -m unittest discover -s package/main/envoy/tests -v

Fixture provenance:
  captured      attribute values copied from the CI build log of the 1.40.2
                arm64 leaf (the script's own WARNING lines print the parsed
                `mod show_repo` data)
  reconstructed text layout of `mod show_repo`/`query` output, or inputs for
                repositories whose output the log does not contain, rebuilt
                from the Envoy 1.37.11 to 1.40.2 and toolshed bazel-v0.5.3 sources
"""

import importlib.util
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "bin", "envoy-bazel-to-spdx.py"
)
spec = importlib.util.spec_from_file_location("envoy_bazel_to_spdx", SCRIPT)
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)

LUAJIT_COMMIT = "871db2c84ecefd70a850e03a6c340214a81739f0"
HTTP_PARSER_COMMIT = "4f15b7d510dc7c6361a26a7c6d2f7c3a17f8d878"
REGISTRY = (
    "https://raw.githubusercontent.com/envoyproxy/bazel-registry/"
    "8ef390e133ec41491e397681c91c30e9cda1395a/modules"
)

# captured values (1.40.2 arm64), reconstructed text layout
LUAJIT_SHOW_REPO = f"""\
## luajit@0.0.0-260126-871db2c.envoy:
# <builtin>
http_archive(
  name = "luajit+",
  urls = ["https://github.com/LuaJIT/LuaJIT/archive/871db2c.tar.gz"],
  integrity = "sha256-qz8W2C32lGVDVlz7DSgQ04fXmjpD4EMWlbA0ZhiOJoA=",
  strip_prefix = "LuaJIT-{LUAJIT_COMMIT}",
  remote_file_urls = {{"BUILD.bazel": ["{REGISTRY}/luajit/0.0.0-260126-871db2c.envoy/overlay/BUILD.bazel"]}},
  remote_module_file_urls = ["{REGISTRY}/luajit/0.0.0-260126-871db2c.envoy/MODULE.bazel"],
  remote_patches = {{}},
  remote_patch_strip = 0,
)
"""

# captured values (1.40.2 arm64), reconstructed text layout
BROTLI_SHOW_REPO = f"""\
## brotli@1.2.0-260930-42a2ed4.envoy:
# <builtin>
http_archive(
  name = "brotli+",
  urls = ["https://github.com/google/brotli/archive/42a2ed4355bc6287da6bb6319f090b499cba4550.tar.gz"],
  strip_prefix = "brotli-42a2ed4355bc6287da6bb6319f090b499cba4550",
  remote_module_file_urls = ["{REGISTRY}/brotli/1.2.0-260930-42a2ed4.envoy/MODULE.bazel"],
)
"""

# reconstructed: the rule's attributes come from toolshed bazel-v0.5.3
# (v8/wee8_prebuilt.bzl, BINS_RELEASE 0.2.23), the sha256 values from its
# versions.bzl (the aarch64 one was also checked against the downloaded archive)
WEE8_SHOW_REPO = """\
## @@envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64:
# Rule wee8_prebuilt defined at (most recent call site first):
load("@@envoy_toolshed+//v8:wee8_prebuilt.bzl", "wee8_prebuilt")
wee8_prebuilt(
  name = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64",
  version = "0.2.23",
  sha256 = "d0c4cdc9e5c5e3784ac5ec0deb8c7fdb76e9f46bc20713f53ffbf439ddfeefa8",
  arch = "aarch64",
  stdlib = "libcxx",
)
## @@envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_x86_64:
wee8_prebuilt(
  name = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_x86_64",
  version = "0.2.23",
  sha256 = "7165b2a61a92c48677b07ccf1c123f9dd3a965911bafaecb2ba1320aa5a527a2",
  arch = "x86_64",
  stdlib = "libcxx",
)
## @@envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_x86_64_libstdcxx:
wee8_prebuilt(
  name = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_x86_64_libstdcxx",
  version = "0.2.23",
  sha256 = "efb0d51c227410ca6cf22af4f4e8c1a294a7753952c64bb3d79c3ef043f28022",
  arch = "x86_64",
  stdlib = "libstdcxx",
)
"""

# captured from the archive's include/v8-version.h (toolshed bins-v0.2.23)
V8_HEADER = """\
#ifndef V8_INCLUDE_VERSION_H_
#define V8_INCLUDE_VERSION_H_
#define V8_MAJOR_VERSION 14
#define V8_MINOR_VERSION 6
#define V8_BUILD_NUMBER 202
#define V8_PATCH_LEVEL 10
#define V8_IS_CANDIDATE_VERSION 0
#endif  // V8_INCLUDE_VERSION_H_
"""

# reconstructed: `query --output=build` of a WORKSPACE line (Envoy 1.37.11,
# repository_locations.bzl v8 and com_github_luajit_luajit entries)
WORKSPACE_QUERY = f"""\
# /root/.cache/bazel/external/WORKSPACE:12:1
http_archive(
  name = "v8",
  urls = ["https://github.com/v8/v8/archive/refs/tags/13.8.258.26.tar.gz"],
  sha256 = "4ffc27074d3f79e8e6401e390443dcf02755349002be4a1b01e72a3cd9457d15",
  strip_prefix = "v8-13.8.258.26",
)
http_archive(
  name = "com_github_luajit_luajit",
  urls = ["https://github.com/LuaJIT/LuaJIT/archive/{LUAJIT_COMMIT}.tar.gz"],
  strip_prefix = "LuaJIT-{LUAJIT_COMMIT}",
)
http_archive(
  name = "com_google_protobuf",
  urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v3.21.12/protobuf-3.21.12.tar.gz"],
  strip_prefix = "protobuf-3.21.12",
)
http_archive(
  name = "com_googlesource_code_re2",
  urls = ["https://github.com/google/re2/archive/2024-07-02.tar.gz"],
  strip_prefix = "re2-2024-07-02",
)
"""


def link_inputs(*repos):
    inputs = ", ".join(f"bazel-out/k8-opt/bin/external/{r}/lib.a" for r in repos)
    return (
        "action 'Linking source/exe/envoy-static'\n"
        "  Mnemonic: CppLink\n"
        "  Target: //source/exe:envoy-static\n"
        f"  Inputs: [{inputs}]\n"
        "  Outputs: [bazel-out/k8-opt/bin/source/exe/envoy-static]\n"
    )


def run_quiet(func, *args, **kwargs):
    with redirect_stderr(io.StringIO()):
        return func(*args, **kwargs)


def no_source(path):
    return None


def resolve(deps, repositories, module_versions=None, header=V8_HEADER, source=no_source):
    return run_quiet(
        tool.resolve_components,
        deps,
        repositories,
        module_versions or {},
        source,
        lambda dep: header,
    )


def parse(text):
    return run_quiet(tool.parse_repository_calls, text)


def by_name(components):
    return {c["name"]: c for c in components}


class LuaJitTest(unittest.TestCase):
    def test_short_commit_url_resolves_to_full_commit(self):
        repos = parse(LUAJIT_SHOW_REPO)
        self.assertEqual(repos["luajit+"]["_rule"], "http_archive")
        version = run_quiet(tool.extract_version_from_metadata, repos["luajit+"])
        self.assertEqual(version, LUAJIT_COMMIT)

    def test_component_has_concrete_identity(self):
        repos = parse(LUAJIT_SHOW_REPO)
        repos["luajit+"]["_module_name"] = "luajit"
        component = run_quiet(
            tool.resolve_dependency, "luajit+", repos, {}, no_source, lambda d: None
        )
        self.assertEqual(component["name"], "luajit")
        self.assertEqual(component["version"], LUAJIT_COMMIT)
        self.assertEqual(component["purl"], f"pkg:github/LuaJIT/LuaJIT@{LUAJIT_COMMIT}")
        self.assertNotIn("UNKNOWN", json.dumps(component))

    def test_short_commit_without_full_commit_in_strip_prefix_fails(self):
        repo = parse(LUAJIT_SHOW_REPO)["luajit+"]
        repo["strip_prefix"] = "LuaJIT-871db2c"
        with self.assertRaisesRegex(tool.SbomError, "cannot be verified"):
            run_quiet(tool.extract_version_from_metadata, repo)

    def test_strip_prefix_commit_must_start_with_short_commit(self):
        repo = parse(LUAJIT_SHOW_REPO)["luajit+"]
        repo["strip_prefix"] = "LuaJIT-" + "0" * 40
        with self.assertRaisesRegex(tool.SbomError, "cannot be verified"):
            run_quiet(tool.extract_version_from_metadata, repo)

    def test_module_version_naming_another_commit_fails(self):
        repo = parse(LUAJIT_SHOW_REPO)["luajit+"]
        repo["remote_module_file_urls"] = [
            f"{REGISTRY}/luajit/0.0.0-260126-deadbee.envoy/MODULE.bazel"
        ]
        with self.assertRaisesRegex(tool.SbomError, "module version"):
            run_quiet(tool.extract_version_from_metadata, repo)

    def test_workspace_full_commit_url_gives_same_identity(self):
        repos = parse(WORKSPACE_QUERY)
        component = run_quiet(
            tool.resolve_dependency, "com_github_luajit_luajit", repos, {}, no_source, lambda d: None
        )
        self.assertEqual(component["purl"], f"pkg:github/LuaJIT/LuaJIT@{LUAJIT_COMMIT}")


class Wee8Test(unittest.TestCase):
    def setUp(self):
        self.repos = parse(WEE8_SHOW_REPO)

    def resolve_one(self, dep, header=V8_HEADER, module_versions=None):
        return run_quiet(
            tool.resolve_dependency,
            dep,
            self.repos,
            module_versions or {},
            no_source,
            lambda d: header,
        )

    def test_rule_is_parsed_with_its_attributes(self):
        repo = self.repos["envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64"]
        self.assertEqual(repo["_rule"], "wee8_prebuilt")
        self.assertEqual(repo["arch"], "aarch64")

    def test_both_architectures_resolve_to_the_same_v8_identity(self):
        for arch, sha in (
            ("aarch64", "d0c4cdc9e5c5e3784ac5ec0deb8c7fdb76e9f46bc20713f53ffbf439ddfeefa8"),
            ("x86_64", "7165b2a61a92c48677b07ccf1c123f9dd3a965911bafaecb2ba1320aa5a527a2"),
        ):
            with self.subTest(arch=arch):
                dep = f"envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_{arch}"
                component = self.resolve_one(dep)
                self.assertEqual(component["name"], "v8")
                self.assertEqual(component["version"], "14.6.202.10")
                self.assertEqual(component["purl"], "pkg:github/v8/v8@14.6.202.10")
                self.assertEqual(component["sha256"], sha)
                self.assertEqual(
                    component["download"],
                    "https://github.com/envoyproxy/toolshed/releases/download/bins-v0.2.23/"
                    f"v8-wee8-14.6.202.10-linux-{arch}.tar.xz",
                )

    def test_libstdcxx_flavor_download_name(self):
        dep = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_x86_64_libstdcxx"
        self.assertTrue(self.resolve_one(dep)["download"].endswith("linux-x86_64-libstdcxx.tar.xz"))

    def test_locked_module_is_used_when_the_header_is_unreadable(self):
        dep = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64"
        component = self.resolve_one(dep, header=None, module_versions={"v8": "14.6.202.10.envoy"})
        self.assertEqual(component["version"], "14.6.202.10")

    def test_header_wins_over_a_different_locked_module(self):
        dep = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64"
        component = self.resolve_one(dep, module_versions={"v8": "14.0.0.1.envoy"})
        self.assertEqual(component["version"], "14.6.202.10")

    def test_no_version_source_fails(self):
        dep = "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64"
        with self.assertRaisesRegex(tool.SbomError, "cannot determine the linked V8"):
            self.resolve_one(dep, header="// no macros", module_versions={})

    def test_repository_without_metadata_still_resolves(self):
        component = run_quiet(
            tool.resolve_dependency,
            "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64",
            {},
            {},
            no_source,
            lambda d: V8_HEADER,
        )
        self.assertEqual(component["purl"], "pkg:github/v8/v8@14.6.202.10")
        self.assertTrue(component["download"].startswith("https://github.com/v8/v8/"))

    def test_workspace_source_build_gives_the_same_purl_shape(self):
        repos = parse(WORKSPACE_QUERY)
        component = run_quiet(tool.resolve_dependency, "v8", repos, {}, no_source, lambda d: None)
        self.assertEqual(component["purl"], "pkg:github/v8/v8@13.8.258.26")

    def test_header_parser(self):
        self.assertEqual(tool.parse_v8_version_header(V8_HEADER), "14.6.202.10")
        self.assertIsNone(tool.parse_v8_version_header("#define V8_MAJOR_VERSION 1"))
        self.assertEqual(tool.locked_v8_version({"v8": "14.6.202.10.envoy"}), "14.6.202.10")
        self.assertIsNone(tool.locked_v8_version({}))


class UnresolvedTest(unittest.TestCase):
    def test_repository_without_metadata_fails(self):
        with self.assertRaisesRegex(tool.SbomError, "mystery_dep: no repository metadata"):
            resolve(["mystery_dep"], {})

    def test_archive_without_version_fails_instead_of_unknown(self):
        repos = {"odd": {"name": "odd", "urls": ["https://example.com/odd.tar.gz"], "_rule": "http_archive"}}
        with self.assertRaisesRegex(tool.SbomError, "odd: no version"):
            resolve(["odd"], repos)

    def test_unhandled_repository_rule_fails(self):
        repos = {"odd": {"name": "odd", "_rule": "git_repository"}}
        with self.assertRaisesRegex(tool.SbomError, "git_repository is not handled"):
            resolve(["odd"], repos)

    def test_all_problems_are_reported_together(self):
        with self.assertRaises(tool.SbomError) as caught:
            resolve(["a_dep", "b_dep"], {})
        self.assertIn("a_dep", str(caught.exception))
        self.assertIn("b_dep", str(caught.exception))

    def test_missing_required_components_fail(self):
        with self.assertRaises(tool.SbomError) as caught:
            resolve([], {})
        self.assertIn("V8", str(caught.exception))
        self.assertIn("LuaJIT", str(caught.exception))

    def test_toolchain_and_first_party_repositories_are_not_shipped(self):
        for dep in (
            "llvm_toolchain_llvm",
            "bazel_tools",
            "local_config_cc",
            "toolchains_llvm++llvm+llvm_toolchain",
            "envoy_toolshed++llvm_minimal_extension+llvm_minimal_linux_arm64",
            "envoy_toolshed++sysroot_extension+sysroot_linux_amd64",
            "envoy_api",
            "envoy_api+",
        ):
            with self.subTest(dep=dep):
                self.assertIsNotNone(tool.non_shipped_reason(dep))
        self.assertIsNone(tool.non_shipped_reason("luajit+"))
        self.assertIsNone(tool.non_shipped_reason("envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64"))


class ExistingBehaviourTest(unittest.TestCase):
    def test_full_commit_url_resolves_to_the_full_commit(self):
        repos = parse(BROTLI_SHOW_REPO)
        repos["brotli+"]["_module_name"] = "brotli"
        component = run_quiet(tool.resolve_dependency, "brotli+", repos, {}, no_source, lambda d: None)
        commit = "42a2ed4355bc6287da6bb6319f090b499cba4550"
        self.assertEqual(component["version"], commit)
        self.assertEqual(component["purl"], f"pkg:github/google/brotli@{commit}")

    def test_semver_and_date_versions(self):
        repos = parse(WORKSPACE_QUERY)
        proto = run_quiet(tool.resolve_dependency, "com_google_protobuf", repos, {}, no_source, lambda d: None)
        re2 = run_quiet(tool.resolve_dependency, "com_googlesource_code_re2", repos, {}, no_source, lambda d: None)
        self.assertEqual(proto["purl"], "pkg:github/protocolbuffers/protobuf@3.21.12")
        self.assertEqual(re2["version"], "2024-07-02")

    def test_non_github_url_gives_generic_purl(self):
        repo = {"name": "zlib", "urls": ["https://zlib.net/zlib-1.3.1.tar.gz"], "_rule": "http_archive"}
        component = run_quiet(tool.resolve_dependency, "zlib", {"zlib": repo}, {}, no_source, lambda d: None)
        self.assertEqual(component["purl"], "pkg:generic/zlib@1.3.1")

    def test_module_name_is_used_for_bzlmod_repositories(self):
        repos = parse(LUAJIT_SHOW_REPO)
        repos["luajit+"]["_module_name"] = "luajit"
        component = run_quiet(tool.resolve_dependency, "luajit+", repos, {}, no_source, lambda d: None)
        self.assertEqual(component["name"], "luajit")

    def test_foreign_cc_archives_only_map_to_archive_repositories(self):
        repos = parse(WORKSPACE_QUERY)
        repos.update(parse(WEE8_SHOW_REPO))
        found = run_quiet(
            tool.resolve_archive_repos,
            ["bazel-out/k8-opt/bin/external/com_google_protobuf/bazel/foreign_cc/com_google_protobuf/lib/libx.a"],
            repos,
        )
        self.assertEqual(found, {"com_google_protobuf"})


class VendoredTest(unittest.TestCase):
    def test_http_parser_commit_comes_from_the_vendoring_note(self):
        readme = (
            "This is a clone of the [http-parser](https://github.com/nodejs/http-parser)\n"
            f"repo at commit `{HTTP_PARSER_COMMIT}`. See GitHub issue\n"
        )
        component = run_quiet(
            tool.resolve_dependency, "http_parser", {}, {}, lambda path: readme, lambda d: None
        )
        self.assertEqual(component["purl"], f"pkg:github/nodejs/http-parser@{HTTP_PARSER_COMMIT}")

    def test_missing_vendoring_note_fails(self):
        with self.assertRaisesRegex(tool.SbomError, "http_parser"):
            run_quiet(tool.resolve_dependency, "http_parser", {}, {}, no_source, lambda d: None)


class BinaryMarkerTest(unittest.TestCase):
    def check(self, content):
        components = [
            {"name": "v8", "version": "14.6.202.10", "binary_marker": True},
            {"name": "luajit", "version": LUAJIT_COMMIT},
        ]
        with tempfile.NamedTemporaryFile() as binary:
            binary.write(content)
            binary.flush()
            tool.verify_binary_markers(components, binary.name)

    def test_version_present(self):
        self.check(b"\x00junk\x0014.6.202.10\x00junk")

    def test_version_absent_fails(self):
        with self.assertRaisesRegex(tool.SbomError, "v8 14.6.202.10"):
            self.check(b"\x00junk\x0013.8.258.26\x00")


class MainTest(unittest.TestCase):
    """The whole script with Bazel's answers replaced by canned output."""

    def run_main(self, aquery, graph, show_repo, env=None):
        calls = []

        def fake_bazel(description, *args):
            calls.append(args)
            return {"aquery": aquery, "graph": graph, "show_repo": show_repo}[
                {"aquery": "aquery", "mod": "graph" if args[1] == "graph" else "show_repo"}[args[0]]
            ]

        out = io.StringIO()
        with tempfile.TemporaryDirectory() as source:
            os.makedirs(os.path.join(source, "bazel/external/http_parser"))
            with open(os.path.join(source, "bazel/external/http_parser/README.md"), "w") as readme:
                readme.write(
                    "[http-parser](https://github.com/nodejs/http-parser)\n"
                    f"repo at commit `{HTTP_PARSER_COMMIT}`.\n"
                )
            with mock.patch.object(tool, "run_bazel", fake_bazel), mock.patch.object(
                tool, "bazel_header_reader", lambda: lambda dep: V8_HEADER
            ), mock.patch.object(tool.os, "getcwd", lambda: source), mock.patch.dict(
                os.environ, env or {}, clear=False
            ), mock.patch.object(
                tool.sys, "argv", ["x", "envoy-dependencies", "1.40.2", "-c", "opt"]
            ), redirect_stdout(out), redirect_stderr(io.StringIO()):
                tool.main()
        return json.loads(out.getvalue())

    GRAPH = json.dumps(
        {
            "key": "<root>",
            "name": "envoy",
            "version": "",
            "dependencies": [
                {"key": "luajit@0.0.0-260126-871db2c.envoy", "name": "luajit",
                 "version": "0.0.0-260126-871db2c.envoy"},
                {"key": "v8@14.6.202.10.envoy", "name": "v8", "version": "14.6.202.10.envoy"},
            ],
            "indirectDependencies": [],
        }
    )

    def test_bzlmod_line_produces_a_complete_sbom(self):
        aquery = link_inputs(
            "luajit+",
            "envoy_toolshed++wee8_prebuilt_extension+wee8_prebuilt_aarch64",
            "envoy_toolshed++llvm_minimal_extension+llvm_minimal_linux_arm64",
            "envoy_toolshed++sysroot_extension+sysroot_linux_arm64",
            "toolchains_llvm++llvm+llvm_toolchain",
            "envoy_api+",
            "http_parser",
        )
        doc = self.run_main(aquery, self.GRAPH, LUAJIT_SHOW_REPO + WEE8_SHOW_REPO)
        purls = sorted(p["externalRefs"][0]["referenceLocator"] for p in doc["packages"])
        self.assertEqual(
            purls,
            [
                f"pkg:github/LuaJIT/LuaJIT@{LUAJIT_COMMIT}",
                f"pkg:github/nodejs/http-parser@{HTTP_PARSER_COMMIT}",
                "pkg:github/v8/v8@14.6.202.10",
            ],
        )
        self.assertNotIn("UNKNOWN", json.dumps(doc))

    def test_unresolvable_linked_repository_exits_non_zero_and_writes_nothing(self):
        aquery = link_inputs("luajit+", "no_such_repo+")
        out = io.StringIO()
        with mock.patch.object(tool, "run_bazel", lambda d, *a: aquery if a[0] == "aquery" else
                               (self.GRAPH if a[1] == "graph" else LUAJIT_SHOW_REPO)), \
                mock.patch.object(tool, "bazel_header_reader", lambda: lambda dep: V8_HEADER), \
                mock.patch.object(tool.sys, "argv", ["x", "n", "1"]), \
                redirect_stdout(out), redirect_stderr(io.StringIO()) as err:
            with self.assertRaises(SystemExit) as caught:
                tool.main()
        self.assertEqual(caught.exception.code, 1)
        self.assertEqual(out.getvalue(), "")
        self.assertIn("no_such_repo+", err.getvalue())


if __name__ == "__main__":
    unittest.main()
