#!/bin/sh
# DHI runtime entrypoint for dhi/trigger-dev.
#
# Why this exists: upstream's docker/scripts/entrypoint.sh shells out to pnpm
# (e.g. `pnpm --filter @trigger.dev/database db:migrate:deploy`). DHI runtime
# images stay minimal, so we invoke Prisma's CLI directly via node_modules/.bin
# and use netcat for the optional database wait, keeping behavior parity with
# upstream while avoiding pnpm at runtime.
set -eu

WORKDIR=/triggerdotdev
cd "$WORKDIR"

if [ -n "${DATABASE_HOST:-}" ]; then
  host="${DATABASE_HOST%%:*}"
  port="${DATABASE_HOST#*:}"
  if [ "$port" = "$host" ]; then port=5432; fi
  echo "Waiting for ${host}:${port}..."
  # netcat-openbsd ships as nc.openbsd in the runtime image; the usual
  # /usr/bin/nc symlink only exists once update-alternatives runs (which is
  # not the case in the DHI runtime). Reach the binary directly.
  while ! nc.openbsd -z "$host" "$port" 2>/dev/null; do
    sleep 1
  done
  echo "database is up"
fi

if [ "${SKIP_POSTGRES_MIGRATIONS:-}" != "1" ]; then
  echo "Running prisma migrations"
  cd "$WORKDIR/internal-packages/database"
  "$WORKDIR/node_modules/.bin/prisma" migrate deploy
  cd "$WORKDIR"
  echo "Prisma migrations done"
else
  echo "SKIP_POSTGRES_MIGRATIONS=1, skipping Postgres migrations."
fi

if [ -n "${CLICKHOUSE_URL:-}" ] && [ "${SKIP_CLICKHOUSE_MIGRATIONS:-}" != "1" ]; then
  echo "Running ClickHouse migrations..."
  export GOOSE_DRIVER=clickhouse
  if echo "$CLICKHOUSE_URL" | grep -q "secure="; then
    export GOOSE_DBSTRING="$CLICKHOUSE_URL"
  elif echo "$CLICKHOUSE_URL" | grep -q "?"; then
    export GOOSE_DBSTRING="${CLICKHOUSE_URL}&secure=true"
  else
    export GOOSE_DBSTRING="${CLICKHOUSE_URL}?secure=true"
  fi
  export GOOSE_MIGRATION_DIR="$WORKDIR/internal-packages/clickhouse/schema"
  /usr/local/bin/goose up
  echo "ClickHouse migrations complete."
elif [ "${SKIP_CLICKHOUSE_MIGRATIONS:-}" = "1" ]; then
  echo "SKIP_CLICKHOUSE_MIGRATIONS=1, skipping ClickHouse migrations."
else
  echo "CLICKHOUSE_URL not set, skipping ClickHouse migrations."
fi

mkdir -p "$WORKDIR/apps/webapp/prisma"
cp "$WORKDIR/internal-packages/database/prisma/schema.prisma" "$WORKDIR/apps/webapp/prisma/"
# POSIX sh leaves unmatched globs literal, so test for engine presence
# explicitly. We warn but don't abort: Prisma can still find engines under
# node_modules at runtime, but copying them next to the schema avoids a
# slow first-request fallback. A silent failure here previously surfaced
# as a confusing "Could not load engine" error in webapp logs.
if ls "$WORKDIR"/node_modules/@prisma/engines/*.node >/dev/null 2>&1; then
  cp "$WORKDIR"/node_modules/@prisma/engines/*.node "$WORKDIR/apps/webapp/prisma/"
else
  echo "Warning: no prisma engines at $WORKDIR/node_modules/@prisma/engines/*.node; webapp may fall back to runtime engine resolution."
fi

cd "$WORKDIR/apps/webapp"

MAX_OLD_SPACE_SIZE="${NODE_MAX_OLD_SPACE_SIZE:-8192}"
echo "Setting max old space size to ${MAX_OLD_SPACE_SIZE}"

NODE_PATH="$WORKDIR/node_modules/.pnpm/node_modules" exec node --max-old-space-size="${MAX_OLD_SPACE_SIZE}" ./build/server.js
