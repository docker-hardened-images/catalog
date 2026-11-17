#!/bin/bash
# Builds the ros_core and ros_base closure with colcon at its final prefix, then splits the
# install into the runtime tree and the -dev tree for dhi/build-pkg.
# Inputs: SOURCE_DIR (src/<owner>/<repo>, mcap/, optional stage1/), TARGET_DIR, ROS_DISTRO,
# ROS_PACKAGES, ROS_IGNORE_PACKAGES, ROS_DEV_PACKAGES.
set -euo pipefail

prefix="/opt/ros/${ROS_DISTRO}"
build="${SOURCE_DIR}/build"

# mcap_vendor applies these to its FetchContent download, which FETCHCONTENT_SOURCE_DIR_MCAP replaces.
for p in "${SOURCE_DIR}"/src/ros2/rosbag2/mcap_vendor/patches/*.patch; do
  [ -f "${p}" ] || continue
  patch -d "${SOURCE_DIR}/mcap" -p3 < "${p}"
done

# Libraries the distro does not package, built into the prefix so the *_vendor packages find
# them instead of downloading their own copies.
if [ -d "${SOURCE_DIR}/stage1" ]; then
  colcon build \
    --base-paths "${SOURCE_DIR}/stage1" \
    --merge-install \
    --build-base "${SOURCE_DIR}/build-stage1" \
    --install-base "${prefix}" \
    --parallel-workers "$(nproc)" \
    --event-handlers console_cohesion+ \
    --cmake-args \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTING=OFF \
      -DBUILD_SHARED_LIBS=ON \
      -DFOONATHAN_MEMORY_BUILD_EXAMPLES=OFF \
      -DFOONATHAN_MEMORY_BUILD_TESTS=OFF \
      --no-warn-unused-cli
  # python_orocos_kdl hard-codes dist-packages; the prefix's PYTHONPATH names site-packages.
  site="${prefix}/lib/python$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')/site-packages"
  mkdir -p "${site}"
  for f in "${site%/site-packages}"/dist-packages/*; do
    [ -e "${f}" ] || continue
    mv "${f}" "${site}/"
  done
  rmdir "${site%/site-packages}/dist-packages" 2> /dev/null || true
  set +u
  # shellcheck disable=SC1091
  . "${prefix}/local_setup.sh"
  set -u
  export PYTHONPATH="${site}${PYTHONPATH:+:${PYTHONPATH}}"
fi

# shellcheck disable=SC2086
colcon build \
  --base-paths "${SOURCE_DIR}/src" \
  --packages-up-to ${ROS_PACKAGES} \
  --packages-ignore ${ROS_IGNORE_PACKAGES} \
  --merge-install \
  --build-base "${build}" \
  --install-base "${prefix}" \
  --parallel-workers "$(nproc)" \
  --event-handlers console_cohesion+ \
  --cmake-args \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DSECURITY=ON \
    -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
    -DFETCHCONTENT_SOURCE_DIR_MCAP="${SOURCE_DIR}/mcap" \
    --no-warn-unused-cli

runtime="${TARGET_DIR}${prefix}"
dev="${TARGET_DIR}/dev-staging${prefix}"
mkdir -p "${runtime%/*}" "${dev}"
cp -a "${prefix}" "${runtime}"

# Move one path, relative to the prefix, from the runtime tree into the -dev tree, merging
# directories that already exist there.
to_dev() {
  local rel=$1
  [ -n "${rel}" ] || return 0
  [ -e "${runtime}/${rel}" ] || [ -L "${runtime}/${rel}" ] || return 0
  if [ -d "${runtime}/${rel}" ] && [ ! -L "${runtime}/${rel}" ]; then
    mkdir -p "${dev}/${rel}"
    cp -a "${runtime}/${rel}/." "${dev}/${rel}/"
    rm -rf "${runtime:?}/${rel}"
  else
    mkdir -p "${dev}/$(dirname "${rel}")"
    mv "${runtime}/${rel}" "${dev}/${rel}"
  fi
}

# Build-only packages: their install records, plus the share/<pkg> tree and the colcon package
# marker colcon writes outside those records.
for pkg in ${ROS_DEV_PACKAGES}; do
  for manifest in "${build}/${pkg}/install_manifest.txt" "${build}/${pkg}/install.log"; do
    [ -f "${manifest}" ] || continue
    while IFS= read -r f; do
      to_dev "${f#"${prefix}"/}"
    done < "${manifest}"
  done
  to_dev "share/${pkg}"
  to_dev "share/colcon-core/packages/${pkg}"
done

# Headers, CMake package configs, pkg-config files and static archives of every package. Some
# packages install their CMake config under lib/<pkg>/cmake, and the alpine stage 1 installs into lib64.
cd "${runtime}"
for d in include lib/pkgconfig lib/cmake lib64/pkgconfig lib64/cmake; do
  to_dev "${d}"
done
for d in share lib lib64; do
  [ -d "${d}" ] || continue
  find "${d}" -mindepth 2 -maxdepth 2 -type d -name cmake -print | while IFS= read -r c; do
    to_dev "${c}"
  done
done
find lib -name '*.a' -print | while IFS= read -r f; do
  to_dev "${f}"
done
find . -depth -type d -empty -delete
