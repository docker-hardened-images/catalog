## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/stackgres-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-stackgres-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This Docker Hardened StackGres Operator image is a drop-in replacement for the upstream JVM operator image
(`quay.io/stackgres/operator:<version>-jvm`). You normally deploy it with the upstream `stackgres-operator` Helm chart
and manage PostgreSQL clusters through the StackGres custom resources described in the
[StackGres documentation](https://stackgres.io/doc/latest/).

Use a tag that pins the operator version, such as `1.19.5` or `1.19.5-debian13`, and install the chart release with the
same version. The chart and the operator are released together, and each chart release installs the custom resource
definitions for its operator version.

### What's included in this StackGres Operator image

This Docker Hardened StackGres Operator image includes:

- `patronictl-4` — the Patroni 4 command-line client the operator runs to read and control Patroni 4 clusters, installed
  as `/usr/bin/patronictl-<version>` (for example `/usr/bin/patronictl-4.1.5` in the `1.19.5` tags)
- `patronictl-3` — the Patroni 3 command-line client the operator uses for Patroni 3 clusters, installed as
  `/usr/bin/patronictl-<version>` (for example `/usr/bin/patronictl-3.3.11` in the `1.19.5` tags)

Both clients include the etcd v3, Consul, ZooKeeper, Exhibitor, and Raft backends, so the operator can also manage
SGClusters whose Patroni configuration (`spec.configurations.patroni.initialConfig`) uses a non-Kubernetes DCS.

To check a client version:

```bash
$ docker run --rm --entrypoint /usr/bin/patronictl-4.1.5 dhi.io/stackgres-operator:1.19.5 version
patronictl version 4.1.5
```

## Install StackGres with Helm

The following example installs the operator into the `stackgres` namespace with the upstream chart and a pull secret for
`dhi.io`:

```bash
$ kubectl create namespace stackgres
$ kubectl create secret docker-registry dhi-pull-secret --namespace stackgres \
  --docker-server=dhi.io --docker-username=<your-username> --docker-password=<your-access-token>
$ helm repo add stackgres-charts https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/
$ helm install stackgres-operator stackgres-charts/stackgres-operator \
  --namespace stackgres \
  --version 1.19.5 \
  --set operator.image.name=dhi.io/stackgres-operator \
  --set operator.image.tag=1.19.5 \
  --set 'imagePullSecrets[0].name=dhi-pull-secret'
$ kubectl wait --namespace stackgres deployment/stackgres-operator --for condition=Available --timeout 5m
```

Keep the following in mind when you set the chart values:

- Use a registry-qualified image name. The chart prefixes `operator.image.name` with `containerRegistry` (`quay.io` by
  default) unless the name already starts with a registry host. `dhi.io/stackgres-operator` is used as is. For a mirror,
  include the host, for example `docker.io/<your-namespace>/dhi-stackgres-operator`. Otherwise the chart renders
  `quay.io/<your-namespace>/dhi-stackgres-operator`.
- Leave `containerRegistry` at its default. The operator also uses it to pull the companion images it deploys (the REST
  API, admin UI, cluster controller, and Patroni images), and those images stay on upstream registries.
- The chart adds `imagePullSecrets` to the operator service account and to the service accounts of its install jobs.
  When `disableClusterRole` or `disableCrdsAndWebhooksUpdate` is set, the chart also runs an `initialize-operator` job
  with the same operator image, so that job needs the same pull secret.
- The chart runs the operator as UID and GID 1000, as it does for upstream non-`-jvm` tags. The image runs under any
  non-root UID, so you don't need to change `operator.securityContext`.

After the operator is available, create clusters as described in the
[StackGres documentation](https://stackgres.io/doc/latest/). For all chart values, see the
[Helm parameters reference](https://stackgres.io/doc/latest/install/helm/parameters/).

### Companion image versions

The operator picks the tag of the cluster controller it injects into each SGCluster from its own image version.
Upstream's JVM image selects the `-jvm` cluster controller, for example
`quay.io/stackgres/cluster-controller:1.19.5-jvm`. This image does the same: it sets `JAVA_TOOL_OPTIONS` to
`-Dstackgres.operatorImageVersion=<version>-jvm` and the matching JVM and native version properties.

To select a different companion version, pass a later `-D` option through `developer.extraOpts`. For example, the
following switches new clusters to the native cluster controller `quay.io/stackgres/cluster-controller:1.19.5`:

```bash
$ helm upgrade stackgres-operator stackgres-charts/stackgres-operator \
  --namespace stackgres \
  --version 1.19.5 \
  --reuse-values \
  --set 'developer.extraOpts[0]=-Dstackgres.operatorImageVersion=1.19.5'
```

Don't set `JAVA_TOOL_OPTIONS` through `developer.extraEnv`. Replacing it drops these properties. The operator then
derives the companion tag from the image tag, for example `1.19.5-debian13`, which upstream doesn't publish, so the new
cluster pods can't pull their cluster controller. On FIPS variants it also drops the FIPS security settings.

## Run the operator outside Kubernetes

You can start the operator as a plain container to check that the image runs and serves its health endpoints. The
operator serves HTTPS with the certificate and key in `/etc/operator/certs`. The process doesn't run as your host user,
so the key file must be readable by others:

```bash
$ mkdir certs
$ openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=localhost" \
  -keyout certs/tls.key -out certs/tls.crt
$ chmod 0644 certs/tls.key
$ docker run -d --name stackgres-operator -p 8080:8080 -p 8443:8443 \
  -v "$(pwd)/certs:/etc/operator/certs:ro" \
  -e KUBERNETES_MASTER=https://240.0.0.1 \
  -e DISABLE_BOOTSTRAP=true \
  -e DISABLE_RECONCILIATION=true \
  dhi.io/stackgres-operator:1.19.5
$ until curl -fs -o /dev/null http://localhost:8080/q/health/live; do sleep 2; done
$ curl http://localhost:8080/q/health/live
$ curl -k https://localhost:8443/q/health/live
```

The operator takes several seconds to start, so the `until` loop waits for the HTTP listener before the two checks.

`KUBERNETES_MASTER` points at an unreachable address, and the two `DISABLE_*` variables stop the operator from
installing resources or reconciling clusters, so the container starts without a Kubernetes cluster.

### Environment variables

| Variable                 | Description                                                      | Default                       | Required |
| ------------------------ | ---------------------------------------------------------------- | ----------------------------- | -------- |
| `OPERATOR_CERT_FILE`     | Path of the TLS certificate for the HTTPS listener               | `/etc/operator/certs/tls.crt` | No       |
| `OPERATOR_KEY_FILE`      | Path of the TLS private key for the HTTPS listener               | `/etc/operator/certs/tls.key` | No       |
| `KUBERNETES_MASTER`      | Kubernetes API server URL, when not using in-cluster credentials | In-cluster service account    | No       |
| `DISABLE_BOOTSTRAP`      | Skip installing CRDs, webhooks, and other bootstrap resources    | `false`                       | No       |
| `DISABLE_RECONCILIATION` | Don't reconcile StackGres custom resources                       | `false`                       | No       |

For example, to read the certificate from another directory:

```bash
$ docker run -d --name stackgres-operator -p 8080:8080 -p 8443:8443 \
  -v "$(pwd)/certs:/run/certs:ro" \
  -e OPERATOR_CERT_FILE=/run/certs/tls.crt \
  -e OPERATOR_KEY_FILE=/run/certs/tls.key \
  -e KUBERNETES_MASTER=https://240.0.0.1 \
  -e DISABLE_BOOTSTRAP=true \
  -e DISABLE_RECONCILIATION=true \
  dhi.io/stackgres-operator:1.19.5
```

### Read-only root filesystem

The operator only needs a writable `/tmp`, so you can run it with a read-only root filesystem:

```bash
$ docker run -d --name stackgres-operator -p 8080:8080 -p 8443:8443 \
  --read-only --tmpfs /tmp \
  -v "$(pwd)/certs:/etc/operator/certs:ro" \
  -e KUBERNETES_MASTER=https://240.0.0.1 \
  -e DISABLE_BOOTSTRAP=true \
  -e DISABLE_RECONCILIATION=true \
  dhi.io/stackgres-operator:1.19.5
```

FIPS variants also need `/tmp` to allow executables, because the Bouncy Castle FIPS provider unpacks a native library
there at startup. Use `--tmpfs /tmp:exec` instead. With a `noexec` `/tmp`, the operator exits with
`UnsatisfiedLinkError ... libbc-probe.so: failed to map segment from shared object`.

## Non-hardened images vs. Docker Hardened Images

- **User:** The image runs as UID 65532 instead of 185. The Helm chart sets UID 185 for upstream's `-jvm` tags and UID
  1000 for this image's tags, so this only matters when you run the container directly.
- **Command:** The image starts the same upstream launcher (`/app/stackgres-operator.sh`) in exec form, with no
  entrypoint. The launcher's environment variables, such as `JAVA_OPTS`, `APP_OPTS`, `OPERATOR_LOG_LEVEL`, and
  `DEBUG_OPERATOR`, work as they do upstream.
- **Java runtime:** The image ships Eclipse Temurin 21 at `/usr/lib/jvm/temurin-21` instead of the UBI OpenJDK at
  `/usr/lib/jvm/java-21`, and doesn't carry the UBI-specific environment variables.
- **Shell and tools:** Runtime variants keep `/bin/sh` for the launcher script (dash on Debian, BusyBox on Alpine) but
  don't include bash, a package manager, or `curl`.
- **Patroni clients:** The image ships patronictl 4.1.5 and 3.3.11 on Python 3.13 instead of upstream's three clients
  (3.2.2, 3.3.3, and 4.1.4). Patroni 3 clusters, including those on 3.2.2, use the 3.3 client.
- **FIPS variants:** FIPS variants set `JAVA_TOOL_OPTIONS` and `JDK_JAVA_OPTIONS` to run Java with the Bouncy Castle
  FIPS provider in approved-only mode. Keep both variables when you add JVM options; add options through `JAVA_OPTS` or
  `developer.extraOpts` instead. The Patroni clients use the OpenSSL FIPS provider.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
