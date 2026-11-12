#!/bin/sh
# Preserve upstream's command passthrough for gcloud, gsutil, and bq.
set -e
exec "$@"
