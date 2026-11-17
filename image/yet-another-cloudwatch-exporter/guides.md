## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/yet-another-cloudwatch-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-yet-another-cloudwatch-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this yet-another-cloudwatch-exporter image

This image contains YACE (`yace`), a Prometheus exporter for AWS CloudWatch that auto-discovers AWS resources via tags
and exposes their metrics on port 5000. The image ships with an example EC2 discovery configuration at
`/etc/yace/config.yml` so the container starts without requiring an externally mounted config file. AWS credentials are
required at runtime to connect to CloudWatch — supply them via IRSA, environment variables, or a mounted credentials
file as described in the [Authentication section](#aws-credentials) below.

## Run the yet-another-cloudwatch-exporter container

Run the following command, replacing `<tag>` with the image variant you want to use. AWS credentials must be available
in the container's environment.

```bash
docker run -d --name yace -p 5000:5000 \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=<your-key-id> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret-key> \
  dhi.io/yet-another-cloudwatch-exporter:<tag>
```

Once running, Prometheus metrics are available at `http://localhost:5000/metrics`.

To inspect available CLI flags, run:

```bash
docker run --rm dhi.io/yet-another-cloudwatch-exporter:<tag> --help
```

## AWS credentials

YACE uses the
[AWS SDK for Go default credential chain](https://aws.github.io/aws-sdk-go-v2/docs/configuring-sdk/#specifying-credentials).
The following methods are all supported:

- **IRSA (recommended for Kubernetes)** — annotate the pod's service account with an IAM role ARN. No additional
  environment variables are needed.
- **Environment variables** — set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` (or
  `AWS_DEFAULT_REGION`).
- **Shared credentials file** — mount `~/.aws/credentials` into the container at `/home/nonroot/.aws/credentials` (the
  runtime image runs as the nonroot user).

The IAM policy attached to the credentials must grant the CloudWatch and resource-tagging permissions YACE needs, with
additional permissions required per namespace. See the
[upstream authentication docs](https://github.com/prometheus-community/yet-another-cloudwatch-exporter#authentication)
for the full list.

## Use a custom configuration file

The image ships a default EC2 discovery config at `/etc/yace/config.yml`. To use your own configuration, mount it over
that path:

```bash
docker run -d --name yace -p 5000:5000 \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=<your-key-id> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret-key> \
  -v $(pwd)/yace-config.yml:/etc/yace/config.yml:ro \
  dhi.io/yet-another-cloudwatch-exporter:<tag>
```

Refer to the
[upstream configuration docs](https://github.com/prometheus-community/yet-another-cloudwatch-exporter/blob/master/docs/configuration.md)
for the full configuration reference.

## Docker Compose with Prometheus

The following Compose example runs YACE alongside Prometheus. The `prometheus-init` service (using `dhi.io/busybox:1`)
pre-creates the data volume with the correct ownership because the DHI Prometheus image runs as a nonroot user (uid
65532).

```yaml
services:
  yace:
    image: dhi.io/yet-another-cloudwatch-exporter:<tag>
    environment:
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=<your-key-id>
      - AWS_SECRET_ACCESS_KEY=<your-secret-key>
    volumes:
      - ./yace-config.yml:/etc/yace/config.yml:ro
    ports:
      - "5000:5000"
    restart: unless-stopped

  prometheus-init:
    image: dhi.io/busybox:1
    user: "0:0"
    volumes:
      - prometheus-data:/var/prometheus
    command: ["chown", "-R", "65532:65532", "/var/prometheus"]
    restart: "no"

  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/var/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/var/prometheus'
    depends_on:
      prometheus-init:
        condition: service_completed_successfully
      yace:
        condition: service_started
    restart: unless-stopped

volumes:
  prometheus-data: {}
```

Create a matching Prometheus scrape configuration:

```yaml
global:
  scrape_interval: 60s

scrape_configs:
  - job_name: yace
    static_configs:
      - targets: ['yace:5000']
```

Start the stack:

```bash
docker compose up -d
```

## Deploy on Kubernetes with the upstream Helm chart

Install YACE using the official community Helm chart and override the image to use the Docker Hardened Image. Replace
`<your-registry-secret>` with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>`
with the desired image tag.

```bash
helm install yace oci://ghcr.io/prometheus-community/charts/prometheus-yet-another-cloudwatch-exporter \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=yet-another-cloudwatch-exporter \
  --set image.tag=<tag>
```

Verify the installation:

```bash
kubectl get pods -l app.kubernetes.io/name=prometheus-yet-another-cloudwatch-exporter
```

For IRSA-based authentication in Kubernetes, annotate the Helm-managed service account with your IAM role ARN:

```bash
helm install yace oci://ghcr.io/prometheus-community/charts/prometheus-yet-another-cloudwatch-exporter \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=yet-another-cloudwatch-exporter \
  --set image.tag=<tag> \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<account-id>:role/<role-name>
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
