## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this harbor-core Hardened image

This image contains the Harbor Core binary. It is the main API server for the Harbor registry and is responsible for
REST APIs, database migrations, authentication, certificate management, and email template processing. It is one of
several services in a Harbor deployment and is intended to run alongside `harbor-portal`, `harbor-jobservice`,
`harbor-registry`, PostgreSQL, and Redis. The entrypoint for this image is `/usr/local/bin/harbor-core`.

## Start a harbor-core instance

`harbor-core` is a long-running service that needs a database and cache on startup; running it with no configuration
will crash immediately with `failed to initialize cache`. The command below only shows the list of environment variables
the binary understands:

```bash
docker run --rm dhi.io/harbor-core:<tag> -h
```

To verify the image boots against real backing services, run it under Docker Compose alongside the sibling Hardened
Harbor images `dhi.io/harbor-db` (hardened PostgreSQL for Harbor) and `dhi.io/harbor-redis` (hardened Redis for Harbor):

```yaml
# compose.yaml
services:
  harbor-db:
    image: dhi.io/harbor-db:<tag>
    environment:
      POSTGRES_PASSWORD: root123
    volumes:
      - harbor-db-data:/var/lib/postgresql/data
    healthcheck:
      test: [CMD, /docker-healthcheck.sh]
      interval: 5s
      retries: 30
      start_period: 30s

  harbor-redis:
    image: dhi.io/harbor-redis:<tag>
    healthcheck:
      test: [CMD, redis-cli, ping]
      interval: 5s
      retries: 30

  harbor-core:
    image: dhi.io/harbor-core:<tag>
    depends_on:
      harbor-db:
        condition: service_healthy
      harbor-redis:
        condition: service_healthy
    environment:
      CORE_SECRET: not-so-secret
      JOBSERVICE_SECRET: not-so-secret
      CORE_URL: http://harbor-core:8080
      EXT_ENDPOINT: http://localhost:8080
      REGISTRY_URL: http://harbor-registry:5000
      TOKEN_SERVICE_URL: http://harbor-core:8080/service/token
      LOG_LEVEL: info
      DATABASE_TYPE: postgresql
      POSTGRESQL_HOST: harbor-db
      POSTGRESQL_PORT: "5432"
      POSTGRESQL_USERNAME: postgres
      POSTGRESQL_PASSWORD: root123
      POSTGRESQL_DATABASE: registry
      POSTGRESQL_SSLMODE: disable
      _REDIS_URL_CORE: redis://harbor-redis:6379/0
      _REDIS_URL_REG: redis://harbor-redis:6379/1
      HARBOR_ADMIN_PASSWORD: Harbor12345
    ports:
      - "8080:8080"

volumes:
  harbor-db-data:
```

This runtime image does **not** ship `/etc/core/app.conf`, `/harbor/conf/app.conf`, or another bundled `app.conf`. The
upstream image does not include that file either; Harbor deployments that use `CONFIG_PATH` normally provide it at
runtime through the chart or another volume mount. The compose example uses environment variables instead. If you rely
on a file-backed `app.conf`, set `CONFIG_PATH` to a path **inside the container** and mount a readable file or volume
there yourself.

`harbor-core` alone does not serve the Harbor UI; that responsibility belongs to `harbor-portal`. The compose stack
above only confirms that Core starts, connects to its dependencies, and reaches the "server is ready" log line. To
exercise the full product (including the UI) use the Helm chart below.

## Common harbor-core use cases

### Deploy the full Harbor stack with Helm

The supported way to run harbor-core end-to-end is via the upstream Harbor Helm chart, overriding only the `core`
subchart to use the Docker Hardened Image.

Create `values.yaml`:

```yaml
expose:
  type: nodePort
  tls:
    enabled: false

externalURL: http://<node-ip>:30002

harborAdminPassword: Harbor12345

core:
  image:
    repository: dhi.io/harbor-core
    tag: <tag>
  # The upstream image starts through /harbor/entrypoint.sh before execing the
  # Core binary. The hardened image does not ship that Photon wrapper, so the
  # chart command needs to point at the binary directly.
  command:
    - /usr/local/bin/harbor-core
```

The upstream entrypoint runs certificate setup and then starts `/harbor/harbor_core`. The hardened image starts the Core
binary directly at `/usr/local/bin/harbor-core`; if your deployment relied on the upstream wrapper for custom
certificate setup, handle that with a chart value, secret/config mount, or init container before Core starts.

Replace `<node-ip>` with a reachable IP on the cluster node (for example, the output of `minikube ip` or the node
address from `kubectl get nodes -o wide`). Then install:

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update

helm install my-harbor harbor/harbor -f values.yaml
```

Once the `my-harbor-core` deployment reports `Ready`, open `http://<node-ip>:30002` and sign in as `admin` with the
password from `harborAdminPassword`. Harbor enforces CSRF via a secure cookie, so the UI will refuse to log in when
served over HTTPS with a self-signed certificate that your browser rejects. For a quick local test, prefer the plain
HTTP NodePort configuration above; for any real deployment terminate TLS at an ingress controller with a trusted
certificate.

### Ship the Core binary without the chart (advanced)

