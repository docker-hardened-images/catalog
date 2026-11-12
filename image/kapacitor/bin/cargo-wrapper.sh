#!/usr/bin/bash
# Shim used to compile the flux library during go build.
# At build time, github.com/influxdata/pkg-config (installed as pkg-config)
# builds libflux on demand by running `$CARGO build --release`.
#
# flux-core's "strict" feature (enabled by default in v0.191.0) enables
# deny(warnings) which fails with newer Rust. The deny->warn change is
# handled by the flux-core-strict-warnings.patch applied to vendor/.
# This wrapper disables default features to skip unnecessary compilation.

exec /usr/local/bin/cargo "$@" --no-default-features --features=cffi
