#!/bin/bash
set -euo pipefail

: "${TARGET_DIR:?}"
: "${LIBVIPS_VERSION:?}"
: "${SKIA_MILESTONE:?}"
: "${SHARP_AOM_VERSION:?}"
: "${SHARP_LIBARCHIVE_VERSION:?}"
: "${SHARP_CAIRO_VERSION:?}"
: "${SHARP_CGIF_VERSION:?}"
: "${SHARP_LIBEXIF_VERSION:?}"
: "${SHARP_EXPAT_VERSION:?}"
: "${SHARP_LIBFFI_VERSION:?}"
: "${SHARP_FONTCONFIG_VERSION:?}"
: "${SHARP_FREETYPE_VERSION:?}"
: "${SHARP_FRIBIDI_VERSION:?}"
: "${SHARP_GLIB_VERSION:?}"
: "${SHARP_HARFBUZZ_VERSION:?}"
: "${SHARP_LIBHEIF_VERSION:?}"
: "${SHARP_HIGHWAY_VERSION:?}"
: "${SHARP_IMAGEQUANT_VERSION:?}"
: "${SHARP_LCMS_VERSION:?}"
: "${SHARP_MOZJPEG_VERSION:?}"
: "${SHARP_PANGO_VERSION:?}"
: "${SHARP_PIXMAN_VERSION:?}"
: "${SHARP_LIBPNG_VERSION:?}"
: "${SHARP_PROXY_LIBINTL_VERSION:?}"
: "${SHARP_LIBRSVG_VERSION:?}"
: "${SHARP_LIBTIFF_VERSION:?}"
: "${SHARP_LIBUHDR_VERSION:?}"
: "${SHARP_LIBWEBP_VERSION:?}"
: "${SHARP_LIBXML2_VERSION:?}"
: "${SHARP_ZLIB_NG_VERSION:?}"
: "${CANVAS_LIBAOM_VERSION:?}"
: "${CANVAS_LIBAVIF_VERSION:?}"
: "${CANVAS_BROTLI_VERSION:?}"
: "${CANVAS_EXPAT_VERSION:?}"
: "${CANVAS_FREETYPE_VERSION:?}"
: "${CANVAS_HARFBUZZ_VERSION:?}"
: "${CANVAS_ICU_VERSION:?}"
: "${CANVAS_LIBJPEG_TURBO_VERSION:?}"
: "${CANVAS_LIBJXL_VERSION:?}"
: "${CANVAS_LIBPNG_VERSION:?}"
: "${CANVAS_LIBWEBP_VERSION:?}"
: "${CANVAS_MIMALLOC_VERSION:?}"
: "${CANVAS_WUFFS_VERSION:?}"
: "${CANVAS_ZLIB_VERSION:?}"

# node on Alpine has no glibcVersionRuntime. Debian Node prints a dotted version.
if node -p 'process.report.getReport().header.glibcVersionRuntime || ""' | grep -q '[0-9]'; then
  libc=gnu
else
  libc=musl
fi
arch="$(node -p 'process.arch')"

case "$libc" in
  musl)
    sharp_dir="node_modules/@img/sharp-linuxmusl-${arch}"
    vips_dir="node_modules/@img/sharp-libvips-linuxmusl-${arch}"
    canvas_dir="node_modules/@napi-rs/canvas-linux-${arch}-musl"
    ;;
  gnu)
    sharp_dir="node_modules/@img/sharp-linux-${arch}"
    vips_dir="node_modules/@img/sharp-libvips-linux-${arch}"
    canvas_dir="node_modules/@napi-rs/canvas-linux-${arch}-gnu"
    ;;
esac

