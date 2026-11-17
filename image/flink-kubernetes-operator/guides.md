## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use, update your
commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/flink-kubernetes-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-flink-kubernetes-operator:<tag>`

For the examples, you may need to authenticate to the registry to pull the images.

## What's included in this image

This Docker Hardened Apache Flink Kubernetes Operator image includes:

- The Apache Flink Kubernetes Operator shaded JAR
- The Apache Flink Kubernetes Webhook shaded JAR
- The Apache Flink Kubernetes Standalone JAR
- Operator plugins under `/opt/flink/plugins`
- Log4j and Logback configuration under `/opt/flink/log`
- The upstream `/docker-entrypoint.sh` script

## Start the image

Replace `<tag>` with the image variant you want to run, such as `1`, `1.15`, `1.15.0`, or `1-dev`.

Use the default command to see the supported entrypoint modes:

```bash
docker run --rm dhi.io/flink-kubernetes-operator:<tag>
```

Start the operator process:

```bash
docker run --rm dhi.io/flink-kubernetes-operator:<tag> operator
```

Start the admission webhook process:

```bash
docker run --rm dhi.io/flink-kubernetes-operator:<tag> webhook
```

For Kubernetes deployments, follow the
[official Flink Kubernetes Operator installation guide](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/try-flink-kubernetes-operator/quick-start/)
and replace the upstream image reference with the Docker Hardened Image reference.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run the operator in production. They run as the nonroot `flink` user and include only
  the runtime dependencies needed by the upstream entrypoint and Java application.
- Build-time variants include `dev` in the tag and are intended for development, debugging, or use as an intermediate
  stage in a multi-stage Dockerfile. They run as root and include a shell and package manager.

FIPS variants are not currently published for this image.

## Migrate to a Docker Hardened Image

To migrate to the Docker Hardened Apache Flink Kubernetes Operator image:

1. Choose the DHI tag that matches your upstream operator major or patch version, such as `1` or `1.15.0`.
1. Replace the upstream image in your Helm values, Kustomize patch, or Kubernetes manifest with
   `dhi.io/flink-kubernetes-operator:<tag>`.
1. Keep the same entrypoint mode (`operator` or `webhook`) and operator environment variables unless your deployment
   intentionally customizes them.
1. Use the `dev` variant or Docker Debug for troubleshooting. The runtime image does not include a package manager.

## Troubleshooting migration

### Entrypoint

The image preserves upstream's `/docker-entrypoint.sh`, default command `help`, and entrypoint modes `operator` and
`webhook`.

### User and permissions

The image runs as the nonroot `flink` user with uid/gid `9999`, matching the upstream image. Ensure mounted
configuration, certificates, and log paths are readable by that user.
