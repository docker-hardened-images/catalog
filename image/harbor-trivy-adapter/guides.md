## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/harbor-trivy-adapter:<tag>`
- Mirrored image: `<your-namespace>/dhi-harbor-trivy-adapter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the Harbor Trivy Adapter Hardened Image to integrate Trivy
vulnerability scanning with Harbor registry.

### What's included in this Harbor Trivy Adapter Hardened Image

This Docker Hardened Harbor Trivy Adapter image includes:

- The scanner-trivy binary: Harbor's REST API adapter for Trivy
- The trivy binary: The Trivy vulnerability scanner

### Start the Harbor Trivy Adapter

```bash
docker run -d --name harbor-trivy-adapter -p 8080:8080 dhi.io/harbor-trivy-adapter:<tag>
```

The adapter starts and listens on port 8080 for HTTP requests from Harbor.

## Common use cases

### Deploy with Harbor using Docker Compose

You can deploy the Harbor Trivy Adapter alongside Harbor using Docker Compose:

```yaml
services:
  trivy-adapter:
    image: dhi.io/harbor-trivy-adapter:<tag>
    container_name: trivy-adapter
    restart: always
    environment:
      SCANNER_LOG_LEVEL: info
      SCANNER_TRIVY_CACHE_DIR: /home/scanner/.cache/trivy
      SCANNER_TRIVY_REPORTS_DIR: /home/scanner/.cache/reports
      SCANNER_TRIVY_VULN_TYPE: "os,library"
      SCANNER_TRIVY_SEVERITY: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
      SCANNER_API_SERVER_ADDR: ":8080"
    ports:
      - 8080:8080
    volumes:
      - trivy-cache:/home/scanner/.cache

volumes:
  trivy-cache:
```

### Configure in Harbor

1. Log in to Harbor as an administrator.
1. Navigate to **Interrogation Services** > **Scanners**.
1. Click **New Scanner**.
1. Configure the scanner:
   - Name: `Trivy`
   - Endpoint URL: `http://trivy-adapter:8080`
1. Click **Test Connection** to verify.
1. Click **Add** to save the scanner.

### Environment variables

The Harbor Trivy Adapter supports the following environment variables:

| Variable                           | Description                         | Default                            |
| ---------------------------------- | ----------------------------------- | ---------------------------------- |
| `SCANNER_API_SERVER_ADDR`          | API server listen address           | `:8080`                            |
| `SCANNER_API_SERVER_READ_TIMEOUT`  | API server read timeout             | `15s`                              |
| `SCANNER_API_SERVER_WRITE_TIMEOUT` | API server write timeout            | `15s`                              |
| `SCANNER_LOG_LEVEL`                | Log level                           | `info`                             |
| `SCANNER_TRIVY_CACHE_DIR`          | Trivy cache directory               | `/home/scanner/.cache/trivy`       |
| `SCANNER_TRIVY_REPORTS_DIR`        | Reports cache directory             | `/home/scanner/.cache/reports`     |
| `SCANNER_TRIVY_VULN_TYPE`          | Vulnerability types to scan         | `os,library`                       |
| `SCANNER_TRIVY_SEVERITY`           | Severity levels to report           | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` |
| `SCANNER_TRIVY_IGNORE_UNFIXED`     | Ignore unfixed vulnerabilities      | `false`                            |
| `SCANNER_TRIVY_SKIP_UPDATE`        | Skip Trivy DB update                | `false`                            |
| `SCANNER_TRIVY_INSECURE`           | Allow insecure registry connections | `false`                            |

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Harbor Trivy Adapter   | Docker Hardened Harbor Trivy Adapter         |
| --------------- | ----------------------------------- | -------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                 |
| Package manager | tdnf available (Photon OS)          | No package manager in runtime variants       |
| User            | scanner user (UID 10000)            | Runs as nonroot user (UID 65532)             |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components           |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount              |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/harbor-trivy-adapter:<tag>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

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

## Differences from upstream

The Docker Hardened Image differs from the upstream `goharbor/trivy-adapter-photon` image in several ways:

### Entrypoint and custom CA certificate installation

**Upstream behavior:**

- Uses an entrypoint script (`/home/scanner/entrypoint.sh`) that:
  - Automatically installs custom CA certificates from `/etc/harbor/ssl` and `/harbor_cust_cert` directories
  - Appends these certificates to the system CA bundle (`/etc/pki/tls/certs/ca-bundle.crt`)
  - Then executes the scanner-trivy binary

**DHI behavior:**

- Runs the binary directly (`/usr/local/bin/scanner-trivy`) without the entrypoint wrapper
- Does not automatically install custom CA certificates
- Uses standard system CA certificates from the ca-certificates package

**Impact:**

For most deployments that use public registries or registries with publicly-trusted certificates, no changes are needed.
However, if your Harbor deployment uses custom CA certificates (self-signed or private CA), you'll need to manually
configure certificate trust using one of the workarounds below.

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
           cat /etc/ssl/certs/ca-certificates.crt > /shared-ca-bundle/ca-bundle.crt
           if [ -d /etc/harbor/ssl ]; then
             find /etc/harbor/ssl -name ca.crt -exec cat {} \; >> /shared-ca-bundle/ca-bundle.crt
           fi
           if [ -d /harbor_cust_cert ]; then
             find /harbor_cust_cert \( -name "*.crt" -o -name "*.ca" -o -name "*.pem" \) | while read f; do
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
     - name: trivy-adapter
       image: dhi.io/harbor-trivy-adapter:<tag>
       env:
         - name: SSL_CERT_FILE
           value: /shared-ca-bundle/ca-bundle.crt
       volumeMounts:
         - name: shared-ca-bundle
           mountPath: /shared-ca-bundle
   volumes:
     - name: harbor-ssl
       secret:
         secretName: harbor-tls-ca
     - name: harbor-cust-cert
       secret:
         secretName: harbor-custom-certs
     - name: shared-ca-bundle
       emptyDir: {}
   ```

