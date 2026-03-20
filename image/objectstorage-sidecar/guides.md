## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/objectstorage-sidecar:<tag>`
- Mirrored image: `<your-namespace>/dhi-objectstorage-sidecar:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an Object Storage Sidecar image

The object storage sidecar must be deployed alongside a COSI driver container. The sidecar communicates with the driver
through a Unix domain socket, and both containers must share the same volume for this socket.

### Basic usage

To see available command-line options:

```bash
$ docker run --rm dhi.io/objectstorage-sidecar:<tag> --help
```

### Deployment in Kubernetes

The following example demonstrates a complete working setup using the SeaweedFS COSI driver. You can use other COSI
driver images by replacing the driver container in the deployment below.

Installation requirements vary by driver and deployment platform. Before proceeding, ensure your chosen driver is
compatible with your Kubernetes version and COSI API version. Consult each driver's documentation for specific
requirements, as many provide Helm charts or Kubernetes manifests for easier deployment. See the
[Driver Installation Guide](https://github.com/kubernetes-sigs/container-object-storage-interface/blob/main/docs/src/operations/installing-driver.md)
for general guidance.

When properly deployed, the sidecar connects to the driver and begins managing COSI resources in the cluster. For full
functionality, you'll also need to install the COSI controller manager and configure appropriate RBAC permissions.

#### Prerequisites

1. A running Kubernetes cluster
1. kubectl configured to access your cluster
1. A namespace created (e.g., `kubectl create namespace <cosi-namespace>`)

#### Step 1: Load the images

For minikube or similar local clusters, load the images:

```bash
minikube image load dhi.io/objectstorage-sidecar:<tag>
minikube image load dhi.io/seaweedfs-cosi-driver:<tag>
```

For other Kubernetes distributions, ensure the images are available in your container registry or can be pulled by your
cluster nodes.

#### Step 2: Deploy the COSI provisioner

Deploy both the COSI sidecar and driver together:

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cosi-provisioner
  namespace: <cosi-namespace>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cosi-provisioner
  template:
    metadata:
      labels:
        app: cosi-provisioner
    spec:
      containers:
      - name: seaweedfs-cosi-driver
        image: dhi.io/seaweedfs-cosi-driver:<tag>
        args:
          - "-v=5"
          - "-logtostderr"
        env:
          - name: COSI_ENDPOINT
            value: "unix:///var/lib/cosi/cosi.sock"
        volumeMounts:
          - name: socket-dir
            mountPath: /var/lib/cosi
      - name: cosi-sidecar
        image: dhi.io/objectstorage-sidecar:<tag>
        args:
          - "-d"
          - "unix:///var/lib/cosi/cosi.sock"
          - "-v"
          - "5"
        volumeMounts:
          - name: socket-dir
            mountPath: /var/lib/cosi
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
        - name: socket-dir
          emptyDir: {}
EOF
```

#### Step 3: Verify the connection

Check that both containers are running:

```bash
kubectl get pods -n <cosi-namespace> -l app=cosi-provisioner
```

View the sidecar logs to confirm successful connection:

```bash
kubectl logs -n <cosi-namespace> -l app=cosi-provisioner -c cosi-sidecar
```

You should see a successful connection message:

```bash
"Successfully connected to driver" name="seaweedfs.objectstorage.k8s.io"
```

If you see leader election errors, this is expected when RBAC permissions or COSI CRDs are not yet configured. The
connection between the sidecar and driver is working correctly.

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
