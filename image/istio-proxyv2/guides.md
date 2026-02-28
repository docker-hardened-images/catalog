## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- **Public image**: `dhi.io/istio-proxyv2:<tag>`
- **Mirrored image**: `<your-namespace>/dhi-istio-proxyv2:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this istio-proxyv2 image

This Docker Hardened Image includes:

- Istio proxy binaries and configuration
- Pilot-agent for managing the proxy lifecycle
- Enhanced security with non-root user operation (UID 1337)
- CIS compliance for runtime variants; FIPS 140 + STIG + CIS compliance for FIPS variants

## Start an Istio Proxy v2 instance

Istio Proxy v2 is designed to function as a sidecar in a service mesh and requires an active Istio control plane. It
cannot be run as a standalone container.

### Install Istio control plane

First, install the Istio control plane on your Kubernetes cluster.

```bash
# Download and install istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with minimal profile
istioctl install --set profile=minimal -y

# Verify the control plane is running
kubectl get pods -n istio-system
```

### Create a namespace with sidecar injection

Create a namespace and enable automatic Istio sidecar injection:

```bash
# Create namespace
kubectl create namespace istio-app

# Enable Istio sidecar injection
kubectl label namespace istio-app istio-injection=enabled

# Verify the label
kubectl get namespace istio-app --show-labels
```

### Create an image pull secret

Create a Kubernetes secret so the cluster can pull images from the DHI registry:

```bash
kubectl create secret docker-registry dhi-registry-secret \
    --docker-server=dhi.io \
    --docker-username=<your-username> \
    --docker-password=<your-password> \
    -n istio-app
```

### Deploy your application with the DHI sidecar

Create the deployment manifest with the DHI istio-proxyv2 sidecar:

```bash
cat > deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
  namespace: istio-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
        - name: example-app
          image: dhi.io/nginx:1-debian13
          ports:
            - containerPort: 8080
        - name: istio-proxy
          image: dhi.io/istio-proxyv2:1.28.4
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 1337
      imagePullSecrets:
      - name: dhi-registry-secret
EOF

kubectl apply -f deployment.yaml
```

### Verify the deployment

```bash
# Check pod status - both containers should show 2/2 READY
kubectl get pods -n istio-app

# Verify the sidecar is connected to the control plane
kubectl logs -n istio-app -l app=example-app -c istio-proxy --tail=10
```

You should see `Envoy proxy is ready` in the logs, confirming the sidecar has connected to the Istio control plane.

## Common istio-proxyv2 use cases

### Service mesh sidecar deployment

The primary use case is automatic sidecar injection in Kubernetes pods within an Istio service mesh.

### Traffic management with virtual services

Create a VirtualService to manage traffic routing through the service mesh:

```bash
cat > virtual-service.yaml << 'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: example-app
  namespace: istio-app
spec:
  hosts:
  - example-app
  http:
  - route:
    - destination:
        host: example-app
        port:
          number: 8080
EOF

kubectl apply -f virtual-service.yaml
```

### Verify mTLS is active

The DHI sidecar automatically handles mutual TLS between services:

```bash
# Check workload certificate status
kubectl logs -n istio-app -l app=example-app -c istio-proxy | grep -i "cert\|tls\|trust"
```

You should see entries confirming workload certificate generation and trust anchor caching.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature             | Standard (`istio/proxyv2`) | Docker Hardened (`dhi.io/istio-proxyv2`)          |
| ------------------- | -------------------------- | ------------------------------------------------- |
| **User**            | root (default)             | 1337 (istio-proxy)                                |
| **Shell**           | Bash                       | None                                              |
| **Package manager** | Yes (apt)                  | None                                              |
| **Entrypoint**      | /usr/local/bin/pilot-agent | /usr/local/bin/pilot-agent                        |
| **Image size**      | ~99 MB (uncompressed)      | ~60 MB (uncompressed)                             |
| **Zero CVE**        | No                         | Yes (zero critical/high/medium)                   |
| **FIPS variant**    | No                         | Yes                                               |
| **Base OS**         | Ubuntu 24.04               | Docker Hardened Images (Debian 13)                |
| **Compliance**      | None                       | CIS (runtime); FIPS 140, STIG, CIS (FIPS variant) |
| **Architectures**   | amd64, arm64               | amd64, arm64                                      |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- **Docker Debug** to attach to containers
- **Docker's Image Mount feature** to mount debugging tools
- **Kubernetes-specific debugging** with `kubectl debug`

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For Kubernetes environments, you can use kubectl debug:

```bash
kubectl debug -n istio-app pod/<pod-name> -it --image=busybox --target=istio-proxy
```

Or use Docker Debug if you have access to the node:

```bash
docker debug <container-id>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run the Istio proxy in production. These images:

- Run as the istio-proxy user (UID 1337)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the proxy
- Carry CIS compliance labels

**FIPS variants** are designed for environments that require FIPS 140 compliance. These images:

- Include FIPS-validated cryptographic libraries
- Carry FIPS 140, STIG, and CIS compliance labels
- Are slightly larger than runtime variants due to FIPS crypto libraries

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                 | Migration note                                                                                                                                                                                                                                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Base image**       | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                   |
| **Non-root user**    | By default, the DHI istio-proxyv2 runs as the istio-proxy user (UID 1337). Ensure that necessary files and directories are accessible to this user.                                                                                                                                                         |
| **TLS certificates** | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                          |
| **Ports**            | Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.                                                                                           |
| **Entry point**      | Both the standard and DHI istio-proxyv2 images use `/usr/local/bin/pilot-agent` as the entrypoint. However, Docker Hardened Images for other products may have different entry points than their standard counterparts. Inspect entry points with `docker inspect` and update your Dockerfile if necessary. |
| **No shell**         | By default, runtime images don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                        |

The following steps outline the general migration process.

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step.

1. **Verify permissions.** Since the image runs as the istio-proxy user (UID 1337), ensure that data directories and
   mounted volumes are accessible to this user.

## Troubleshoot migration

### General debugging

The recommended method for debugging applications built with Docker Hardened Images is to use **Docker Debug** to attach
to these containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in an
ephemeral, writable layer that only exists during the debugging session.

### Permissions

By default the DHI istio-proxyv2 runs as the istio-proxy user (UID 1337). Ensure that necessary files and directories
are accessible to this user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Both the standard and
DHI istio-proxyv2 images use `/usr/local/bin/pilot-agent` as the entrypoint. For other DHI images, use `docker inspect`
to verify entry points and update your Dockerfile if necessary.
