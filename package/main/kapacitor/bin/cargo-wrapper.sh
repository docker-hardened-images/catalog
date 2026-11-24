#!/bin/sh
# Shim used to compile the flux library during go build.
# github.com/influxdata/pkg-config (installed as pkg-config) builds libflux on
# demand by running `$CARGO build --release`.
exec cargo "$@" --no-default-features --features=cffi
