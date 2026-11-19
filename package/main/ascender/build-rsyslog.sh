#!/bin/bash
# Debian leaf only: builds libestr, libfastjson and rsyslog from their pinned tarballs and stages rsyslogd and
# RSYSLOG_MODULES (README, Debian rsyslog). The leaf's pipeline step sets the variables.
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PACKAGE_LIBDIR:?PACKAGE_LIBDIR is required}"
: "${NOTICE_FILE:?NOTICE_FILE is required}"
: "${RSYSLOG_VERSION:?RSYSLOG_VERSION is required}"
: "${LIBESTR_VERSION:?LIBESTR_VERSION is required}"
: "${LIBFASTJSON_VERSION:?LIBFASTJSON_VERSION is required}"
: "${RSYSLOG_MODULES:?RSYSLOG_MODULES is required}"

build=$(mktemp -d)
stage="${build}/stage"
moddir="${PACKAGE_LIBDIR}/rsyslog"
for name in libestr libfastjson rsyslog; do
  mkdir "${build}/${name}"
  tar -xzf "${SOURCE_DIR}/${name}.tar.gz" --strip-components=1 -C "${build}/${name}"
done

# Debian's hardening flags (dpkg-buildflags prints none here), a RUNPATH to PACKAGE_LIBDIR, and a fixed
# build-directory name in the debug information.
case "$(uname -m)" in
  x86_64) cf_protection=-fcf-protection ;;
  aarch64) cf_protection=-mbranch-protection=standard ;;
  *) echo "no control-flow protection flag for $(uname -m)" >&2; exit 1 ;;
esac
export CFLAGS="-g -O2 -ffile-prefix-map=${build}=. -fstack-protector-strong -fstack-clash-protection ${cf_protection} -Wformat -Werror=format-security"
export CPPFLAGS="-Wdate-time -D_FORTIFY_SOURCE=2"
export LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-rpath,${PACKAGE_LIBDIR}"
export PKG_CONFIG_PATH="${PACKAGE_LIBDIR}/pkgconfig"

for name in libestr libfastjson; do
  (
    cd "${build}/${name}"
    ./configure --prefix=/usr --libdir="${PACKAGE_LIBDIR}" --includedir="${build}/include" --disable-static
    make -j"$(nproc)"
    make check
    make install
  )
done
[ "$(pkg-config --modversion libestr)" = "${LIBESTR_VERSION}" ]
[ "$(pkg-config --modversion libfastjson)" = "${LIBFASTJSON_VERSION}" ]

# Only what Ascender's configurations load; every other default-on feature is off.
(
  cd "${build}/rsyslog"
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir="${PACKAGE_LIBDIR}" \
    --disable-static \
    --enable-imptcp \
    --enable-omhttp \
    --disable-klog \
    --disable-libsystemd \
    --disable-imjournal \
    --disable-uuid \
    --disable-libgcrypt \
    --disable-libyaml \
    --disable-fmhash \
    --disable-fmhttp \
    --disable-mmleefparse \
    --disable-impstats-push \
    --disable-imhttp \
    --disable-mmpstrucdata
  make -j"$(nproc)"
  make install DESTDIR="${stage}"
)

install -D -m 0755 "${stage}/usr/sbin/rsyslogd" "${TARGET_DIR}/usr/sbin/rsyslogd"
# The rsyslog spdx@v1 step records RSYSLOG_VERSION.
have=$("${TARGET_DIR}/usr/sbin/rsyslogd" -v | awk 'NR == 1 { print $2 }')
[ "${have}" = "${RSYSLOG_VERSION}" ] || { echo "rsyslogd reports ${have}, not RSYSLOG_VERSION ${RSYSLOG_VERSION}" >&2; exit 1; }
install -d "${TARGET_DIR}${moddir}"
for module in ${RSYSLOG_MODULES}; do
  install -m 0644 "${stage}${moddir}/${module}.so" "${TARGET_DIR}${moddir}/"
done
for lib in libestr.so.0 libfastjson.so.4; do
  cp -P "${PACKAGE_LIBDIR}/${lib}" "${PACKAGE_LIBDIR}/$(readlink "${PACKAGE_LIBDIR}/${lib}")" "${TARGET_DIR}${PACKAGE_LIBDIR}/"
done

# Licence texts, with the hashtable and atomic.h notices.
notice="${TARGET_DIR}${NOTICE_FILE}"
section() {
  printf '==> %s: %s in %s\n' "$1" "$2" "$3"
}
hashtable=$(for f in hashtable.c hashtable_itr.c; do
  section rsyslog "runtime/${f}" "rsyslog-${RSYSLOG_VERSION}.tar.gz"
  sed -n -e '1p' -e '/Copyright (c) 2002.*Christopher Clark/,/\*\//p' "${build}/rsyslog/runtime/${f}"
  echo
done)
[ "$(printf '%s\n' "${hashtable}" | grep -c 'Redistributions in binary form must reproduce')" -eq 2 ] \
  || { echo "the hashtable licence notices were not found in runtime/hashtable*.c" >&2; exit 1; }
atomic=$(sed -n '/Copyright/,/\*\//p' "${build}/libfastjson/atomic.h")
[[ "${atomic}" == *'Licensed under the Apache License, Version 2.0'* ]] \
  || { echo "the Apache-2.0 notice was not found in libfastjson's atomic.h" >&2; exit 1; }
{
  for f in COPYING COPYING.LESSER COPYING.ASL20; do
    section rsyslog "${f}" "rsyslog-${RSYSLOG_VERSION}.tar.gz"
    cat "${build}/rsyslog/${f}"
    echo
  done
  printf '%s\n\n' "${hashtable}"
  section libestr COPYING "libestr-${LIBESTR_VERSION}.tar.gz"
  cat "${build}/libestr/COPYING"
  echo
  section libfastjson COPYING "libfastjson-${LIBFASTJSON_VERSION}.tar.gz"
  cat "${build}/libfastjson/COPYING"
  echo
  section libfastjson atomic.h "libfastjson-${LIBFASTJSON_VERSION}.tar.gz"
  printf '%s\n\n' "${atomic}"
} >> "${notice}"

# rsyslogd must be linked with -z now, and each LINK_CHECKS file must link its library.
readelf -d "${TARGET_DIR}/usr/sbin/rsyslogd" | grep -E 'FLAGS.*BIND_NOW' \
  || { echo "rsyslogd is not linked with -z now" >&2; exit 1; }
read -r -a link_checks <<< "${LINK_CHECKS:-}"
for check in "${link_checks[@]}"; do
  pattern=$(printf '%s' "${check#*=}" | sed 's/\./\\./g')
  readelf -d "${TARGET_DIR}/${check%%=*}" | grep -E "\[${pattern}\]" \
    || { echo "${check%%=*} does not link ${check#*=}" >&2; exit 1; }
done

rm -r "${build}"
