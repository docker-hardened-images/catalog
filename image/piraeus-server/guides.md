## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/piraeus-server:<tag>`
- Mirrored image: `<your-namespace>/dhi-piraeus-server:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this piraeus-server image

This Docker Hardened piraeus-server image includes:

- **linstor** - The LINSTOR command-line client for managing storage resources
- **Controller** - The LINSTOR controller binary (at `/usr/share/linstor-server/bin/Controller`) for managing cluster
  state and coordinating storage operations
- **Satellite** - The LINSTOR satellite binary (at `/usr/share/linstor-server/bin/Satellite`) for managing local DRBD
  resources on storage nodes
- **kubectl** - Kubernetes command-line tool for cluster management
- **k8s-await-election** - Utility for waiting on Kubernetes leader election before starting services
- **losetup-container** - Container-aware loop device management utility for storage operations
- **piraeus-entry.sh** - Entrypoint script that orchestrates LINSTOR controller and satellite startup

## Start a piraeus-server image

Piraeus Server is the core storage engine of the Piraeus stack, built on LINSTOR and DRBD technology. It can run in
three modes: as a **controller** (manages cluster state and coordinates storage operations), as a **satellite** (runs on
each storage node and manages local DRBD resources), or in **combined** mode. In production Kubernetes deployments, the
Piraeus Operator automatically deploys and configures these components, but the image can also be run standalone for
testing or non-Kubernetes environments.

### Basic usage (satellite mode)

```bash
docker run -d --name piraeus-server \
  --privileged \
  -p 3366:3366 -p 3367:3367 -p 3370:3370 -p 3371:3371 -p 3376:3376 -p 3377:3377 \
  dhi.io/piraeus-server:<tag> startSatellite
```

### Controller mode

```bash
docker run -d --name piraeus-controller \
  -p 3370:3370 -p 3371:3371 \
  -v piraeus-controller-data:/var/lib/linstor \
  dhi.io/piraeus-server:<tag> startController
```

**Note:** The `/var/lib/linstor` directory is pre-created in the image with proper nonroot ownership. When using volume
mounts, ensure the volume has correct permissions for the nonroot user (UID 65532).

### Exposed ports

| Port | Description      |
| ---- | ---------------- |
| 3366 | Satellite plain  |
| 3367 | Satellite SSL    |
| 3370 | Controller plain |
| 3371 | Controller SSL   |
| 3376 | Combined plain   |
| 3377 | Combined SSL     |

## Common piraeus-server use cases

### Kubernetes deployment via Piraeus Operator

The recommended way to deploy Piraeus Server is through the Piraeus Operator, which manages the lifecycle of LINSTOR
components. The operator handles controller and satellite deployment, configuration, and scaling:

```bash
helm repo add piraeus-charts https://piraeus.io/helm-charts/
helm repo update
helm install piraeus-operator piraeus-charts/piraeus-operator \
  --set installCRDs=true \
  --set linstorSatelliteImage.repository=dhi.io/piraeus-server \
  --set linstorSatelliteImage.tag=<tag> \
  --set linstorControllerImage.repository=dhi.io/piraeus-server \
  --set linstorControllerImage.tag=<tag>
```

### Standalone controller deployment

For testing or non-Kubernetes environments, you can run the controller standalone:

```bash
docker run -d --name piraeus-controller \
  -p 3370:3370 -p 3371:3371 \
  -v piraeus-controller-data:/var/lib/linstor \
  dhi.io/piraeus-server:<tag> startController
```

### Standalone satellite deployment

Run a satellite node that connects to an external controller:

```bash
docker run -d --name piraeus-satellite \
  --privileged \
  -p 3366:3366 -p 3367:3367 \
  -v /dev:/dev \
  -v piraeus-satellite-data:/var/lib/linstor \
  -e LINSTOR_CONTROLLERS=http://controller-host:3370 \
  dhi.io/piraeus-server:<tag> startSatellite
```

### Check LINSTOR cluster status

Once deployed, verify the cluster status using the LINSTOR client:

```bash
# Using kubectl exec
kubectl exec -it deployment/linstor-controller -- linstor node list

# Or using docker exec
docker exec -it piraeus-controller linstor node list
```

## Differences vs upstream piraeus-server image

When migrating from upstream `quay.io/piraeusdatastore/piraeus-server` to Docker Hardened Images, note these key
differences:

| Aspect             | Upstream           | DHI                                | Migration Impact                                                    |
| ------------------ | ------------------ | ---------------------------------- | ------------------------------------------------------------------- |
| User               | `root`             | `nonroot` (UID 65532)              | Volume mounts need proper permissions for nonroot user              |
| `/var/lib/linstor` | Created at runtime | Pre-created with nonroot ownership | Volume mounts work correctly; ensure volumes have correct ownership |
| Shell              | May vary           | `bash` included                    | Shell is available for debugging and entrypoint scripts             |

**Volume permissions:** When using volume mounts for `/var/lib/linstor`, ensure the volume has correct ownership. In
Kubernetes, the Piraeus Operator handles this automatically. For standalone Docker usage, you may need to initialize
volumes with proper permissions:

```bash
# Create volume with correct ownership
docker volume create piraeus-controller-data
docker run --rm -v piraeus-controller-data:/data \
  --entrypoint chown dhi.io/piraeus-server:<tag> \
  -R 65532:65532 /data
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
