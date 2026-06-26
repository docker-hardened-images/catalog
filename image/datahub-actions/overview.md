## About DataHub Actions

DataHub Actions is an event-driven framework that reacts to real-time changes in DataHub's metadata graph. The
`datahub-actions` CLI provided by this image consumes events from Kafka topics (`MetadataChangeLog_Versioned_v1`,
`EntityChangeEvent_v1`, `PlatformEvent_v1`), filters them by configurable criteria, and invokes pluggable actions in
response — Slack/Teams notifications, documentation/tag/term propagation, and the `executor` action that runs
UI-triggered ingestion jobs. It is the realtime-automation companion to `dhi/datahub-ingestion` and a hard dependency of
DataHub's UI-driven ingestion workflows.

This Docker Hardened DataHub Actions image is available in three variants matching the upstream
`acryldata/datahub-actions` layout:

- **Slim variant** (default): Minimal install of `acryl-datahub-actions[all]` — the full set of pluggable actions
  (executor, slack, teams, doc/tag/term propagation) running against the standard Kafka event source. Suitable for the
  majority of Actions deployments where ingestion runs in a separate `dhi/datahub-ingestion` container or pod.
- **Locked variant** (`-locked`): Hardened airgap variant. Network access to PyPI is blocked at runtime via
  `UV_INDEX_URL` and `PIP_INDEX_URL` pointed at an unreachable endpoint, so the image can only run with the actions
  baked in at build time. Useful for regulated environments that prohibit unaudited runtime package installation.

For more information about DataHub Actions, visit the upstream documentation at
https://docs.datahub.com/docs/actions/quickstart.

## Runtime dependency on DataHub GMS

DataHub Actions does not run standalone. The image's entrypoint blocks on a health check against the DataHub Generalized
Metadata Service (GMS) at
`${DATAHUB_GMS_PROTOCOL:-http}://${DATAHUB_GMS_HOST:-datahub-gms}:${DATAHUB_GMS_PORT:-8080}/health` (default 240 s
timeout, configurable via `DATAHUB_GMS_STARTUP_TIMEOUT_SEC`) before it will start polling Kafka. Make sure a GMS
instance — typically the sibling [`dhi/datahub-gms`](https://hub.docker.com/r/dhi/datahub-gms) — is reachable on the
container network before the Actions container starts, or scale the Actions deployment to zero until GMS is healthy.

## Helm chart

The upstream Helm chart at https://artifacthub.io/packages/helm/datahub/datahub is an *umbrella* chart that deploys
DataHub Actions alongside DataHub GMS, Frontend, MAE/MCE consumers, and the ingestion cron job — six components in one
release. A Docker Hardened equivalent will land in this catalog when every image the umbrella chart references is
hardened. As of this image's release, `dhi/datahub-gms`, `dhi/datahub-ingestion`, and `dhi/datahub-actions` (this image)
are the three hardened components; the remaining three are pending. In the interim, customers can pin the upstream
chart's `acryl-datahub-actions.image.repository` value to `dhi/datahub-actions` to swap in the hardened image alone.

## Deviation from upstream: bundled venvs

Upstream `acryldata/datahub-actions` pre-builds isolated Python venvs for the `executor` action's subprocess plugins
under `/opt/datahub/venvs/<plugin>/` (e.g. `s3`, `demo-data`, `datahub-gc`). This image collapses the upstream
subprocess isolation into the single `/opt/datahub` venv — every dependency is resolved once at build time and shipped
flat. Custom actions that previously expected `${DATAHUB_BUNDLED_VENV_PATH}/<plugin>/bin/python` may need to invoke
`python` from `/opt/python/bin/` instead. Same shape as `dhi/datahub-ingestion`.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

DataHub is an open-source project. DataHub™ is a trademark of the DataHub Project, maintained by Acryl Data, Inc. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. Oracle®
and Oracle Instant Client® are registered trademarks of Oracle Corporation. All other third-party product names, logos,
and trademarks are the property of their respective owners and are used solely for identification. Docker claims no
interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
