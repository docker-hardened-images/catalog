#!/usr/bin/env bash
# Build GHC from the upstream release source tarball with hadrian.
#
# GHC is self-hosting, so the build needs an existing compiler. Upstream's own
# release process uses a previous release's binary distribution for that, and
# hadrian's bootstrap plans pin which versions are usable; a compiler cannot
# build itself. The bootstrap compiler is a build input only and is not shipped.
#
# hadrian itself is a Haskell program and must be built before it can build GHC.
# bootstrap.py resolves every dependency of its pinned plan from
# hadrian/_build/tarballs and verifies each against the plan's own sha256, so
# staging those artefacts keeps the whole build offline.
#
# Expects, from the calling leaf:
#   SOURCE_DIR TARGET_DIR PACKAGE_NAME BOOT_PREFIX BOOT_VERSION GHC_FLAVOUR VERSION
set -eux -o pipefail

nproc_count="$(nproc)"
hadrian_plan="plan-bootstrap-${BOOT_VERSION//./_}.json"

# The bootstrap distribution is itself a bindist, so it needs the same
# configure/make install treatment before its compiler is usable.
mkdir -p "${SOURCE_DIR}/boot"
cd "${SOURCE_DIR}/boot"
tar -xf "${SOURCE_DIR}/boot-ghc.tar.xz" --strip-components=1
./configure --prefix="${BOOT_PREFIX}"
make install
boot_ghc="${BOOT_PREFIX}/bin/ghc"
"${boot_ghc}" --version

cd "${SOURCE_DIR}/ghc-src"

# bootstrap.py reads _build/tarballs relative to its working directory, and
# resolves the three in-tree packages relative to its own location, so it runs
# from hadrian/. That also keeps its _build clear of the GHC build's own _build.
cd hadrian
python3 bootstrap/bootstrap.py \
  --with-compiler "${boot_ghc}" \
  --deps "bootstrap/${hadrian_plan}" \
  --no-archive
cd ..
hadrian_bin="$(pwd)/hadrian/_build/bin/hadrian"

# The release source tarball ships a pre-generated configure, so ./boot is not
# needed here. autoconf is still required later: binary-dist generates the
# bindist's own configure.ac and runs autoreconf over it. GHC 9.14 rejects the
# old --with-ghc= spelling and requires the compiler as a variable assignment.
./configure GHC="${boot_ghc}"

# release is upstream's distribution flavour: it has the same optimised and
# profiled library configuration as perf, and additionally records Haddock
# information in interface files for GHCi's :doc command. binary-dist builds
# the complete documentation set by default (Haddocks, HTML, PDFs and manpage).
"${hadrian_bin}" \
  --directory=. \
  -j"${nproc_count}" \
  --flavour="${GHC_FLAVOUR}" \
  binary-dist

# binary-dist produces a tarball supporting exactly the configure/make install
# workflow, which is the same install step the bindist repackage used.
#
# FIND_LD runs here too, so without --disable-ld-override this configure would
# see the lld the GHC build needs and bake -fuse-ld=lld into the shipped
# settings, making the installed compiler unable to link wherever lld is absent.
# lld stays a build-time tool; the shipped compiler uses the default linker.
mkdir -p "${SOURCE_DIR}/bindist"
cd "${SOURCE_DIR}/bindist"
tar -xf "${SOURCE_DIR}"/ghc-src/_build/bindist/ghc-*.tar.xz --strip-components=1
./configure --prefix="/usr/lib/${PACKAGE_NAME}" --disable-ld-override
make install DESTDIR="${TARGET_DIR}"

python3 "${SOURCE_DIR}/source-metadata.py" sbom \
  --source "${SOURCE_DIR}/ghc-src" \
  --package-root "${TARGET_DIR}/usr/lib/${PACKAGE_NAME}" \
  --output "${TARGET_DIR}/opt/docker/sbom/${PACKAGE_NAME}/.spdx.ghc.json" \
  --version "${VERSION}"
