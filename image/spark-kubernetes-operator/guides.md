## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Spark Kubernetes Operator image

The Apache Spark Kubernetes Operator is intended to run as a Kubernetes controller. It reconciles `SparkApplication` and
`SparkCluster` custom resources and manages Spark workloads on your cluster.

For local smoke testing, you can start the operator process directly. Replace `<tag>` with the image variant you want to
run (for example `1.0-debian13`):

```bash
$ docker run --rm dhi.io/spark-kubernetes-operator:<tag>
```

The operator requires a Kubernetes API and configured RBAC to function. In production, deploy it with the upstream Helm
chart and point the controller image at this hardened image.

### Environment variables

The image preserves upstream environment variables for compatibility:

| Variable                  | Description                            | Default                         | Required |
| ------------------------- | -------------------------------------- | ------------------------------- | -------- |
| `JAVA_HOME`               | Java installation directory            | `/usr/lib/jvm/temurin-26`       | No       |
| `SPARK_OPERATOR_HOME`     | Operator installation root             | `/opt/spark-operator`           | No       |
| `SPARK_OPERATOR_WORK_DIR` | Working directory for the operator JAR | `/opt/spark-operator/operator`  | No       |
| `SPARK_OPERATOR_JAR`      | Operator JAR filename in the work dir  | `spark-kubernetes-operator.jar` | No       |
| `SPARK_USER`              | Runtime user name                      | `spark`                         | No       |

> **Note:** Upstream images may document JVM options via shell entrypoints. DHI runtime images do not include a shell.
> Pass JVM flags by overriding the container command, for example:
>
> ```bash
> $ docker run --rm dhi.io/spark-kubernetes-operator:<tag> \
>   -Xmx512m -cp ./spark-kubernetes-operator.jar org.apache.spark.k8s.operator.SparkOperator
> ```

### Using in Kubernetes

Install the upstream Helm chart and override the operator image repository and tag:

```bash
$ helm repo add spark-kubernetes-operator https://apache.github.io/spark-kubernetes-operator
$ helm install spark-kubernetes-operator spark-kubernetes-operator/spark-kubernetes-operator \
  --namespace spark-operator \
  --create-namespace \
  --set image.repository=dhi.io/spark-kubernetes-operator \
  --set image.tag=<tag>
```

Consult the [upstream documentation](https://github.com/apache/spark-kubernetes-operator) for CRD installation, RBAC,
and workload examples.

### Multi-stage build example

Use a `-dev` variant to prepare build-time artifacts, then copy them into a runtime variant:

```dockerfile
FROM dhi.io/spark-kubernetes-operator:1.0-debian13-dev AS builder
# build steps here

FROM dhi.io/spark-kubernetes-operator:1.0-debian13
# copy artifacts and run
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened upstream image           | Docker Hardened Spark Kubernetes Operator           |
| --------------- | ------------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities   | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available        | No shell in runtime variants                        |
| Package manager | apt available in some upstream builds | No package manager in runtime variants              |
| User            | Runs as `spark` (uid 185)             | Runs as `spark` (uid 185)                           |
| Attack surface  | Larger due to additional utilities    | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging           | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers should not be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened runtime images do not contain a shell or debugging tools. Common troubleshooting approaches include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Kubernetes-native debugging (`kubectl logs`, events, and controller metrics)

For example:

```bash
$ docker debug <container-name>
```

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

   For Debian-based images, you can use `apt-get` to install packages.

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

The DHI Spark Kubernetes Operator image runs `java` directly with
`-cp ./spark-kubernetes-operator.jar org.apache.spark.k8s.operator.SparkOperator`, rather than using a shell entrypoint
script like some upstream distributions. Standard usage is unaffected; if you need to pass JVM flags, override the
container command as shown in [Environment variables](#environment-variables).
