#!/bin/bash
# Checks the Bazel graph of an already-built metadata_store_server and copies the
# notices of the bundled externals. Run from the MLMD source root, after the build,
# with the build's output_base and flags.
#
#   BAZEL=<bazel> BAZEL_FLAGS="<build flags>" check-bazel-graph.sh graph <expected-repos.txt>
#   BAZEL=<bazel> check-bazel-graph.sh pin <repo> <sha256> <url-fragment> <generator_function|->
#   BAZEL=<bazel> check-bazel-graph.sh contains <external/relative/path> <fixed-string>
#   BAZEL=<bazel> check-bazel-graph.sh notices <dest-dir>
set -euo pipefail

target=//ml_metadata/metadata_store:metadata_store_server
shims="boringssl libmysqlclient org_sqlite postgresql zlib"

fail() {
  echo "check-bazel-graph: $*" >&2
  exit 1
}

bazel_() {
  "${BAZEL:?}" --batch "$@"
}

external_dir() {
  echo "$(bazel_ info output_base 2>/dev/null)/external"
}

cmd_graph() {
  local expected=$1 labels
  labels=$(mktemp)

  # shellcheck disable=SC2086
  bazel_ cquery ${BAZEL_FLAGS:?} "deps(${target})" --output=label > "${labels}"
  [ -s "${labels}" ] || fail "cquery returned no labels"

  sed -n 's/^@@\{0,1\}\([^/]*\)\/\/.* (null)$/\1/p' "${labels}" | sort -u > /tmp/linked-repos
  sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "${expected}" | sort -u > /tmp/expected-repos
  diff -u /tmp/expected-repos /tmp/linked-repos || fail "source repositories differ from ${expected}"

  for repo in ${shims}; do
    grep -Eq "^@@?${repo}//" "${labels}" || fail "shim @${repo} is not in the graph"
  done
  if grep -E "^@@?(${shims// /|})//.*\.(c|cc|cpp|S) " "${labels}"; then
    fail "a shim repository compiles vendored sources"
  fi
  echo "graph: $(wc -l < /tmp/linked-repos) source repositories match, shims carry no sources"
}

cmd_pin() {
  local repo=$1 sha256=$2 url=$3 origin=$4 rule
  rule=$(bazel_ query "//external:${repo}" --output=build 2>/dev/null)

  grep -qF "sha256 = \"${sha256}\"" <<< "${rule}" || fail "${repo}: sha256 is not ${sha256}"
  grep -E '^\s+urls? = ' <<< "${rule}" | grep -qF "${url}" || fail "${repo}: no url contains ${url}"
  if [ "${origin}" = "-" ]; then
    if grep -q 'generator_function = ' <<< "${rule}"; then
      fail "${repo}: expected a top-level WORKSPACE declaration"
    fi
  else
    grep -qF "generator_function = \"${origin}\"" <<< "${rule}" || fail "${repo}: not declared by ${origin}"
  fi
  echo "pin: ${repo} ${sha256}"
}

cmd_contains() {
  local path=$1 text=$2
  grep -qF "${text}" "$(external_dir)/${path}" || fail "${path} does not contain ${text}"
  echo "contains: ${path}: ${text}"
}

cmd_notices() {
  local dest=$1 ext
  ext=$(external_dir)

  while read -r src dst; do
    install -D -m 0644 "${ext}/${src}" "${dest}/${dst}"
    [ -s "${dest}/${dst}" ] || fail "${dst} is empty"
  done << 'EOF'
com_github_grpc_grpc/LICENSE grpc/LICENSE
com_github_grpc_grpc/NOTICE.txt grpc/NOTICE.txt
com_github_grpc_grpc/third_party/address_sorting/LICENSE grpc/third_party/address_sorting/LICENSE
com_github_grpc_grpc/third_party/xxhash/LICENSE grpc/third_party/xxhash/LICENSE
com_google_protobuf/LICENSE protobuf/LICENSE
com_google_protobuf/third_party/utf8_range/LICENSE protobuf/third_party/utf8_range/LICENSE
com_google_absl/LICENSE abseil-cpp/LICENSE
com_googlesource_code_re2/LICENSE re2/LICENSE
com_google_glog/COPYING glog/COPYING
com_github_gflags_gflags/COPYING.txt gflags/COPYING.txt
envoy_api/LICENSE envoy-data-plane-api/LICENSE
com_github_cncf_xds/LICENSE cncf-xds/LICENSE
com_google_googleapis/LICENSE googleapis/LICENSE
com_envoyproxy_protoc_gen_validate/LICENSE protoc-gen-validate/LICENSE
EOF
  echo "notices: $(find "${dest}" -type f | wc -l) files in ${dest}"
}

cmd=$1
shift
case "${cmd}" in
  graph) cmd_graph "$@" ;;
  pin) cmd_pin "$@" ;;
  contains) cmd_contains "$@" ;;
  notices) cmd_notices "$@" ;;
  *) fail "unknown command ${cmd}" ;;
esac
