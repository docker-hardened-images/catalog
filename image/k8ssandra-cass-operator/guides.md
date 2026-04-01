## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8ssandra-cass-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-k8ssandra-cass-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Understanding cass-operator

The k8ssandra-cass-operator is a Kubernetes operator that manages Apache Cassandra clusters. It is designed to run
inside a Kubernetes cluster and watches for CassandraDatacenter custom resources. When deployed, the operator automates:

- Provisioning of Cassandra datacenters
- Scaling operations
- Rolling restarts and upgrades
- Container failure remediation
- Rack-aware topology management

The operator is typically deployed via Helm or Kustomize and runs as a Kubernetes Deployment. It is not meant to be run
directly with `docker run` but rather deployed as part of a Kubernetes cluster.

## Deploy cass-operator in Kubernetes

### Using Helm (recommended)

The most common way to deploy cass-operator is using Helm. First, add the k8ssandra Helm repository:

```bash
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
```

If admission webhooks are enabled, the cass-operator chart requires cert-manager to be installed in the cluster before
you install the chart.

Then install the operator using the Docker Hardened Image:

```bash
helm install cass-operator k8ssandra/cass-operator \
  -n cass-operator \
  --create-namespace \
  --set image.registry=dhi.io \
  --set image.repository=k8ssandra-cass-operator \
  --set image.tag=<tag>
```

### Using Kustomize

Create a `kustomization.yaml` file to deploy the operator with the Docker Hardened Image:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cass-operator

resources:
  - github.com/k8ssandra/cass-operator/config/deployments/default?ref=v1.28.1

images:
  - name: k8ssandra/cass-operator
    newName: dhi.io/k8ssandra-cass-operator
    newTag: <tag>
```

Apply the configuration:

```bash
kubectl apply -k .
```

Verify the operator is running:

```bash
kubectl -n cass-operator get pods \
  --selector control-plane=cass-operator-controller-manager
```

### Using a Kubernetes Deployment manifest

For more control, you can create a Deployment manifest directly:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cass-operator
  namespace: cass-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: cass-operator
  template:
    metadata:
      labels:
        name: cass-operator
    spec:
      serviceAccountName: cass-operator
      containers:
      - name: manager
        image: dhi.io/k8ssandra-cass-operator:<tag>
        command:
        - /manager
        args:
        - --leader-elect
        - --health-probe-bind-address=:8081
        - --metrics-bind-address=:8080
        - --metrics-secure=false
        ports:
        - containerPort: 8080
          name: metrics
          protocol: TCP
        - containerPort: 8081
          name: health
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

## Common cass-operator use cases

### Basic Cassandra cluster deployment

Once the operator is running, create a CassandraDatacenter custom resource to deploy a Cassandra cluster:

```yaml
apiVersion: cassandra.datastax.com/v1beta1
kind: CassandraDatacenter
metadata:
  name: dc1
  namespace: cassandra
spec:
  clusterName: demo-cluster
  serverType: cassandra
  serverVersion: "4.0.7"
  managementApiAuth:
    insecure: {}
  size: 3
  storageConfig:
    cassandraDataVolumeClaimSpec:
      storageClassName: standard
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
  config:
    cassandra-yaml:
      authenticator: org.apache.cassandra.auth.PasswordAuthenticator
      authorizer: org.apache.cassandra.auth.CassandraAuthorizer
    jvm-server-options:
      initial_heap_size: "2G"
      max_heap_size: "2G"
```

Apply the configuration:

```bash
kubectl apply -f cassandra-datacenter.yaml
```

The operator will create the necessary StatefulSets, Services, and other resources to run the Cassandra cluster.

### Multi-rack deployment

Deploy Cassandra across multiple failure domains (racks):

```yaml
apiVersion: cassandra.datastax.com/v1beta1
kind: CassandraDatacenter
metadata:
  name: dc1
  namespace: cassandra
spec:
  clusterName: multi-rack-cluster
  serverType: cassandra
  serverVersion: "4.0.7"
  managementApiAuth:
    insecure: {}
  size: 6
  racks:
    - name: rack1
      nodeAffinityLabels:
        topology.kubernetes.io/zone: us-east-1a
    - name: rack2
      nodeAffinityLabels:
        topology.kubernetes.io/zone: us-east-1b
    - name: rack3
      nodeAffinityLabels:
        topology.kubernetes.io/zone: us-east-1c
  storageConfig:
    cassandraDataVolumeClaimSpec:
      storageClassName: standard
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 20Gi
```

This configuration creates 3 racks with 2 nodes each, distributed across different availability zones.

### Configure the operator with supported Helm values and CLI flags

The `cass-operator` manager binary does not expose a generic `--config` file flag. When deploying this image, use Helm
values supported by the chart or pass explicit CLI flags to `/manager`.

For Helm-based installs, configure supported chart values directly:

```bash
helm install cass-operator k8ssandra/cass-operator \
  -n cass-operator \
  --create-namespace \
  --set image.registry=dhi.io \
  --set image.repository=k8ssandra-cass-operator \
  --set image.tag=<tag> \
  --set fullnameOverride=cass-operator \
  --set metrics.address=:8443 \
  --set metrics.tls.enabled=true
