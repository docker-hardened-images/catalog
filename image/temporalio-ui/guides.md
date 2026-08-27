## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Temporal UI Hardened image

Temporal UI is the official web dashboard for a Temporal cluster. It provides a browser-based view of workflows,
activities, namespaces, schedules, and worker fleets, and connects to a Temporal Frontend service over gRPC. The UI is a
standalone Go binary (using the Echo web framework) that serves both the dashboard HTML and a JSON API on the same port.

This Docker Hardened Temporal UI image includes:

- `ui-server` (the Go binary at `/home/ui-server/ui-server`)
- `start-ui-server.sh` (the entrypoint shell script at `/home/ui-server/start-ui-server.sh`)
- The bundled configuration tree at `/home/ui-server/config/` (with `base.yaml` and a templated `docker.yaml`)
- `bash` and `/bin/sh` (required by the entrypoint script, which uses bash-specific syntax)

The image declares port `8080/tcp` for the dashboard and API, runs as the `temporal` user, and exposes the entrypoint at
`/home/ui-server/start-ui-server.sh`.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Start a Temporal UI container

The UI requires a reachable Temporal Frontend service to query workflows. For a quick smoke test without a backend, you
can still start the UI in isolation — the dashboard HTML will load, but API queries return HTTP 503 until a server is
configured:

```bash
$ docker run -d --name temporal-ui -p 8080:8080 dhi.io/temporalio-ui:<tag>
$ curl -I http://localhost:8080/
HTTP/1.1 200 OK
```

For a real deployment, configure the UI to point at your Temporal server via the `TEMPORAL_ADDRESS` environment
variable:

```bash
$ docker run -d --name temporal-ui \
    -p 8080:8080 \
    -e TEMPORAL_ADDRESS=temporal-server.example.com:7233 \
    -e TEMPORAL_CORS_ORIGINS=http://localhost:8080 \
    dhi.io/temporalio-ui:<tag>
```

### Common Temporal UI use cases

#### Run a complete local Temporal stack with Docker Compose

For local development, the UI is typically used alongside the Temporal Server and a database backend. The full stack
consists of:

- A database backend (PostgreSQL in this example)
- A one-shot schema-bootstrap container that uses `temporalio-admin-tools` to create the `temporal` and
  `temporal_visibility` databases
- The Temporal Server (`temporalio-server`)
- The Temporal UI (`temporalio-ui`)

> **DHI-specific note on schema setup.** The Docker Hardened `temporalio-server` image does not bundle the autosetup
> tooling that the upstream `temporalio/auto-setup` image uses, because the schema-creation binaries are kept separate
> to reduce the server's attack surface. As a result, you must run `temporal-sql-tool` from the `temporalio-admin-tools`
> image to bootstrap the database before the server starts. The Compose pattern below uses a one-shot `schema-setup`
> service to handle this.

Create `dynamicconfig/development-sql.yaml`:

```yaml
limit.maxIDLength:
  - value: 255
    constraints: {}
system.forceSearchAttributesCacheRefreshOnRead:
  - value: true
    constraints: {}
```

Then create `docker-compose.yml`:

```yaml
services:
  postgresql:
    image: postgres:17
    container_name: temporal-postgresql
    environment:
      POSTGRES_PASSWORD: temporal
      POSTGRES_USER: temporal
    networks:
      - temporal-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U temporal"]
      interval: 5s
      timeout: 5s
      retries: 10

  schema-setup:
    image: dhi.io/temporalio-admin-tools:<admin-tools-tag>
    container_name: temporal-schema-setup
    depends_on:
      postgresql:
        condition: service_healthy
    environment:
      - SQL_PLUGIN=postgres12
      - SQL_HOST=postgresql
      - SQL_PORT=5432
      - SQL_USER=temporal
      - SQL_PASSWORD=temporal
    networks:
      - temporal-network
    entrypoint: ["bash", "-c"]
    command:
      - |
        set -e
        temporal-sql-tool --db temporal create-database
        temporal-sql-tool --db temporal setup-schema -v 0.0
        temporal-sql-tool --db temporal update-schema -d /etc/temporal/schema/postgresql/v12/temporal/versioned
        temporal-sql-tool --db temporal_visibility create-database
        temporal-sql-tool --db temporal_visibility setup-schema -v 0.0
        temporal-sql-tool --db temporal_visibility update-schema -d /etc/temporal/schema/postgresql/v12/visibility/versioned

  temporal:
    image: dhi.io/temporalio-server:<server-tag>
    container_name: temporal
    depends_on:
      schema-setup:
        condition: service_completed_successfully
    environment:
      - DB=postgres12
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=temporal
      - POSTGRES_SEEDS=postgresql
      - DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/development-sql.yaml
      - SKIP_SCHEMA_SETUP=true
    ports:
      - "7233:7233"
    volumes:
      - ./dynamicconfig:/etc/temporal/config/dynamicconfig
    networks:
      - temporal-network

  temporal-ui:
    image: dhi.io/temporalio-ui:<tag>
    container_name: temporal-ui
    depends_on:
      - temporal
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=http://localhost:8080
    ports:
      - "8080:8080"
    networks:
      - temporal-network

networks:
  temporal-network:
    driver: bridge
```

