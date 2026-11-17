#!/bin/bash
set -eux -o pipefail

test -n "${SOURCE_DIR}"
test -n "${PHP_SRC_VERSION}"
test -n "${REDIS_VERSION}"
test -n "${MEMCACHED_VERSION}"
test -n "${BUNDLED_LIBGD_VERSION}"

src="${SOURCE_DIR}/php-src"
mkdir -p "$src"
tar xf "${SOURCE_DIR}/php-${PHP_SRC_VERSION}.tar.xz" -C "${SOURCE_DIR}"
cp -a "${SOURCE_DIR}/php-${PHP_SRC_VERSION}/." "$src"

build_ext() {
  local ext=$1
  shift
  cd "${src}/ext/${ext}"
  phpize
  ./configure "$@"
  make -j"$(nproc)"
  make install
}

build_ext gd --with-freetype --with-jpeg
build_ext zip
build_ext exif
build_ext bcmath
if command -v dpkg-architecture >/dev/null 2>&1; then
  build_ext ldap --with-libdir="lib/$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"
else
  build_ext ldap
fi
build_ext pdo_mysql --with-pdo-mysql=mysqlnd

build_pecl() {
  local name=$1
  shift
  local dir="${SOURCE_DIR}/pecl/${name}"
  mkdir -p "$dir"
  tar xf "${SOURCE_DIR}/${name}.tgz" -C "$dir" --strip-components=1
  cd "$dir"
  phpize
  ./configure "$@"
  make -j"$(nproc)"
  make install
}

build_pecl redis
build_pecl memcached

ext_dir="$(php-config --extension-dir)"
out=/usr/lib/php/extensions
mkdir -p "$out"
for ext in gd zip exif bcmath ldap pdo_mysql redis memcached; do
  test -s "${ext_dir}/${ext}.so"
  cp -a "${ext_dir}/${ext}.so" "${out}/${ext}.so"
done

# gd_info() prints a fixed display string, so assert the libgd version in the shipped gd.so itself.
grep -aqF "${BUNDLED_LIBGD_VERSION}" "${out}/gd.so"

assert_php_ext() {
  local ext=$1
  local want=$2
  local got
  got="$(php -n -d "extension=${out}/${ext}.so" -r "echo phpversion('${ext}');")"
  test -n "$got"
  test "$got" = "$want"
}

assert_php_ext gd "${PHP_SRC_VERSION}"
# phpversion('zip') reports the linked libzip version, not the PHP source
# version. The extension code is the PHP tree we compiled; libzip itself is
# the distro package the .so links.
zip_ver="$(php -n -d "extension=${out}/zip.so" -r "echo phpversion('zip');")"
test -n "$zip_ver"
assert_php_ext exif "${PHP_SRC_VERSION}"
assert_php_ext bcmath "${PHP_SRC_VERSION}"
assert_php_ext ldap "${PHP_SRC_VERSION}"
assert_php_ext pdo_mysql "${PHP_SRC_VERSION}"
assert_php_ext redis "${REDIS_VERSION}"
assert_php_ext memcached "${MEMCACHED_VERSION}"
