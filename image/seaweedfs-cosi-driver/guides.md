## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/seaweedfs-cosi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-seaweedfs-cosi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a SeaweedFS COSI Driver image

The SeaweedFS COSI Driver is designed to run in Kubernetes as part of a COSI (Container Object Storage Interface)
deployment. The driver implements the COSI controller interfaces and enables Kubernetes workloads to provision and
manage object storage backed by a SeaweedFS cluster.

### Deployment in Kubernetes

The SeaweedFS COSI Driver can be deployed as a standalone controller. When using the SeaweedFS Helm chart, COSI support
must be explicitly enabled in the chart values. The Kubernetes COSI controller and CRDs must be installed in the cluster
before deploying the driver.

#### Step 1: Install COSI Controller and CRDs

Install the Kubernetes COSI controller and Custom Resource Definitions directly from the official repository:

```bash
# Install COSI CRDs
kubectl apply -k https://github.com/kubernetes-sigs/container-object-storage-interface/client/config/crd

# Install COSI controller
kubectl apply -k https://github.com/kubernetes-sigs/container-object-storage-interface/controller
```

#### Step 2: Load DHI Image into Cluster

If you're using a local Kubernetes cluster like kind and testing with the DHI image, you need to load the image into the
cluster:

```bash
kind load docker-image <your-namespace>/dhi-seaweedfs-cosi-driver:<tag> --name <seaweedfs-namespace>

docker exec <seaweedfs-namespace>-control-plane crictl images | grep seaweedfs-cosi
```

#### Step 3: Download and Prepare SeaweedFS Helm Chart

```bash
# Add SeaweedFS Helm repository
helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
helm repo update

# Download chart locally for modification
helm pull seaweedfs/seaweedfs --untar --untardir /tmp
```

#### Step 4: Fix COSI Template API Version

> **Note:** The SeaweedFS Helm chart (as of version 4.0.406) contains COSI templates that use the deprecated `v1alpha1`
> API version and incorrect spec structure. The COSI
> [BucketClass](https://github.com/kubernetes-sigs/container-object-storage-interface/blob/main/client/config/crd/objectstorage.k8s.io_bucketclasses.yaml)
> and
> [BucketAccessClass](https://github.com/kubernetes-sigs/container-object-storage-interface/blob/main/client/config/crd/objectstorage.k8s.io_bucketaccessclasses.yaml)
> CRDs use `v1alpha2`, so the template must be updated to match.

Replace the COSI bucket class template with the correct v1alpha2 format:

```bash
cat > /tmp/seaweedfs/templates/cosi/cosi-bucket-class.yaml << 'EOF'
{{- if and .Values.cosi.enabled .Values.cosi.bucketClassName }}
---
kind: BucketClass
apiVersion: objectstorage.k8s.io/v1alpha2
metadata:
  name: {{ .Values.cosi.bucketClassName }}
spec:
  driverName: {{ .Values.cosi.driverName }}
  deletionPolicy: Delete
---
kind: BucketAccessClass
apiVersion: objectstorage.k8s.io/v1alpha2
metadata:
  name: {{ .Values.cosi.bucketClassName }}
spec:
  driverName: {{ .Values.cosi.driverName }}
  authenticationType: Key
{{- end }}
EOF
```

The changes made:

1. Updated `apiVersion` from `objectstorage.k8s.io/v1alpha1` to `objectstorage.k8s.io/v1alpha2`
1. Moved `driverName` and `deletionPolicy` under `spec:` section (required by v1alpha2)
1. Changed `authenticationType` from `KEY` to `Key` (case correction)

#### Step 5: Create Helm Values File

```bash
cat > /tmp/cosi-values.yaml << 'EOF'
cosi:
  enabled: true
  image: <your-namespace>/dhi-seaweedfs-cosi-driver:<tag>
  imagePullPolicy: Always
EOF
```

#### Step 6: Install SeaweedFS with COSI Driver

```bash
helm install seaweedfs /tmp/seaweedfs \
  -f /tmp/cosi-values.yaml \
  --namespace <seaweedfs-namespace> \
  --create-namespace
```

#### Step 7: Verify Deployment

Verify the DHI COSI driver image is running:

```bash
# Get the objectstorage-provisioner pod name
POD_NAME=$(kubectl get pods -n <seaweedfs-namespace> -l app.kubernetes.io/component=objectstorage-provisioner -o jsonpath='{.items[0].metadata.name}')

# Verify the DHI image is running
kubectl get pod -n <seaweedfs-namespace> $POD_NAME -o jsonpath='{.spec.containers[?(@.name=="dhi-seaweedfs-cosi-driver")].image}' && echo
```

Expected output: `<your-namespace>/dhi-seaweedfs-cosi-driver:<tag>` (or your specified image)

```bash
# Verify the conatiners
kubectl get pod -n <seaweedfs-namespace> $POD_NAME -o jsonpath='{.spec.containers[*].name}' && echo
```

Expected output: `seaweedfs-objectstorage-provisioner` pod contains two containers:

- **seaweedfs-cosi-driver**: Your DHI COSI driver image
- **seaweedfs-cosi-sidecar**: The COSI sidecar that communicates with the COSI controller

```bash
# Verify the logs
kubectl logs -n <seaweedfs-namespace> $POD_NAME -c seaweedfs-cosi-sidecar --tail=10 | grep "renewed lease"
```

Expected output: `successfully renewed lease <seaweedfs-namespace>/seaweedfs-objectstorage-k8s-io-cosi`

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