Start the stack:

```bash
$ docker compose up -d
```

Once the schema-setup container exits with code 0 and the server reaches its serving state, open
`http://localhost:8080/` in a browser. To verify the UI can reach the server from the command line:

```bash
$ curl http://localhost:8080/api/v1/namespaces
```

A successful response includes the `temporal-system` namespace that Temporal creates internally on first boot.

#### Deploy on Kubernetes

A typical Kubernetes deployment of Temporal UI runs as a single-replica `Deployment` fronted by a `Service`. The Service
can be exposed via `Ingress`, `LoadBalancer`, or `port-forward` depending on your environment.

The `imagePullSecrets` field references a pull secret you must create first for `dhi.io` — see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: temporal-ui
  template:
    metadata:
      labels:
        app: temporal-ui
    spec:
      imagePullSecrets:
        - name: helm-pull-secret
      containers:
        - name: temporal-ui
          image: dhi.io/temporalio-ui:<tag>
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: TEMPORAL_ADDRESS
              value: "temporal-frontend.temporal.svc.cluster.local:7233"
            - name: TEMPORAL_CORS_ORIGINS
              value: "http://localhost:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: temporal-ui
spec:
  selector:
    app: temporal-ui
  ports:
    - port: 8080
      targetPort: 8080
```

Set `TEMPORAL_ADDRESS` to the cluster DNS name of your Temporal Frontend service. Many production deployments install
Temporal Server itself via the [official Helm chart](https://github.com/temporalio/helm-charts), then run the UI as a
sibling Deployment that points at the chart's `temporal-frontend` Service.

### Configuration

The UI is configured primarily through environment variables read by the entrypoint script. The most common are:

- `TEMPORAL_ADDRESS` — host and gRPC port of the Temporal Frontend service (default: `localhost:7233`)
- `TEMPORAL_CORS_ORIGINS` — comma-separated list of origins allowed for browser API calls
- `TEMPORAL_UI_PORT` — port the UI listens on inside the container (default: `8080`)
- `TEMPORAL_AUTH_ENABLED`, `TEMPORAL_AUTH_PROVIDER_URL`, `TEMPORAL_AUTH_CLIENT_ID`, `TEMPORAL_AUTH_CLIENT_SECRET` — OIDC
  SSO configuration
- `TEMPORAL_CLOUD_UI` — set to `true` when pointing at Temporal Cloud (default: `false`)

For advanced configuration, mount a custom YAML config at `/home/ui-server/config/docker.yaml`. See the
[Temporal UI server documentation](https://github.com/temporalio/ui-server) for the full schema.

### Non-hardened images vs Docker Hardened Images

#### Key differences

| Feature         | Docker Official Temporal UI          | Docker Hardened Temporal UI                         |
| --------------- | ------------------------------------ | --------------------------------------------------- |
| Security        | Standard Alpine base                 | Minimal, hardened Debian 13 base                    |
| Shell access    | Full shell (`bash`, `sh`)            | `bash` and `sh` (required by the entrypoint script) |
| Package manager | `apk` present (Alpine)               | No package manager                                  |
| User            | Runs as `temporal` user              | Runs as `temporal` user (UID 5000)                  |
| Image size      | ~619 MB                              | ~130 MB                                             |
| Attack surface  | Larger due to Alpine `apk` toolchain | Reduced — no package manager                        |
| Debugging       | Traditional shell debugging          | Use Docker Debug or the bundled `bash` debug bypass |
| Compliance      | None                                 | CIS                                                 |
| Attestations    | None                                 | SBOM, provenance, VEX metadata                      |

These are not generic claims — they reflect direct inspection of the upstream `temporalio/ui:latest` image and
`dhi.io/temporalio-ui:<tag>`. Both run as a non-root user named `temporal`, and both ship a shell because the entrypoint
is a bash script. The notable differences are that the DHI variant removes the package manager (`apk` is present in the
upstream Alpine image), is built on Debian 13 with CIS hardening, and is approximately 79% smaller.

#### Why is bash present?

The image's ENTRYPOINT is `/home/ui-server/start-ui-server.sh`, a bash script that handles legacy config-template
migration, parses arguments, and finally `exec`s the `ui-server` binary. Removing bash would break the entrypoint, so
the runtime image ships bash and `/bin/sh`. No other shell utilities (such as `coreutils`, `grep`, or `find`) are
included.

The entrypoint also implements a convenience: if you pass `bash` as the CMD, it drops into an interactive bash shell
instead of starting the UI server. This is helpful for one-off inspection:

```bash
$ docker run --rm -it dhi.io/temporalio-ui:<tag> bash
```

For deeper debugging, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/).

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the `temporal` user (UID 5000)
- Do not include a package manager
- Contain only the `ui-server` binary, the entrypoint script, bundled config, and the minimal libraries needed to run it

No build-time (`dev`) variants are currently published for this image. Because the runtime image already contains a
shell, most customization workflows that would normally require a dev variant (such as mounting a custom config) can be
done directly against the runtime image.

The Temporal UI image is published as a runtime variant on Debian 13 and Debian 12 base images. The runtime image runs
as the `temporal` user (UID 5000), does not include a package manager, and is CIS compliant.

A FIPS variant is also available. FIPS variants are FIPS 140-3 compliant and STIG (Security Technical Implementation
Guide) hardened, and require an active Docker Hardened Images subscription.

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

### Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or runtime configuration. At
minimum, you must update the base image to a Docker Hardened Image. This and a few other common changes are listed in
the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                       |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/temporalio-ui:<tag>`.                                                                                                                                                                                                                                           |
| Package management | The image doesn't contain a package manager. To install additional tooling, build your own image `FROM dhi.io/temporalio-ui:<tag>` and add binaries by copying them from another image in a multi-stage build.                                                                                       |
| Non-root user      | The image runs as the `temporal` user (UID 5000), not the typical DHI UID 65532. Ensure any mounted config files at `/home/ui-server/config/docker.yaml` are readable by UID 5000.                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. The image also sets `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`. There is no need to install TLS certificates for connecting to a Temporal server over TLS.                                                              |
| Ports              | The image declares port 8080. The default is above 1024 and unaffected by the privileged-port restriction for nonroot containers.                                                                                                                                                                    |
| Entry point        | The entrypoint is `/home/ui-server/start-ui-server.sh`, which calls the `ui-server` binary with `--env docker start`. To pass additional flags or environment variables, set them via `-e` flags on the docker run command. To drop into a shell instead of starting the UI, pass `bash` as the CMD. |
| Schema setup       | When deploying alongside the Docker Hardened `temporalio-server` image, the server expects an already-initialized schema. Use the `temporalio-admin-tools` image as a one-shot schema-bootstrap container before the server starts, as shown in the Compose example above.                           |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in `imagePullSecrets`.                                                                                                                                                                                                |

