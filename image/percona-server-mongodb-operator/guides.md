## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Deploy the operator

The operator runs in Kubernetes. Install the custom resource definitions, RBAC, and the operator deployment from the
upstream bundle for your operator version, then point the deployment at the hardened image. Replace `<version>` with the
operator version (for example `1.23.0`) and `<tag>` with the matching image tag.

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mongodb-operator/v<version>/deploy/bundle.yaml
kubectl set image deployment/percona-server-mongodb-operator \
  percona-server-mongodb-operator=dhi.io/percona-server-mongodb-operator:<tag>
kubectl rollout status deployment/percona-server-mongodb-operator
```

The operator serves Prometheus metrics on port 8080 and health probes on port 8081.

## Deploy a Percona Server for MongoDB cluster

Create the users secret and a `PerconaServerMongoDB` custom resource. Replace `<version>` with the same operator version
as above.

```bash
kubectl apply -f https://raw.githubusercontent.com/percona/percona-server-mongodb-operator/v<version>/deploy/secrets.yaml
kubectl apply -f https://raw.githubusercontent.com/percona/percona-server-mongodb-operator/v<version>/deploy/cr.yaml
kubectl get psmdb
```

The operator injects this image as the init container of every database pod. The init container runs
`/init-entrypoint.sh`, which copies `mongodb-healthcheck` and the database entrypoint scripts into the shared
`/opt/percona` volume that the database containers use. When the `crVersion` in the custom resource matches the operator
version, the operator uses its own image for the init container, so no extra configuration is needed. To pin it
explicitly, set `spec.initImage` to `dhi.io/percona-server-mongodb-operator:<tag>` in the custom resource.

For backups, sharding, monitoring, and other advanced configuration, see the
[Percona Operator for MongoDB documentation](https://docs.percona.com/percona-operator-for-mongodb/index.html).

## Non-hardened images vs. Docker Hardened Images

- The operator binary is installed at `/usr/bin/percona-server-mongodb-operator`. The upstream path
  `/usr/local/bin/percona-server-mongodb-operator` resolves through a symlink, and it is also the image entrypoint. The
  upstream image sets no entrypoint.
- `mongodb-healthcheck` is installed at `/usr/bin/mongodb-healthcheck`. The upstream root path `/mongodb-healthcheck`
  resolves through a symlink, so `/init-entrypoint.sh` copies it into `/opt/percona` exactly as upstream does.
- The image runs as the nonroot user 65532. The upstream image runs as user 2. Percona's manifests don't pin
  `runAsUser`, so this doesn't affect standard deployments.
- The upstream image ships license texts under `/licenses` and Mozilla-licensed module sources under `/lib/hashicorp`.
  This image doesn't. License and provenance information is carried by the image SBOM and attestations instead.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **percona-server-mongodb-operator is an exception:** runtime variants include `bash` and GNU coreutils, because the
  image also runs as the init container of database pods and its `/init-entrypoint.sh` is a bash script that uses
  `install` and `cp` to populate the shared `/opt/percona` volume.

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
with no shell. **percona-server-mongodb-operator is an exception:** its runtime variants keep `bash` for the init
container entrypoint script.