test -d "$sharp_dir" || {
  echo "[ERROR] missing ${sharp_dir}" >&2
  ls -d node_modules/@img/* >&2 || true
  exit 1
}
test -d "$vips_dir" || {
  echo "[ERROR] missing ${vips_dir}" >&2
  ls -d node_modules/@img/* >&2 || true
  exit 1
}
test -d "$canvas_dir" || {
  echo "[ERROR] missing ${canvas_dir}" >&2
  ls -d node_modules/@napi-rs/* >&2 || true
  exit 1
}
test -n "$(find "$sharp_dir" -name '*.node' -print -quit)"
test -n "$(find "$canvas_dir" -name '*.node' -print -quit)"
test -f "$vips_dir/versions.json"

# Every versions.json entry has an SPDX row. A sharp bump that changes or
# adds a library fails here instead of leaving the SBOM stale.
node - "$vips_dir/versions.json" <<'NODE'
const fs = require('fs');
const got = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const expected = {
  aom: process.env.SHARP_AOM_VERSION,
  archive: process.env.SHARP_LIBARCHIVE_VERSION,
  cairo: process.env.SHARP_CAIRO_VERSION,
  cgif: process.env.SHARP_CGIF_VERSION,
  exif: process.env.SHARP_LIBEXIF_VERSION,
  expat: process.env.SHARP_EXPAT_VERSION,
  ffi: process.env.SHARP_LIBFFI_VERSION,
  fontconfig: process.env.SHARP_FONTCONFIG_VERSION,
  freetype: process.env.SHARP_FREETYPE_VERSION,
  fribidi: process.env.SHARP_FRIBIDI_VERSION,
  glib: process.env.SHARP_GLIB_VERSION,
  harfbuzz: process.env.SHARP_HARFBUZZ_VERSION,
  heif: process.env.SHARP_LIBHEIF_VERSION,
  highway: process.env.SHARP_HIGHWAY_VERSION,
  imagequant: process.env.SHARP_IMAGEQUANT_VERSION,
  lcms: process.env.SHARP_LCMS_VERSION,
  mozjpeg: process.env.SHARP_MOZJPEG_VERSION,
  pango: process.env.SHARP_PANGO_VERSION,
  pixman: process.env.SHARP_PIXMAN_VERSION,
  png: process.env.SHARP_LIBPNG_VERSION,
  'proxy-libintl': process.env.SHARP_PROXY_LIBINTL_VERSION,
  rsvg: process.env.SHARP_LIBRSVG_VERSION,
  tiff: process.env.SHARP_LIBTIFF_VERSION,
  uhdr: process.env.SHARP_LIBUHDR_VERSION,
  vips: process.env.LIBVIPS_VERSION,
  webp: process.env.SHARP_LIBWEBP_VERSION,
  xml2: process.env.SHARP_LIBXML2_VERSION,
  'zlib-ng': process.env.SHARP_ZLIB_NG_VERSION,
};
const gotKeys = Object.keys(got).sort();
const wantKeys = Object.keys(expected).sort();
if (gotKeys.join(',') !== wantKeys.join(',')) {
  console.error(`[ERROR] sharp versions.json keys [${gotKeys}] != SPDX rows [${wantKeys}]`);
  process.exit(1);
}
for (const key of gotKeys) {
  if (got[key] !== expected[key]) {
    console.error(`[ERROR] sharp ${key} is ${got[key]}, expected ${expected[key]}`);
    process.exit(1);
  }
}
NODE

canvas_node="$(find "$canvas_dir" -name '*.node' -print -quit)"
test -n "$canvas_node"
grep -aqF "Skia/PDF m${SKIA_MILESTONE}" "$canvas_node"

canvas_banner() {
  local label="$1"
  local needle="$2"
  if ! grep -aqF -- "$needle" "$canvas_node"; then
    echo "[ERROR] canvas ${label} banner missing from ${canvas_node}: ${needle}" >&2
    exit 1
  fi
}

# Banners present in both the glibc and musl prebuilds of @napi-rs/canvas 0.1.88.
canvas_banner libjpeg-turbo "libjpeg-turbo version ${CANVAS_LIBJPEG_TURBO_VERSION}"
canvas_banner libaom "AOMedia Project AV1 Encoder v${CANVAS_LIBAOM_VERSION}"
canvas_banner libavif "libavif"
canvas_banner mimalloc "mimalloc: error:"
canvas_banner zlib "${CANVAS_ZLIB_VERSION}"
canvas_banner libpng "Application built with libpng-"
canvas_banner expat "EXPAT_ACCOUNTING_DEBUG"
canvas_banner harfbuzz "HB_OPTIONS"
icu_major="${CANVAS_ICU_VERSION%%.*}"
canvas_banner icu "icudt${icu_major}l"
canvas_banner freetype "FREETYPE_PROPERTIES"
canvas_banner libwebp "null VP8Io passed to VP8GetHeaders()"
canvas_banner libjxl "SkJpegxlCodec.cpp"
canvas_banner wuffs "wuffs_base__image_decoder"

# The glibc addon keeps version strings that the musl link strips.
if [ "$libc" = gnu ]; then
  canvas_banner libpng "libpng version ${CANVAS_LIBPNG_VERSION}"
  canvas_banner expat "expat_${CANVAS_EXPAT_VERSION}"
  canvas_banner harfbuzz "${CANVAS_HARFBUZZ_VERSION}"
  canvas_banner icu "${CANVAS_ICU_VERSION}"
  canvas_banner libwebp "NULL VP8Io parameter in VP8Decode()"
  canvas_banner libjxl "third_party/externals/libjxl/"
  # avifVersion() is the "1.0.4" literal. Musl drops it and the mimalloc_version symbol.
  canvas_banner libavif "${CANVAS_LIBAVIF_VERSION}"
  canvas_banner mimalloc "mimalloc_version"
fi

shopt -s nullglob
for dir in node_modules/@img/sharp-* node_modules/@img/sharp-libvips-* node_modules/@napi-rs/canvas-*; do
  case "$dir" in
    "$sharp_dir"|"$vips_dir"|"$canvas_dir") ;;
    *) rm -rf "$dir" ;;
  esac
done
shopt -u nullglob

if [ "$libc" = gnu ]; then
  foreign="$(find node_modules -name '*.node' -path '*musl*' -print -quit)"
else
  foreign="$(find node_modules -name '*.node' \( -path '*gnu*' -o -path '*sharp-linux-*' \) ! -path '*musl*' -print -quit)"
fi
if [ -n "$foreign" ]; then
  echo "[ERROR] foreign-libc native addon remains: $foreign" >&2
  exit 1
fi

test -d api/server
rm -rf api/test
find api config -depth -type d -name __tests__ -exec rm -rf {} +
find api config -type f -name '*.spec.js' -delete
test -f api/server/index.js

test -d client/dist
test -f client/dist/index.html
test -d client/public/fonts
test -d client/public/assets
test -d packages/api/dist
test -d packages/data-provider/dist
test -d packages/data-schemas/dist
test -d packages/client/dist
test -f node_modules/.bin/cross-env
test -f LICENSE
test -f package.json

staged="${TARGET_DIR}/usr/lib/librechat"
rm -rf "$staged"
mkdir -p "$staged/packages" "$staged/client/public"

cp -a package.json LICENSE node_modules api config "$staged/"
cp -a client/package.json "$staged/client/"
cp -a client/dist "$staged/client/"
cp -a client/public/fonts client/public/assets "$staged/client/public/"
for name in api client data-provider data-schemas; do
  mkdir -p "$staged/packages/$name"
  cp -a "packages/$name/package.json" "$staged/packages/$name/"
  cp -a "packages/$name/dist" "$staged/packages/$name/"
  if [ -d "packages/$name/node_modules" ]; then
    cp -a "packages/$name/node_modules" "$staged/packages/$name/"
  fi
done
if [ -f packages/client/tailwind.preset.cjs ]; then
  cp -a packages/client/tailwind.preset.cjs "$staged/packages/client/"
fi
if [ -d packages/api/openapi ]; then
  cp -a packages/api/openapi "$staged/packages/api/"
fi
: > "$staged/.env"

# Workspace package node_modules still contain the TypeScript bundler after
# npm prune. Those directories are build tools, including every platform's
# native binding. Production peers such as winston-daily-rotate-file stay.
for name in api client data-provider data-schemas; do
  base="$staged/packages/$name/node_modules"
  if [ ! -d "$base" ]; then
    continue
  fi
  for tool in tsdown rolldown @rolldown @babel @oxc-project @types get-tsconfig rimraf picomatch; do
    if [ -d "$base/$tool" ]; then
      rm -rf "$base/$tool"
    fi
  done
  if [ -d "$base/@napi-rs/wasm-runtime" ]; then
    rm -rf "$base/@napi-rs/wasm-runtime"
  fi
done
if [ -d "$staged/api/node_modules/@types" ]; then
  rm -rf "$staged/api/node_modules/@types"
fi

src_left="$(find "$staged/packages" -type d -name src -print -quit)"
if [ -n "$src_left" ]; then
  echo "[ERROR] TypeScript source remains in the staged packages tree: $src_left" >&2
  exit 1
fi
if [ -d "$staged/.git" ]; then
  echo "[ERROR] .git was copied into the payload" >&2
  exit 1
fi

bracketed="$(find "$staged" \( -name '*[[]*' -o -name '*[]]*' \) -print -quit)"
if [ -n "$bracketed" ]; then
  echo "[ERROR] bracketed paths remain; dhi/build-pkg cannot glob them" >&2
  find "$staged" \( -name '*[[]*' -o -name '*[]]*' \) >&2
  exit 1
fi

# Fail if the staged tree has no *.map files, then if any remain after deletion.
maps="$(find "$staged" -name '*.map' -print -quit)"
if [ -z "$maps" ]; then
  echo "[ERROR] expected source maps in the staged tree before pruning" >&2
  exit 1
fi
find "$staged" -name '*.map' -delete
left="$(find "$staged" -name '*.map' -print -quit)"
if [ -n "$left" ]; then
  echo "[ERROR] source map remains after pruning: $left" >&2
  exit 1
fi

# Fail if node_modules has no TypeScript sources, then if any remain after deletion.
ts="$(find "$staged" -path '*/node_modules/*' \( -name '*.ts' -o -name '*.mts' -o -name '*.cts' -o -name '*.tsx' \) -print -quit)"
if [ -z "$ts" ]; then
  echo "[ERROR] expected TypeScript sources under node_modules before pruning" >&2
  exit 1
fi
find "$staged" -path '*/node_modules/*' \( -name '*.ts' -o -name '*.mts' -o -name '*.cts' -o -name '*.tsx' \) -delete
left="$(find "$staged" -path '*/node_modules/*' \( -name '*.ts' -o -name '*.mts' -o -name '*.cts' -o -name '*.tsx' \) -print -quit)"
if [ -n "$left" ]; then
  echo "[ERROR] TypeScript source remains under node_modules: $left" >&2
  exit 1
fi

# npm ci runs as root with umask 022, and the git checkout is 0644/0755.
# A recursive chmod would hide a dependency that ships an unreadable file.
unreadable="$(find "$staged" ! -perm -004 -print -quit)"
if [ -n "$unreadable" ]; then
  echo "[ERROR] staged path is not world-readable: $unreadable" >&2
  exit 1
fi
unsearchable="$(find "$staged" -type d ! -perm -001 -print -quit)"
if [ -n "$unsearchable" ]; then
  echo "[ERROR] staged directory is not world-searchable: $unsearchable" >&2
  exit 1
fi

if [ ! -f "$staged/api/server/index.js" ]; then
  echo "[ERROR] staged tree is missing api/server/index.js under $staged" >&2
  find "$staged" -maxdepth 2 -printf '%y %p\n' >&2
  exit 1
fi

(
  cd "$staged"
  node -e "const sharp = require('sharp'); if (sharp.versions.vips !== process.env.LIBVIPS_VERSION) { console.error('sharp linked', sharp.versions.vips); process.exit(1); } require('@napi-rs/canvas');"
)
node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-module-graph.cjs" "$staged"

echo "staged librechat for ${libc}/${arch}"
