#!/usr/bin/bash
# This is only used to compile the flux library.
# At go build time, https://github.com/influxdata/pkg-config is invoked (instead of the real pkg-config), which builds libflux on demand.
# When it builds libflux, it runs `$CARGO build --release`. We can override the default cargo binary with the CARGO envvar.
# libflux has a "strict" feature that is enabled by default and does `deny(warnings)`
# Since we're using a newer version of rust than upstream libflux, there are new warnings they have not accounted for. These stop the build with the strict feature on.
# By using this cargo shim, we can disable the strict feature but still enable the required cffi feature.

exec /usr/local/bin/cargo "$@" --no-default-features --features=cffi
