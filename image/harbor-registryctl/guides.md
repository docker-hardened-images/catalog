## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this harbor-registryctl Hardened image

This image contains `harbor-registryctl`, the Harbor Registry Control component that provides HTTP APIs for managing
Docker Registry backend operations. The entry point for the image is `/usr/local/bin/harbor-registryctl` which provides
registry management APIs including health monitoring, garbage collection coordination, and registry configuration
management.

## Start a harbor-registryctl instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `harbor-registryctl` is designed as a service component that requires a configuration file and typically runs
as part of a Harbor deployment.

```bash
docker run --rm -it dhi.io/harbor-registryctl:<tag> -h
```

## Common harbor-registryctl use cases

### Run with configuration file

`harbor-registryctl` requires a configuration file to run and provides HTTP APIs for registry management operations.

```bash
# Run with a configuration file (daemon mode with port mapping)
docker run -d --name harbor-registryctl \
  -p 8080:8080 \
  -v $(pwd)/config.yml:/etc/registryctl/config.yml \
  dhi.io/harbor-registryctl:<tag> \
  -c /etc/registryctl/config.yml

# Health check endpoint test
curl http://localhost:8080/api/health
```

### Available harbor-registryctl options

The harbor-registryctl service provides these options:

```bash
# Main Options:
# -c string    - Specify registryctl configuration file path (required)
# -h           - Show help information
```

### Run as a daemon service

```bash
docker run -d --name harbor-registryctl \
  -p 8080:8080 \
  -v $(pwd)/config.yml:/etc/registryctl/config.yml \
  dhi.io/harbor-registryctl:<tag> \
  -c /etc/registryctl/config.yml

# Test health endpoint
curl http://localhost:8080/api/health
```

### Harbor deployment integration

`harbor-registryctl` is commonly used as part of Harbor deployments. Here's how to integrate with Helm:

```yaml
# Override Harbor chart to use DHI image in values.yaml
registry:
  registryctl:
    image:
      repository: dhi.io/harbor-registryctl
      tag: <tag>
      pullPolicy: IfNotPresent
```

```bash
# Helm install with DHI harbor-registryctl
# Currently Harbor does not provide arm64 compatible images, so only amd64
# deployments are possible.
helm install my-harbor oci://helm.goharbor.io/harbor \
  --set registry.registryctl.image.repository=dhi.io/harbor-registryctl \
  --set registry.registryctl.image.tag=<tag>
```

### Local development and testing

Use `harbor-registryctl` for local development and testing:

```bash
# Run with config file for testing
docker run --rm -v $(pwd)/config.yml:/etc/registryctl/config.yml \
  dhi.io/harbor-registryctl:<tag> \
  -c /etc/registryctl/config.yml

# Show help
docker run --rm dhi.io/harbor-registryctl:<tag> -h
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened harbor-registryctl     | Docker Hardened harbor-registryctl                  |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
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
docker debug dhi.io/harbor-registryctl
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/harbor-registryctl:<tag>
```

## Differences from upstream

The Docker Hardened Image differs from the upstream `goharbor/harbor-registryctl` image in several ways:

### Entrypoint and custom CA certificate installation

**Upstream behavior:**

- Uses an entrypoint script (`/home/harbor/start.sh`) that:
  - Automatically installs custom CA certificates from `/etc/harbor/ssl` and `/harbor_cust_cert` directories
  - Appends these certificates to the system CA bundle
  - Then executes the harbor-registryctl binary

**DHI behavior:**

- Runs the binary directly (`/usr/local/bin/harbor-registryctl`) without the entrypoint wrapper
- Does not automatically install custom CA certificates

**Workaround for custom CA certificates:**

If you need to use custom CA certificates, you have several options:

1. **Use an init container** (Kubernetes):

   ```yaml
   initContainers:
     - name: install-certs
       image: dhi.io/busybox:1
       command:
         - sh
         - -c
         - |
           if [ -d /etc/harbor/ssl ]; then
             find /etc/harbor/ssl -name ca.crt -exec cat {} \; >> /shared-ca-bundle/ca-bundle.crt
           fi
           if [ -d /harbor_cust_cert ]; then
             find /harbor_cust_cert -name "*.crt" -o -name "*.ca" -o -name "*.pem" | while read f; do
               [ -f "$f" ] && cat "$f" >> /shared-ca-bundle/ca-bundle.crt
             done
           fi
       volumeMounts:
         - name: harbor-ssl
           mountPath: /etc/harbor/ssl
           readOnly: true
         - name: harbor-cust-cert
           mountPath: /harbor_cust_cert
           readOnly: true
         - name: shared-ca-bundle
           mountPath: /shared-ca-bundle
   containers:
     - name: registryctl
       image: dhi.io/harbor-registryctl:<tag>
       env:
         - name: SSL_CERT_FILE
           value: /shared-ca-bundle/ca-bundle.crt
       volumeMounts:
         - name: shared-ca-bundle
           mountPath: /shared-ca-bundle
   volumes:
     - name: harbor-ssl
     - name: harbor-cust-cert
     - name: shared-ca-bundle
       emptyDir: {}
   ```

1. **Mount certificates and set SSL_CERT_FILE** (Docker/Docker Compose):

   ```yaml
   services:
     registryctl:
       image: dhi.io/harbor-registryctl:<tag>
       environment:
         SSL_CERT_FILE: /etc/ssl/certs/ca-certificates.crt
       volumes:
         - ./custom-certs:/custom-certs:ro
         - ./ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt:ro
   ```

1. **Build a custom image** with certificates pre-installed:

   ```dockerfile
   FROM dhi.io/harbor-registryctl:<tag>
   COPY custom-certs/*.crt /usr/local/share/ca-certificates/
   USER root
   RUN update-ca-certificates
   USER nonroot
   ```

### Healthcheck

**Upstream:** Includes a built-in healthcheck that tests both HTTP (port 8080) and HTTPS (port 8443) endpoints.

**DHI:** Does not include a healthcheck. You should define your own healthcheck in your Kubernetes or Docker Compose
configuration:

**Kubernetes example:**

```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /api/health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Docker Compose example:**

```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/api/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

### Volumes

**Upstream:** Declares `/var/lib/registry` as a volume in image metadata.

**DHI:** Does not include volume declarations. Ensure you explicitly mount any required storage paths (such as
`/var/lib/registry`) in your deployment configuration.

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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                        |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                             |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                            |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. Custom CA certificate installation from `/etc/harbor/ssl` and `/harbor_cust_cert` is not automatic - see "Differences from upstream" section for workarounds.                                                                    |
| Ports              | Non-dev hardened images run as a nonroot user by default. `harbor-registryctl` typically binds to port 8080 for HTTP APIs. Because hardened images run as nonroot, avoid privileged operations.                                                                                                       |
| Entry point        | Docker Hardened Images may have different entry points than standard images. The DHI harbor-registryctl entry point is `/usr/local/bin/harbor-registryctl`. The upstream entrypoint script that handles custom CA certificate installation is not included - see "Differences from upstream" section. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                           |
| Volume mounting    | When using harbor-registryctl in containers, ensure proper volume mounting for accessing configuration files from the host filesystem. Upstream declares `/var/lib/registry` as a volume - DHI does not include volume declarations, so explicitly mount required storage paths.                      |
| Healthcheck        | Upstream includes a built-in healthcheck. DHI does not include a healthcheck - define your own in Kubernetes or Docker Compose configuration (see "Differences from upstream" section for examples).                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your Harbor deployment.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The harbor-registryctl service is typically used as part of Harbor registry deployments.

1. **Update your Harbor Helm chart configurations.**

   Update the image references in your Helm values or Harbor deployment configurations to use the hardened images:

   - From: `goharbor/harbor-registryctl:<tag>`
   - To: `dhi.io/harbor-registryctl:<tag>`

1. **For custom Harbor deployments, update the base image in your manifests.**

   If you're building custom Harbor deployments, ensure that your registry pod uses the hardened harbor-registryctl as
   the registryctl container image.

1. **Update configuration file mounting.**

   Ensure your deployments properly mount configuration files that harbor-registryctl needs. The service requires access
   to registry configuration through proper volume mounting.

1. **Test Harbor functionality.**

   After migration, verify that registry operations, health checks, and other Harbor functions continue to work
   correctly with the hardened image. Test the `/api/health` endpoint and registry management operations.

## Troubleshoot migration

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

`harbor-registryctl` requires read access to configuration files and may need write access to registry storage
directories. Ensure your volume mounts and file permissions allow the nonroot user to access these files when running in
containers.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Harbor
registryctl typically uses port 8080 which is not privileged.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