### Troubleshoot migration

The following are common issues that you may encounter during migration.

#### General debugging

The image ships bash and `/bin/sh` (required by the entrypoint), but no general-purpose debugging tools. For deeper
troubleshooting:

- Use the entrypoint's built-in debug bypass: `docker run --rm -it dhi.io/temporalio-ui:<tag> bash`
- Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) for richer debugging:
  `docker debug temporal-ui`

The container logs structured JSON to stdout for every HTTP request (method, URI, status, latency). View them with
`docker logs temporal-ui`.

#### UI loads but API calls return HTTP 503

This means the UI cannot reach the Temporal Frontend service. Check:

- `TEMPORAL_ADDRESS` resolves to the correct host and gRPC port (default port `7233`)
- The Temporal Server container is in the same network as the UI
- The Temporal Server has completed its initialization (look for "Started" in its logs)

#### Server fails with `relation "schema_version" does not exist`

The Temporal Server image does not bootstrap its own schema. Run the schema-setup pattern shown in the Compose example
above using `temporalio-admin-tools` and `temporal-sql-tool` before starting the server.

#### Permissions

The image runs as UID 5000 (`temporal`). Any mounted config files or volumes must be readable by this UID. With named
Docker volumes this works automatically.

#### Privileged ports

The image runs as a nonroot user, so the UI cannot bind to ports below 1024. The default port 8080 is unaffected.

#### Entry point

The image's ENTRYPOINT is `/home/ui-server/start-ui-server.sh`. Use `docker inspect` to view the entrypoint and any
default CMD for a specific tag.
