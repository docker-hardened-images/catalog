## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this x509-certificate-exporter image

This Docker Hardened x509-certificate-exporter image includes:

- The `x509-certificate-exporter` binary built from the official enix/x509-certificate-exporter releases
- Prometheus metrics endpoint on port 9793
- Health check endpoint at `/healthz`
- Support for watching certificate files from mounted directories or Kubernetes secrets
- The entrypoint is the x509-certificate-exporter binary at `/usr/local/bin/x509-certificate-exporter`

## Common x509-certificate-exporter Hardened Image use cases

This guide provides practical examples for using the x509-certificate-exporter Hardened Image to monitor X.509
certificate expiration in Kubernetes clusters or standalone environments.

### Run a x509-certificate-exporter container

#### Basic usage with certificate directory

```bash
docker run -d --name x509-exporter \
    -p 9793:9793 \
    -v /path/to/certs:/certs:ro \
    dhi.io/x509-certificate-exporter:<tag> \
    --watch-dir=/certs
```

#### With custom listen address

```bash
docker run -d --name x509-exporter \
    -p 8080:8080 \
    -v /path/to/certs:/certs:ro \
    dhi.io/x509-certificate-exporter:<tag> \
    --watch-dir=/certs \
    --listen-address=:8080
```

### Run with Docker Compose

#### Monitor a single certificate directory

1. Create Docker Compose:

Create `docker-compose.yaml`.

```yaml
services:
  x509-exporter:
    image: dhi.io/x509-certificate-exporter:<tag>
    ports:
      - "9793:9793"
    volumes:
      - /etc/ssl/certs:/certs:ro
    command:
      - --watch-dir=/certs
    restart: unless-stopped
```

2. Start the exporter:

```bash
docker compose up -d
```

3. Verify it's running:

```bash
curl http://localhost:9793/metrics | grep x509_cert
```

#### Monitor multiple certificate directories

Use `docker-compose.yaml`:

```yaml
services:
  x509-exporter:
    image: dhi.io/x509-certificate-exporter:<tag>
  ports:
    - "9793:9793"
  volumes:
    - /etc/ssl/certs:/certs:ro
    - /etc/pki/tls:/tls:ro
    - /app/certificates:/app-certs:ro
  command:
    - --watch-dir=/certs
    - --watch-dir=/tls
    - --watch-dir=/app-certs
  restart: unless-stopped
```

### Integration with Prometheus

1. Create `docker-compose.yaml` with Prometheus:

```yaml
services:
  x509-exporter:
    image: dhi.io/x509-certificate-exporter:<tag>
    ports:
      - "9793:9793"
    volumes:
      - /etc/ssl/certs:/certs:ro
    command:
      - --watch-dir=/certs
restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    depends_on:
      - x509-exporter
```

2. Create `prometheus.yml`

```yaml
global:
  scrape_interval: 60s

scrape_configs:
  - job_name: 'x509-exporter'
    static_configs:
      - targets: ['x509-exporter:9793']
```

3. Start the stack:

```bash
docker compose up -d
```

4. Access Prometheus at `http://localhost:9090` and query certificate metrics:

```bash
# Certificates expiring in less than 30 days
x509_cert_not_after - time() < 86400 * 30

# Expired certificates
x509_cert_expired == 1
```

### Use x509-certificate-exporter in Kubernetes

1. Deploy as a DaemonSet to monitor certificates on all nodes:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: x509-certificate-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: x509-certificate-exporter
  template:
    metadata:
      labels:
        app: x509-certificate-exporter
    spec:
      containers:
        - name: x509-exporter
          image: dhi.io/x509-certificate-exporter:<tag>
          args:
            - --watch-dir=/host-certs
            - --watch-dir=/host-pki
          ports:
            - containerPort: 9793
              name: metrics
          volumeMounts:
            - name: host-certs
              mountPath: /host-certs
              readOnly: true
            - name: host-pki
              mountPath: /host-pki
              readOnly: true
          livenessProbe:
            httpGet:
              path: /healthz
              port: 9793
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /healthz
              port: 9793
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: host-certs
          hostPath:
            path: /etc/ssl/certs
        - name: host-pki
          hostPath:
            path: /etc/pki/tls
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: x509-certificate-exporter
  namespace: monitoring
  labels:
    app: x509-certificate-exporter
spec:
  ports:
    - port: 9793
      targetPort: 9793
      name: metrics
  selector:
    app: x509-certificate-exporter
```

2. Apply the manifest:

```bash
kubectl apply -f x509-exporter.yaml
```

3. Verify the deployment:

```bash
kubectl get pods -n monitoring -l app=x509-certificate-exporter
```

### Monitor Kubernetes secrets

1. Deploy as a Deployment to watch Kubernetes TLS secrets:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: x509-certificate-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: x509-certificate-exporter
  template:
    metadata:
      labels:
        app: x509-certificate-exporter
    spec:
      serviceAccountName: x509-certificate-exporter
      containers:
        - name: x509-exporter
          image: dhi.io/x509-certificate-exporter:<tag>
          args:
            - --watch-kube-secrets
          ports:
            - containerPort: 9793
              name: metrics
          livenessProbe:
            httpGet:
              path: /healthz
              port: 9793
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /healthz
              port: 9793
            initialDelaySeconds: 5
            periodSeconds: 10
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: x509-certificate-exporter
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: x509-certificate-exporter
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: x509-certificate-exporter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: x509-certificate-exporter
subjects:
  - kind: ServiceAccount
    name: x509-certificate-exporter
    namespace: monitoring
```

### Prometheus ServiceMonitor (for Prometheus Operator)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: x509-certificate-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: x509-certificate-exporter
  endpoints:
    - port: metrics
      interval: 60s
      path: /metrics
```

## Available metrics

The exporter provides the following Prometheus metrics:

| Metric                          | Type    | Description                                                 |
| ------------------------------- | ------- | ----------------------------------------------------------- |
| `x509_cert_not_before`          | Gauge   | Certificate validity start time (Unix timestamp)            |
| `x509_cert_not_after`           | Gauge   | Certificate expiration time (Unix timestamp)                |
| `x509_cert_expired`             | Gauge   | 1 if certificate is expired, 0 otherwise                    |
| `x509_cert_expires_in_seconds`  | Gauge   | Number of seconds until certificate expires (optional)      |
| `x509_cert_valid_since_seconds` | Gauge   | Number of seconds since certificate became valid (optional) |
| `x509_cert_error`               | Gauge   | Certificate parsing/validation error indicator (optional)   |
| `x509_read_errors`              | Counter | Number of errors reading certificates                       |
| `x509_exporter_build_info`      | Gauge   | Build information including version and revision            |

## Command-line options

Common command-line flags:

| Flag                      | Description                                                                | Default |
| ------------------------- | -------------------------------------------------------------------------- | ------- |
| `--watch-dir=<path>`      | Watch one or more directory which contains x509 cert files (not recursive) | -       |
| `--watch-kube-secrets`    | Scrape kubernetes secrets and monitor them                                 | false   |
| `--listen-address=<addr>` | Address on which to bind and expose metrics                                | `:9793` |
| `--version`               | Show version information                                                   | -       |
| `--help`                  | Show help message                                                          | -       |

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Argo CD Image Updater  | Docker Hardened Argo CD Image Updater               |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user (UID 1000)                     |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/argocd-image-updater:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/argocd-image-updater:<tag> /dbg/bin/sh
```

### Image variants

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

- FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
  validated under FIPS 140, a U.S. government standard for secure cryptographic operations. For example, usage of MD5
  fails in FIPS variants.

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
