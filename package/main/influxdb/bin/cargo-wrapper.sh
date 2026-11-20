#!/bin/sh
# Only used to compile the flux library. At go build time https://github.com/influxdata/pkg-config
# is invoked instead of the real pkg-config and builds libflux on demand with "$CARGO build --release".
# The CARGO environment variable points that build here.
# libflux enables a "strict" feature by default that does deny(warnings). A newer rustc than upstream's
# adds warnings it has not accounted for, which stops the build, so the strict feature is switched off
# while the cffi feature the Go bindings need stays on.

exec /usr/bin/cargo "$@" --no-default-features --features=cffi
