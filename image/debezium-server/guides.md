## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use, update the commands
to reference the mirrored image. Authenticate first with `docker login dhi.io`.

### Configure Debezium Server

Each Debezium Server instance runs one source connector and one sink. Put the configuration in
`config/application.properties`; the image reads it from `/debezium/config/application.properties`.

The following example captures PostgreSQL changes and sends them to Amazon Kinesis. Replace the example database values
and ensure that streams matching the generated destination names exist before starting the server.

```properties
debezium.sink.type=kinesis
debezium.sink.kinesis.region=us-east-2

debezium.source.connector.class=io.debezium.connector.postgresql.PostgresConnector
debezium.source.database.hostname=postgres.example.internal
debezium.source.database.port=5432
debezium.source.database.user=debezium
debezium.source.database.password=replace-me
debezium.source.database.dbname=application
debezium.source.topic.prefix=application
debezium.source.plugin.name=pgoutput
debezium.source.offset.storage.file.filename=/debezium/data/offsets.dat
```

Start the server with persistent configuration and data directories:

```console
docker run --rm -p 8080:8080 \
  -v "$(pwd)/config:/debezium/config:ro" \
  -v "$(pwd)/data:/debezium/data" \
  dhi.io/debezium-server:3.6
```

The health endpoints are exposed on port 8080. See the upstream
[Debezium Server documentation](https://debezium.io/documentation/reference/3.6/operations/debezium-server.html) for
source connector, sink, serialization, transformation, and health endpoint configuration.

### Configure with environment variables

MicroProfile Config maps property names to uppercase environment variables with punctuation replaced by underscores. For
example, `debezium.sink.type=kinesis` can be supplied as `DEBEZIUM_SINK_TYPE=kinesis`. Prefer mounted files or a secrets
provider for credentials rather than including secrets directly in image layers or command history.

### Use EKS workload identity (IRSA)

The hardened distribution includes the AWS SDK STS module required by the default credentials provider to exchange a
projected web-identity token. On Amazon EKS, configure an IAM role for the Kubernetes service account and allow EKS to
inject `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`. Do not set `debezium.sink.kinesis.credentials.profile`; the
Kinesis sink then uses the default AWS credential chain and obtains short-lived role credentials without static access
keys.

The role needs permission to write to the destination streams and, when applicable, to use their KMS keys. Scope those
permissions to the required stream and key ARNs.

### JVM, JMX, and OpenTelemetry settings

The upstream-compatible `/debezium/run.sh` launcher reads `JAVA_OPTS` and `DEBEZIUM_OPTS`. Set `JMX_HOST` and `JMX_PORT`
to enable JMX. The OpenTelemetry Java agent is included in the assembled distribution; telemetry is disabled by default
through `OTEL_SDK_DISABLED=true`. Set it to `false` and configure the standard `OTEL_*` variables to export telemetry.

### Writable paths

The runtime image runs as the `debezium` user (UID 185, GID 0). `/debezium/config` and `/debezium/data` are writable by
that account. When bind-mounting host directories, ensure UID 185 or GID 0 can access them. Mount configuration read-only
when Debezium does not need to update it.

## Differences from `quay.io/debezium/server`

| Aspect | Upstream | Docker Hardened Image |
| :--- | :--- | :--- |
| Base OS | Red Hat UBI 8 OpenJDK 21 | Debian 13 with Docker Hardened Images Eclipse Temurin 21 |
| Default user | `jboss` (UID 185, GID 0) | `debezium` (UID 185, GID 0) |
| Application layout | `/debezium` | `/debezium` |
| Startup | `CMD ["/debezium/run.sh"]` | `CMD ["/debezium/run.sh"]` |
| Configuration and data | `/debezium/config`, `/debezium/data` | Same paths; no Docker `VOLUME` metadata is declared |
| AWS web identity | The 3.6.0.Final distribution omits the AWS SDK STS module | STS is included so the default credential chain supports EKS IRSA |
| Package manager | `microdnf` is available in the base image | Runtime has no package manager; use the `-dev` variant for package installation |
| Runtime shell | Bash, required by `run.sh` | Bash, retained for launcher compatibility |

## Image variants

- Runtime tags, such as `3.6` and `3.6-debian13`, run as UID 185 and contain the minimal Java runtime and tools required
  by Debezium's launcher.
- Development tags end in `-dev`, run as root, and include a JDK, shell, package manager, and common build utilities. Use
  them only in build stages or for controlled customization, then copy artifacts into the runtime image.

## Migrate to a Docker Hardened Image

For a direct deployment, replace `quay.io/debezium/server:3.6.0.Final` with `dhi.io/debezium-server:3.6`. Existing
configuration and data mounts under `/debezium` and security contexts that use UID 185 remain compatible.

If your Dockerfile installs extra connectors, JDBC drivers, or agents, use a multi-stage build. Perform downloads and
package installation in `dhi.io/debezium-server:3.6-dev`, verify and copy only the required artifacts, then use the
runtime image for the final stage. The runtime variant intentionally omits `apt` and other development tools.

Review any custom image that worked around missing AWS web-identity support. The hardened image already includes STS, so
adding a second `sts` JAR or mixing AWS SDK versions is unnecessary and can create classpath conflicts.

## Troubleshooting

### The container cannot read mounted files

The process runs as UID 185 with primary GID 0. Update ownership or group permissions on mounted configuration and data
paths. In Kubernetes, an appropriate pod `securityContext` or `fsGroup` can provide access without making files
world-writable.

### Kinesis authentication falls through to the node role

Confirm that the pod has `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`, the token file is readable by UID 185, the
service account is annotated for the intended IAM role, and the role trust policy matches the cluster's OIDC issuer and
service account subject. Avoid setting a credentials profile unless you intentionally mount a profile file.

### Add or inspect files in the runtime container

The runtime keeps Bash because the upstream launcher requires it, but it does not include a package manager or general
debugging suite. Use Docker Debug for ephemeral diagnostics, or use the `-dev` image in a non-production environment.