```

For manifest-based deployments, pass supported flags explicitly to `/manager`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cass-operator
  namespace: cass-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: cass-operator
  template:
    metadata:
      labels:
        name: cass-operator
    spec:
      serviceAccountName: cass-operator
      containers:
      - name: manager
        image: dhi.io/k8ssandra-cass-operator:<tag>
        command:
        - /manager
        args:
        - --leader-elect
        - --health-probe-bind-address=:8081
        - --metrics-bind-address=:8443
        - --metrics-secure=true
        - --metrics-cert-path=/certs
        - --metrics-cert-name=tls.crt
        - --metrics-cert-key=tls.key
        ports:
        - containerPort: 8443
          name: metrics
          protocol: TCP
        - containerPort: 8081
          name: health
          protocol: TCP
        volumeMounts:
        - name: certs
          mountPath: /certs
          readOnly: true
      volumes:
      - name: certs
        secret:
          secretName: metrics-server-cert
```

To see the flags supported by the current image, run `/manager --help` in the container image or inspect the upstream
chart values before overriding them.

### Operator with secure metrics endpoint

Enable secure metrics with TLS:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cass-operator
  namespace: cass-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: cass-operator
  template:
    metadata:
      labels:
        name: cass-operator
    spec:
      serviceAccountName: cass-operator
      containers:
      - name: manager
        image: dhi.io/k8ssandra-cass-operator:<tag>
        command:
        - /manager
        args:
        - --leader-elect
        - --metrics-bind-address=:8443
        - --metrics-secure=true
        - --metrics-cert-path=/certs
        - --metrics-cert-name=tls.crt
        - --metrics-cert-key=tls.key
        ports:
        - containerPort: 8443
          name: metrics
          protocol: TCP
        volumeMounts:
        - name: certs
          mountPath: /certs
          readOnly: true
      volumes:
      - name: certs
        secret:
          secretName: metrics-server-cert
```

### Cluster-scoped operator deployment

Deploy the operator to watch all namespaces:

```bash
# Using Kustomize with cluster scope
kubectl apply --force-conflicts --server-side \
  -k github.com/k8ssandra/cass-operator/config/deployments/cluster?ref=v1.28.1
```

Or with a custom Kustomization:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cass-operator

resources:
  - github.com/k8ssandra/cass-operator/config/deployments/default?ref=v1.28.1

components:
  - github.com/k8ssandra/cass-operator/config/components/cluster?ref=v1.28.1

images:
  - name: k8ssandra/cass-operator
    newName: dhi.io/k8ssandra-cass-operator
    newTag: <tag>
```

### Monitoring with Prometheus

Deploy the operator with Prometheus ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cass-operator-metrics
  namespace: cass-operator
spec:
  selector:
    matchLabels:
      name: cass-operator
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: v1
kind: Service
metadata:
  name: cass-operator-metrics
  namespace: cass-operator
  labels:
    name: cass-operator
spec:
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
  selector:
    name: cass-operator
```

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened k8ssandra-cass-operator image has the following key differences from the upstream image:

### User and permissions

The DHI image runs as a nonroot user (UID 65532) by default. Current upstream images also run as a nonroot user, but you
should still verify user, group, and `securityContext` expectations when migrating manifests between image variants.

### Minimal base image

The DHI image is built on a minimal Debian 13 base with only essential libraries, reducing the attack surface. The
upstream image may include additional tools and utilities that are not necessary for production operation.

### No shell or package manager

The runtime DHI image does not include a shell or package manager. For debugging, use `kubectl logs` to view operator
logs or use Docker Debug for interactive troubleshooting.

### Shell availability

The upstream k8ssandra/cass-operator image includes a shell (/bin/sh) for debugging and troubleshooting. The DHI image
does not include a shell to reduce attack surface. For debugging DHI deployments, use `kubectl logs` to view operator
logs or use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) for interactive troubleshooting.

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

## FIPS

A FIPS-compliant variant of this image is available with the `-fips` suffix (e.g., `k8ssandra-cass-operator:1-fips`).

The FIPS variant is built with a FIPS-enabled Go toolchain and uses FIPS-aware cryptographic settings at runtime via the
following environment variables:

```
GODEBUG=fips140=on
GOFIPS140=v1.0.0
```

`GODEBUG=fips140=on` enables Go's FIPS mode without enforcing strict `fips140=only` behavior, which can break
Kubernetes-related runtime paths used by this operator. `GOFIPS140=v1.0.0` pins the Go FIPS module version.

The FIPS variant also includes the OpenSSL FIPS provider for any operations that delegate to OpenSSL.

Use the FIPS variant when deploying in environments that require FIPS 140-2 compliance, such as US federal government
workloads or FedRAMP-authorized systems.
