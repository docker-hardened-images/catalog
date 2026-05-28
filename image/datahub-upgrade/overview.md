## About DataHub Upgrade

DataHub is an open-source metadata platform for the modern data stack, designed to enable data discovery, observability,
and governance across complex data ecosystems. Originally developed at LinkedIn and now maintained as a community
project under the LF AI & Data Foundation with Acryl Data as the primary commercial backer, DataHub provides a unified
catalog for tracking data assets, lineage, and ownership. For more information, visit https://datahub.com.

The `datahub-upgrade` component is a run-to-completion batch container that performs system upgrades, index rebuilds,
and maintenance jobs against a running DataHub deployment. It is designed to be executed as a Kubernetes pre-install or
pre-upgrade hook so that schemas, indices, and configuration are fully migrated before the rest of the DataHub stack
(GMS, frontend, and consumers) starts the new version.

## Supported upgrade jobs

Pass the job name with the `-u` flag to the container entrypoint (for example, `-u SystemUpdate`):

- **SystemUpdate** — applies default configurations, ingests system defaults, and emits a readiness signal on the Kafka
  topic `DataHubUpgradeHistory_v1`. All other DataHub services wait for this signal before serving traffic. This is the
  standard job to run during a version upgrade.
- **SystemUpdateBlocking** — blocking subset of SystemUpdate. Use when an upgrade includes a long-running migration that
  must fully complete before dependent services can start.
- **SystemUpdateNonBlocking** — non-blocking subset of SystemUpdate. Use when the migration can proceed concurrently
  with dependent services starting.
- **RestoreIndices** — rebuilds Elasticsearch search and graph indices from the primary metadata store by replaying MCL
  events. Supports optional arguments: `batchSize`, `batchDelayMs`, `numThreads`, `aspectName`, `urn`, `urnLike`, and
  `urnBasedPagination`.
- **RestoreBackup** — restores the SQL document store from a backup file. Requires `BACKUP_READER` and
  `BACKUP_FILE_PATH` environment variables to be set.
- **EvaluateTests** — runs Metadata Tests in batches. Recommended as a scheduled Kubernetes CronJob, typically once per
  day.

Full job reference: https://docs.datahub.com

## Bundled tools

In addition to the `datahub-upgrade.jar` Spring Boot application (Java 17), the image ships:

- **`dockerize`** — a Go-based readiness wrapper (built from `github.com/powerman/dockerize`) used by the entrypoint to
  wait on upstream datastores (Elasticsearch, Ebean/MySQL/Postgres, Cassandra, Neo4j) before starting the JVM.
- **`kubectl`** — Kubernetes CLI, used by some upgrade jobs that perform Kubernetes-side operations during migration.
- **OpenTelemetry Java agent** — bundled at `/datahub/datahub-upgrade/lib/opentelemetry-javaagent.jar`. Activated by
  setting `ENABLE_OTEL=true` at runtime.
- **JMX Prometheus agent** — bundled at `/datahub/datahub-upgrade/lib/jmx_prometheus_javaagent.jar`. Activated by
  setting `ENABLE_PROMETHEUS=true` at runtime; binds to port 4318 when enabled.
- **Entity registry** — `entity-registry.yml` placed at `/datahub/datahub-gms/resources/entity-registry.yml` as required
  by the DataHub JAR at startup.

## Image variants

This image is available in runtime, dev, and FIPS variants:

- **Runtime** (`dhi.io/datahub-upgrade:<tag>`) — minimal production image running as the non-root `datahub` user (UID
  65532). No shell or package manager included.
- **Dev** (`dhi.io/datahub-upgrade:<tag>-dev`) — includes a shell and package manager for development and debugging
  workflows. Runs as root.
- **FIPS** (`dhi.io/datahub-upgrade:<tag>-fips`) — wires BouncyCastle FIPS into the JVM as the JCE provider via
  `JDK_JAVA_OPTIONS=@/datahub/datahub-upgrade/scripts/datahub-fips.properties`, so all Java TLS and JCE operations use
  FIPS 140-validated cryptography. The environment variable `DATAHUB_FIPS=true` is set in this variant.
- **FIPS dev** (`dhi.io/datahub-upgrade:<tag>-fips-dev`) — combines the FIPS cryptographic configuration with the dev
  tooling.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

DataHub™ is a trademark of the DataHub Project (https://github.com/datahub-project), maintained by Acryl Data, Inc. All
rights in the mark are reserved to their respective owners. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.
