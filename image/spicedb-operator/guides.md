## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About the SpiceDB Operator

The SpiceDB Operator is a Kubernetes operator that manages the lifecycle of SpiceDB clusters. It installs custom
resource definitions and watches for `SpiceDBCluster` resources to provision and upgrade SpiceDB instances. It requires
cluster-admin permissions and a running Kubernetes cluster with `kubectl` configured to access it.

### Deploy the SpiceDB Operator

Apply the operator bundle manifest to your cluster. Replace `<tag>` with the image variant you want to run.

```bash
kubectl create namespace spicedb-operator
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spicedb-operator
  namespace: spicedb-operator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spicedb-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: spicedb-operator
  namespace: spicedb-operator
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spicedb-operator
  namespace: spicedb-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spicedb-operator
  template:
    metadata:
      labels:
        app: spicedb-operator
    spec:
      serviceAccountName: spicedb-operator
      containers:
      - name: spicedb-operator
        image: dhi.io/spicedb-operator:<tag>
        args: [run, --crd=true]
EOF
```

Verify the operator is running:

```bash
kubectl rollout status deployment/spicedb-operator -n spicedb-operator
kubectl get pods -n spicedb-operator
```

### Create a SpiceDBCluster

Once the operator is running, create a `SpiceDBCluster` resource to provision a SpiceDB instance. Create the required
secret first, then the cluster resource.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-spicedb-config
  namespace: default
stringData:
  preshared_key: "changeme"
---
apiVersion: authzed.com/v1alpha1
kind: SpiceDBCluster
metadata:
  name: my-spicedb
  namespace: default
spec:
  channel: stable
  config:
    datastoreEngine: memory
  secretName: my-spicedb-config
EOF
```

The operator reconciles the resource and creates a SpiceDB deployment in the same namespace:

```bash
kubectl get spicedbcluster
kubectl get deployment my-spicedb
```

### Use a persistent datastore

The `memory` datastore is suitable for development only. For production, configure SpiceDB with a supported persistent
datastore. Pass datastore connection details in the secret rather than the cluster spec to avoid exposing credentials.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-spicedb-config
  namespace: default
stringData:
  preshared_key: "changeme"
  datastore_uri: "postgres://user:password@host:5432/spicedb?sslmode=disable"
---
apiVersion: authzed.com/v1alpha1
kind: SpiceDBCluster
metadata:
  name: my-spicedb
  namespace: default
spec:
  channel: stable
  config:
    datastoreEngine: postgres
  secretName: my-spicedb-config
EOF
```

Supported datastore engines: `memory`, `postgres`, `mysql`, `cockroachdb`, `spanner`.

### Upgrade SpiceDB

The operator follows its built-in update graph to determine valid upgrade paths. To upgrade, update `spec.channel` or
`spec.version` in the `SpiceDBCluster` resource. The operator validates the upgrade is safe before applying it.

```bash
kubectl patch spicedbcluster my-spicedb --type merge \
  -p '{"spec": {"version": "v1.44.0"}}'
```

Monitor the upgrade:

```bash
kubectl get spicedbcluster my-spicedb -w
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your SpiceDB Operator deployment to a Docker Hardened Image, update the image reference in your Deployment
manifest. The DHI image uses the same entrypoint and flags as the upstream image.

| Item               | Migration note                                                                                                                                                          |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace the upstream `authzed/spicedb-operator` image reference with `dhi.io/spicedb-operator:<tag>`.                                                                   |
| Package management | Non-dev images don't contain package managers. Use images with a `dev` tag only in build stages.                                                                        |
| Non-root user      | Non-dev images run as nonroot (UID 65532). Ensure any mounted config files and volumes are accessible to this user.                                                     |
| No shell           | Non-dev images don't contain a shell. Use Docker Debug to attach to running containers for troubleshooting.                                                             |
| Entry point        | The hardened image uses `/usr/bin/spicedb-operator` as its entrypoint, matching the upstream binary. Existing `args` in your Deployment spec work without modification. |
| FIPS compliance    | Switch to a `-fips` tagged variant to enable FIPS 140-3 mode across all cryptographic operations. No changes to `SpiceDBCluster` resources are required.                |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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
