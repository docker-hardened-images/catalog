## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this harbor-registry Hardened image

This image contains `registry`, the Harbor Registry component that provides the Docker Distribution v2 registry for
storing and distributing container images. The entry point for the image is `/usr/local/bin/registry` which serves the
registry API on ports 5000 (HTTP) and 5443 (HTTPS).

## Start a harbor-registry instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `harbor-registry` is designed as a service component that requires a configuration file and typically runs as
part of a Harbor deployment.

```bash
docker run --rm -it dhi.io/harbor-registry:<tag> --help
```

## Common harbor-registry use cases

### Run with configuration file

`harbor-registry` requires a configuration file to run and provides the Docker Distribution v2 registry API.

```bash
# Run with a configuration file (daemon mode with port mapping)
docker run -d --name harbor-registry \
  -p 5000:5000 \
  -v $(pwd)/config.yml:/etc/registry/config.yml \
  dhi.io/harbor-registry:<tag> \
  serve /etc/registry/config.yml

# Test registry API
curl http://localhost:5000/v2/
```

### Available harbor-registry options

The harbor-registry service provides these options:

```bash
# Main command:
# registry serve <config> - Serve the registry API
# registry --help         - Show help information
```

### Run as a daemon service

```bash
docker run -d --name harbor-registry \
  -p 5000:5000 \
  -v $(pwd)/config.yml:/etc/registry/config.yml \
  dhi.io/harbor-registry:<tag> \
  serve /etc/registry/config.yml

# Test registry API
curl http://localhost:5000/v2/
```

### Harbor deployment integration

`harbor-registry` is commonly used as part of Harbor deployments. Here's how to integrate with Helm:

```yaml
# Override Harbor chart to use DHI image in values.yaml
registry:
  registry:
    image:
      repository: dhi.io/harbor-registry
      tag: <tag>
      pullPolicy: IfNotPresent
```

```bash
# Helm install with DHI harbor-registry
# Currently Harbor does not provide arm64 compatible images, so only amd64
# deployments are possible.
helm repo add harbor https://helm.goharbor.io
helm install my-harbor harbor/harbor \
  --set registry.registry.image.repository=dhi.io/harbor-registry \
  --set registry.registry.image.tag=<tag>
```

### Local development and testing

Use `harbor-registry` for local development and testing:

```bash
# Run with config file for testing
docker run --rm -v $(pwd)/config.yml:/etc/registry/config.yml \
  dhi.io/harbor-registry:<tag> \
  serve /etc/registry/config.yml

# Show help
docker run --rm dhi.io/harbor-registry:<tag> --help
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened harbor-registry        | Docker Hardened harbor-registry                     |
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

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/harbor-registry:<tag>
```

## Differences from upstream

The Docker Hardened Image differs from the upstream `goharbor/registry-photon` image in several ways:

### Entrypoint and custom CA certificate installation

**Upstream behavior:**

- Uses an entrypoint script (`/home/harbor/entrypoint.sh`) that:
  - Automatically installs custom CA certificates from `/etc/harbor/ssl` and `/harbor_cust_cert` directories
  - Appends these certificates to the system CA bundle
  - Then executes the registry binary

**DHI behavior:**

- Runs the binary directly (`/usr/local/bin/registry`) without the entrypoint wrapper
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
     - name: registry
       image: dhi.io/harbor-registry:<tag>
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
     registry:
       image: dhi.io/harbor-registry:<tag>
       environment:
         SSL_CERT_FILE: /etc/ssl/certs/ca-certificates.crt
       volumes:
         - ./custom-certs:/custom-certs:ro
         - ./ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt:ro
   ```

1. **Build a custom image** with certificates pre-installed:

   ```dockerfile
   FROM dhi.io/harbor-registry:<tag>
   COPY custom-certs/*.crt /usr/local/share/ca-certificates/
   USER root
   RUN update-ca-certificates
   USER nonroot
   ```

### Healthcheck

**Upstream:** Includes a built-in healthcheck that tests the registry HTTP endpoint.

**DHI:** Does not include a healthcheck. You should define your own healthcheck in your Kubernetes configuration:

**Kubernetes example:**

```yaml
livenessProbe:
  httpGet:
    path: /v2/
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /v2/
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Volumes

**Upstream:** Declares `/storage` as a volume in image metadata.

**DHI:** Does not include volume declarations. Ensure you explicitly mount any required storage paths (such as
`/storage`) in your deployment configuration.

### Binary naming

**Upstream:** The registry binary is named `registry_DO_NOT_USE_GC` to warn against using the registry's built-in
garbage collection (Harbor manages GC through registryctl instead).

**DHI:** The binary is named `registry` without the GC warning suffix.

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

| Item               | Migration note                                                                                                                                                                                                                                                                           |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                                                                                                                      |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                               |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. Custom CA certificate installation from `/etc/harbor/ssl` and `/harbor_cust_cert` is not automatic - see "Differences from upstream" section for workarounds.                                                       |
| Ports              | Non-dev hardened images run as a nonroot user by default. `harbor-registry` typically binds to port 5000 for HTTP APIs. Because hardened images run as nonroot, avoid privileged operations.                                                                                             |
| Entry point        | Docker Hardened Images may have different entry points than standard images. The DHI harbor-registry entry point is `/usr/local/bin/registry`. The upstream entrypoint script that handles custom CA certificate installation is not included - see "Differences from upstream" section. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                              |
| Volume mounting    | When using harbor-registry in containers, ensure proper volume mounting for accessing configuration files from the host filesystem. Upstream declares `/storage` as a volume - DHI does not include volume declarations, so explicitly mount required storage paths.                     |
| Healthcheck        | Upstream includes a built-in healthcheck. DHI does not include a healthcheck - define your own in Kubernetes configuration (see "Differences from upstream" section for examples).                                                                                                       |

The following steps outline the general migration process.

1. **Find hardened images for your Harbor deployment.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The harbor-registry service is typically used as part of Harbor registry deployments.

1. **Update your Harbor Helm chart configurations.**

   Update the image references in your Helm values or Harbor deployment configurations to use the hardened images:

   - From: `goharbor/registry-photon:<tag>`
   - To: `dhi.io/harbor-registry:<tag>`

1. **For custom Harbor deployments, update the base image in your manifests.**

   If you're building custom Harbor deployments, ensure that your registry pod uses the hardened harbor-registry as the
   registry container image.

1. **Update configuration file mounting.**

   Ensure your deployments properly mount configuration files that harbor-registry needs. The service requires access to
   registry configuration through proper volume mounting.

1. **Test Harbor functionality.**

   After migration, verify that registry operations, health checks, and other Harbor functions continue to work
   correctly with the hardened image. Test the `/v2/` endpoint and image push/pull operations.

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

`harbor-registry` requires read access to configuration files and may need write access to registry storage directories.
Ensure your volume mounts and file permissions allow the nonroot user to access these files when running in containers.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Harbor registry
typically uses port 5000 which is not privileged.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