1. **Mount certificates and set SSL_CERT_FILE** (Docker/Docker Compose):

   Create a `ca-bundle.crt` file that contains both the standard system CA certificates and your custom certificates
   concatenated together. Then mount it into the container:

   ```yaml
   services:
     trivy-adapter:
       image: dhi.io/harbor-trivy-adapter:<tag>
       environment:
         SSL_CERT_FILE: /etc/ssl/certs/ca-certificates.crt
       volumes:
         - ./ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt:ro
   ```

1. **Use insecure mode** (not recommended for production):

   Set `SCANNER_TRIVY_INSECURE=true` to skip certificate verification. This should only be used for testing.

## Migrate to a Docker Hardened Image

Switching to the hardened Harbor Trivy Adapter image does not require any special changes for most deployments. You can
use it as a drop-in replacement for the standard image (`goharbor/trivy-adapter-photon`) in your existing workflows and
configurations. Note that the hardened image runs as UID 65532 (nonroot) instead of UID 10000 (scanner), so update any
file permissions or volume mounts accordingly.

**Important:** If your Harbor deployment uses custom CA certificates (self-signed or private CA), see the "Differences
from upstream" section for required configuration changes.

### Migration steps

1. Update your image reference.

   Replace the image reference in your Docker run command, Compose file, or Kubernetes manifests:

   - From: `goharbor/trivy-adapter-photon:<tag>`
   - To: `dhi.io/harbor-trivy-adapter:<tag>`

1. Update the user ID if necessary.

   The hardened image runs as UID 65532. Update any file permissions or volume mounts:

   ```bash
   chown -R 65532:65532 /path/to/cache
   ```

1. All your existing environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. The Harbor Trivy Adapter uses port 8080 by default, which is
not a privileged port, so this should not be an issue.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point and custom CA certificates

The DHI harbor-trivy-adapter uses `/usr/local/bin/scanner-trivy` as the entrypoint, while the upstream image
(`goharbor/trivy-adapter-photon`) uses `/home/scanner/entrypoint.sh`. The upstream entrypoint script automatically
installs custom CA certificates from `/etc/harbor/ssl` and `/harbor_cust_cert` directories before starting the scanner.

If your Harbor deployment uses custom CA certificates, you must manually configure certificate trust. See the
"Differences from upstream" section for detailed workarounds including init containers and volume mounts.
