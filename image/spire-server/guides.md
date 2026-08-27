## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Deploy SPIFFE SPIRE Server in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

SPIFFE SPIRE Server is the central authority in a SPIRE deployment. It manages workload registration entries, performs
node attestation, and issues X.509-SVID and JWT-SVID identities within a trust domain. The server persists state in a
datastore, supports federation with other trust domains, and is intended to run alongside SPIRE Agents as part of a
complete SPIRE stack, typically deployed using the official SPIRE Helm charts.

Replace `<your-namespace>` with your organization's namespace, `<secret name>` with your Kubernetes image pull secret,
and `<tag>` with the image variant you want to use.

## Deploy with the SPIFFE SPIRE Server Helm Chart

The recommended way to deploy SPIFFE SPIRE Server in production is using the
[SPIFFE Helm Charts documentation](https://spiffe.io/docs/latest/spire-helm-charts-hardened-about/). You can override
the SPIRE Server image to use Docker Hardened Images via the values.yaml during installation.

### Configure the SPIRE Server to use the Docker Hardened Image

Create a `values.yaml` file and configure the SPIRE Server to use your Docker Hardened Image:

```yaml
spire-server:
  image:
    registry: <your-registry-name>
    repository: <your-namespace>/dhi-spire-server
    tag: <tag>
  bundlePublisher:
    k8sConfigMap:
      enabled: false
  dataStore:
    sql:
      # Configure external database
      databaseType: postgres
      databaseName: spire
      host: postgresql.spire.svc.cluster.local
      port: 5432
      username: <your-username>
      password: <your-password>
      options:
        - sslmode: disable

# Uncomment and configure if using a private registry
# imagePullSecrets:
#   - name: <secret-name>

```

Before installing the SPIRE Helm chart, ensure you have:

- A running Kubernetes cluster with the SPIFFE SPIRE Server image loaded
- A database configured and accessible from your cluster (you can use the
  [DHI PostgreSQL image](https://hub.docker.com/hardened-images/catalog/dhi/postgres))
- Updated the database connection details in your `values.yaml` to match your setup

### Install the CDRs and SPIRE stack with your custom values

```bash
helm upgrade --install -n <your-namespace> spire-crds spire-crds \
--repo https://spiffe.github.io/helm-charts-hardened/

helm upgrade --install -n <your-namespace> spire spire \
--repo https://spiffe.github.io/helm-charts-hardened/ -f values.yaml
```

### Verify the SPIRE Server is running

```bash
kubectl get pods -n <your-namespace>

kubectl logs -n <your-namespace> spire-server-0 -c spire-server | grep -E "(postgres|Connected|CA prepared|Server APIs)"
```

### Verify the deployment is running with the DHI image

```bash
kubectl -n spire get pods -l app.kubernetes.io/name=server \
  -o jsonpath='{.items[*].spec.containers[0].image}'
```

Expected output:

```
<your-registry-name>/<your-namespace>/spire-server:<tag>
```

## Common use cases

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

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
