## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rabbitmqoperator-cluster-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-rabbitmqoperator-cluster-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a RabbitMQ Cluster Operator

The RabbitMQ Cluster Kubernetes Operator runs in a Kubernetes cluster. It watches `RabbitmqCluster` custom resources and
reconciles them into workloads, services, and configuration. This image is the operator. The RabbitMQ message broker is
published as a separate image.

Install the operator with the Kubernetes steps below. A local container is useful for printing command-line flags.
Upstream installation, defaults, and cluster configuration are documented at
https://www.rabbitmq.com/kubernetes/operator/install-operator,
https://www.rabbitmq.com/kubernetes/operator/configure-operator-defaults, and
https://www.rabbitmq.com/kubernetes/operator/using-operator. The project source is
https://github.com/rabbitmq/cluster-operator.

### Print command-line flags

```console
$ docker run --rm dhi.io/rabbitmqoperator-cluster-operator:<tag> --help
```

The command prints `Usage of /manager`. Metrics listen on port 8080 (`--metrics-bind-address`, default `:8080`). Health
probes listen on port 8081 (`--health-probe-bind-address`, default `:8081`). The v2.23.3 release manifest serves the
admission webhook on port 9443.

### Install on Kubernetes

Cluster Operator 2.22 and later requires cert-manager before the operator manifest is applied. Install cert-manager
v1.19.4, also exercised by this image's integration test, and wait until its pods are Ready:

```console
$ kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.4/cert-manager.yaml
$ kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=300s
```

Apply the v2.23.3 release manifest with the operator image replaced. That manifest refers to the operator once, as
`ghcr.io/rabbitmq/cluster-operator:2.23.3`:

```console
$ curl -fsSL https://github.com/rabbitmq/cluster-operator/releases/download/v2.23.3/cluster-operator.yml \
  | sed 's|ghcr.io/rabbitmq/cluster-operator:2.23.3|dhi.io/rabbitmqoperator-cluster-operator:<tag>|' \
  | kubectl apply -f -
```

The manifest creates Deployment `rabbitmq-cluster-operator` in namespace `rabbitmq-system`. Authenticate the cluster to
`dhi.io` and add the pull secret to that Deployment. The patch rolls the pod so it can pull the image:

```console
$ kubectl -n rabbitmq-system create secret docker-registry dhi-pull --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
$ kubectl -n rabbitmq-system patch deployment rabbitmq-cluster-operator -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"dhi-pull"}]}}}}'
```

See https://docs.docker.com/dhi/how-to/use/.

The same manifest includes cert-manager Certificate `cluster-operator-serving-cert`. Its `secretName` is
`cluster-operator-webhook-server-cert`. After cert-manager issues the certificate, the operator container mounts that
secret at `/tmp/k8s-webhook-server/serving-certs`. Kubernetes creates that path from the secret volume. The webhook
server reads its serving certificate from the mount.

The release manifest supplies the operator namespace from the pod namespace. When that value is unset, the process logs
`unable to find operator namespace` and exits.

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