If you run Harbor without the community chart, reuse the environment variables from the compose example above and ensure
the container has read access to `/harbor/migrations` (bundled in this image under `/harbor`). Core will fail on startup
with `failed to apply database schema` if the migrations directory is unreadable.

```bash
docker run -d --name harbor-core \
  -e CORE_SECRET=... \
  -e JOBSERVICE_SECRET=... \
  -e DATABASE_TYPE=postgresql \
  -e POSTGRESQL_HOST=harbor-db \
  -e POSTGRESQL_PORT=5432 \
  -e POSTGRESQL_USERNAME=postgres \
  -e POSTGRESQL_PASSWORD=... \
  -e POSTGRESQL_DATABASE=registry \
  -e _REDIS_URL_CORE=redis://harbor-redis:6379/0 \
  -e _REDIS_URL_REG=redis://harbor-redis:6379/1 \
  -e HARBOR_ADMIN_PASSWORD=Harbor12345 \
  -p 8080:8080 \
  --network harbor-network \
  dhi.io/harbor-core:<tag>
```

### Inspect the running service

The container exposes the management API on port 8080.

```bash
curl http://localhost:8080/api/v2.0/health
curl http://localhost:8080/api/v2.0/systeminfo
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened harbor-core            | Docker Hardened harbor-core                         |
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

```bash
docker debug dhi.io/harbor-core:<tag>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  dhi.io/harbor-core:<tag> /dbg/bin/sh
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

- FIPS variants include `fips` in the variant name and tag and come in both runtime and build-time flavors. These
  variants use cryptographic modules validated under FIPS 140, a U.S. government standard for secure cryptographic
  operations. The `harbor-core` FIPS variants build against the FIPS-validated Go toolchain and run the Core binary with
  `GODEBUG=fips140=on`. This is the lenient mode: FIPS-validated primitives are used wherever possible, but non-FIPS
  primitives used by transitive dependencies (for example SHA-1 in redis/go-redis) are still permitted. Strict mode
  (`fips140=only`) is not used today because those dependencies would otherwise cause Harbor to refuse to start.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                                                                                                                                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                                 |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. `harbor-core` binds to port 8080 for HTTP APIs.                                                                                                                                                                                                                                  |
| Entry point        | The upstream `goharbor/harbor-core` image is launched via `/harbor/entrypoint.sh`, which runs certificate setup and then starts Core. The DHI entrypoint is `/usr/local/bin/harbor-core`. Set `core.command` in your Helm values to match, and move any certificate setup you depended on into chart values, mounts, or an init container. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                |
| Environment config | Harbor Core is configured with environment variables in this image. It does not include `/etc/core/app.conf` unless you mount one and set `CONFIG_PATH`. Provide PostgreSQL, Redis, and secret values at launch or the container will crash on startup.                                                                                    |

The following steps outline the general migration process.

1. **Find hardened images for your Harbor deployment.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The harbor-core service is the central API server component of Harbor deployments, handling backend operations and
   email templates.

1. **Update your Harbor Helm chart configurations.**

   Update the image references in your Helm values to use the hardened image and explicitly set the command, because the
   upstream image's entrypoint is a shell script that does not exist in the hardened image:

   ```yaml
   core:
     image:
       repository: dhi.io/harbor-core
       tag: <tag>
     command:
       - /usr/local/bin/harbor-core
   ```

1. **For custom Harbor deployments, update the base image in your manifests.**

   If you build your own Core manifests, point the container image at `dhi.io/harbor-core:<tag>` and set
   `command: ["/usr/local/bin/harbor-core"]` in the pod spec.

1. **Validate connectivity and secrets.**

   Confirm the Pod has the full set of Harbor environment variables (`CORE_SECRET`, `JOBSERVICE_SECRET`, PostgreSQL
   credentials, Redis URLs, `HARBOR_ADMIN_PASSWORD`, etc.) before rolling traffic over.

1. **Test Harbor functionality.**

   After migration, verify that Harbor API endpoints, user authentication, and other core backend functions continue to
   work correctly with the hardened image. Test the `/api/v2.0/health` endpoint and sign in to the portal to confirm
   end-to-end functionality. Note that the web UI is provided by the harbor-portal component, not harbor-core.

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

`harbor-core` requires database and cache connectivity and a readable `/harbor/migrations` tree (bundled in the image).
If you use `CONFIG_PATH`, the file must exist at that path (for example via a volume mount). Otherwise rely on
environment variables as in the compose example.

### Cannot sign in to the Harbor UI

If the login page returns `invalid user name or password` with the default admin credentials, check for one of the
following.

- The Helm chart is still pointing at the upstream entrypoint. Confirm `core.command` is set to
  `[/usr/local/bin/harbor-core]` in your values.
- The external URL does not match the browser address. Harbor rejects requests whose `Host` header does not match
  `externalURL`. For a NodePort deployment, set `externalURL: http://<node-ip>:<node-port>` and reach the UI at the
  exact same address.
- TLS is enabled with a certificate the browser cannot validate. The CSRF cookie is marked `Secure`, so the UI stays on
  the login page even after a successful POST. Disable TLS for local testing or terminate TLS at an ingress with a
  trusted certificate.
- `harborAdminPassword` was not overridden and you are trying the upstream default `Harbor12345`. Set the value
  explicitly when installing the chart.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Harbor core
typically uses port 8080 which is not privileged.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
