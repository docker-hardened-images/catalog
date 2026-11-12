## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Prerequisites

NetBox requires three external services at runtime:

- **PostgreSQL** (≥ 14) — canonical state.
- **Redis** with append-only persistence (`--appendonly yes`) — the RQ queue used by the worker and webhook delivery.
- **Redis** without persistence — the cache used to memoize query results.

The image does **not** bundle these. Use the compose example below, or supply your own.

## Start a NetBox instance

The minimum-viable single-host run (with throwaway data stores) looks like:

```bash
$ docker network create netbox
$ docker run -d --name netbox-postgres --network netbox \
    -e POSTGRES_USER=netbox -e POSTGRES_PASSWORD=netbox -e POSTGRES_DB=netbox \
    docker.io/postgres:18
$ docker run -d --name netbox-redis --network netbox \
    docker.io/redis:7 redis-server --appendonly yes
$ docker run -d --name netbox-redis-cache --network netbox \
    docker.io/redis:7
$ docker run -d --name netbox --network netbox -p 8080:8080 \
    -e DB_HOST=netbox-postgres -e DB_NAME=netbox -e DB_USER=netbox -e DB_PASSWORD=netbox \
    -e REDIS_HOST=netbox-redis -e REDIS_CACHE_HOST=netbox-redis-cache \
    -e SECRET_KEY="$(openssl rand -hex 32)" \
    -e ALLOWED_HOSTS="*" \
    dhi.io/netbox:<tag>
```

The first start performs database migrations and initial setup. NetBox will become reachable at `http://localhost:8080/`
once the entrypoint logs `✅ Initialisation is done.` followed by Granian's startup banner.

For production, use the compose example below.

## Compose example (web + worker)

NetBox uses the **same image** for the web service and the RQ worker; the role is selected via the `command` override.
The worker depends on the web service to first apply database migrations.

```yaml
services:
  postgres:
    image: docker.io/postgres:18
    environment:
      POSTGRES_USER: netbox
      POSTGRES_PASSWORD: netbox
      POSTGRES_DB: netbox
    volumes:
      # postgres:18+ expects the volume at /var/lib/postgresql (not .../data)
      - netbox-postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "netbox", "-d", "netbox"]
      interval: 5s
      retries: 10
      start_period: 10s

  redis:
    image: docker.io/redis:7
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - netbox-redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 10
      start_period: 10s

  redis-cache:
    image: docker.io/redis:7
    command: ["redis-server"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 10
      start_period: 10s

  netbox-web:
    image: dhi.io/netbox:<tag>
    ports:
      - "8080:8080"
    environment: &netbox-env
      DB_HOST: postgres
      DB_NAME: netbox
      DB_USER: netbox
      DB_PASSWORD: netbox
      REDIS_HOST: redis
      REDIS_CACHE_HOST: redis-cache
      SECRET_KEY: "replace-me-with-50-plus-random-characters-from-openssl-rand-hex"
      ALLOWED_HOSTS: "*"
      SUPERUSER_NAME: admin
      SUPERUSER_EMAIL: admin@example.com
      SUPERUSER_PASSWORD: admin
    volumes:
      - netbox-media:/opt/netbox/netbox/media
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
      redis-cache: { condition: service_healthy }

  netbox-worker:
    image: dhi.io/netbox:<tag>
    command:
      - /opt/netbox/venv/bin/python
      - /opt/netbox/netbox/manage.py
      - rqworker
    environment: *netbox-env
    volumes:
      - netbox-media:/opt/netbox/netbox/media
    # First boot: web may still be migrating when the worker starts; retry until ready.
    restart: on-failure
    depends_on:
      netbox-web: { condition: service_started }

volumes:
  netbox-postgres-data:
  netbox-redis-data:
  netbox-media:
```

### Environment variables

| Variable                                                             | Description                                                                               | Required               |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------- |
| `DB_HOST`                                                            | PostgreSQL hostname.                                                                      | yes                    |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD`                                | PostgreSQL credentials.                                                                   | yes                    |
| `REDIS_HOST` / `REDIS_PASSWORD` / `REDIS_DATABASE`                   | Primary Redis (RQ queue).                                                                 | `REDIS_HOST` yes       |
| `REDIS_CACHE_HOST` / `REDIS_CACHE_PASSWORD` / `REDIS_CACHE_DATABASE` | Cache Redis (memoization).                                                                | `REDIS_CACHE_HOST` yes |
| `SECRET_KEY`                                                         | Django secret. **Must be ≥ 50 characters.** Generate with `openssl rand -hex 32`.         | yes                    |
| `ALLOWED_HOSTS`                                                      | Space-separated host names Django will accept. `"*"` permits any (dev only).              | yes                    |
| `SUPERUSER_NAME` / `SUPERUSER_EMAIL` / `SUPERUSER_PASSWORD`          | One-time superuser bootstrap. Skipped if `SKIP_SUPERUSER=true`.                           | no                     |
| `SUPERUSER_API_TOKEN`                                                | API token to assign to the bootstrap superuser. Useful for CI seeding.                    | no                     |
| `GRANIAN_WORKERS`                                                    | Granian worker count (default: `4`).                                                      | no                     |
| `GRANIAN_BACKPRESSURE`                                               | Backpressure threshold (default: matches `GRANIAN_WORKERS`).                              | no                     |
| `AUTH_LDAP_SERVER_URI`                                               | Activates the optional LDAP authentication backend. See upstream NetBox docs for details. | no                     |

### Tuning `GRANIAN_WORKERS`

The default of 4 workers fits most small deployments. Rule of thumb: `2 * CPU_cores + 1`. For an 8-core host, set
`GRANIAN_WORKERS=17`. Each worker is an independent Python process and holds its own database connection pool — high
worker counts also need a larger PostgreSQL `max_connections`.

Note on `GRANIAN_EXTRA_ARGS`: the upstream launcher expands it as a bash array (`"${GRANIAN_EXTRA_ARGS[@]}"`), which is
only populated when the variable was declared as an array in the launching shell. A plain
`docker run -e GRANIAN_EXTRA_ARGS="--foo --bar"` passes a single string and the expansion produces zero arguments. If
you need extra granian flags, mount your own launcher or use the individual `GRANIAN_*` variables above.

### Health checks

NetBox exposes a `/login/` endpoint that returns 200 once Django is ready to serve. Since Docker Hardened Images don't
include `curl` in the runtime variant, use HTTP probes from the orchestrator rather than `HEALTHCHECK`:

```yaml
livenessProbe:
  httpGet: { path: /login/, port: 8080 }
  initialDelaySeconds: 60
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /login/, port: 8080 }
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Install plugins / custom Python dependencies

Use the `-dev` variant as a builder stage to install plugins into the venv, then copy the venv into the runtime image.
The venv ships without its own pip, so target it with the system pip via `--python`:

```dockerfile
FROM dhi.io/netbox:<tag>-dev AS builder
RUN pip --python /opt/netbox/venv/bin/python install --no-cache-dir \
      netbox-bgp \
      netbox-secrets

FROM dhi.io/netbox:<tag>
COPY --from=builder /opt/netbox/venv /opt/netbox/venv
```

After building, enable each plugin by mounting a config file that sets the `PLUGINS` list at
`/etc/netbox/config/plugins.py`. Every `*.py` under `/etc/netbox/config/` is loaded at startup, matching upstream
netbox-docker behavior.

For FIPS-aware plugins, do the same with the `-fips-dev` and `-fips` tags.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag suffix.

- **Runtime** (`:4`, `:4.6`, `:4.6.4`) — production. Runs as nonroot user uid 65532. No shell tooling, no package
  manager. Used as the final image in a multi-stage Dockerfile or directly via `docker run`.
- **Dev** (`:4-dev`, `:4.6-dev`, `:4.6.4-dev`) — build-time. Runs as root and ships `apt` + `bash` + `coreutils` +
  `findutils`. Use as a builder stage for plugin installs.
- **FIPS** (`:4-fips`, etc.) — runtime variant linked against the FIPS OpenSSL provider. Carries `fips-compliant: true`
  \+ `stig-certified: true` attestations. See the SAML caveat in the overview.
- **FIPS-dev** (`:4-fips-dev`, etc.) — FIPS runtime plus the dev overlay.

To view all available variants, select the Tags tab for this repository.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                 |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace `netboxcommunity/netbox:<tag>` with `dhi.io/netbox:<tag>`.                                                                                                                                                                                                                             |
| Package management | Non-dev images don't include `apt`. Install Python plugins via the `-dev` variant in a builder stage and `COPY` the venv into the runtime image.                                                                                                                                               |
| Non-root user      | Upstream `netboxcommunity/netbox` runs as **root (uid 0)** by default (a `netbox` user at uid 999 exists for volume ownership). This image runs as **uid 65532** (DHI nonroot). If you bind-mount media or backup volumes, `chown -R 65532:65532` the directory before starting the container. |
| TLS certificates   | TLS certificates ship in `/etc/ssl/certs/ca-certificates.crt`. No additional install needed.                                                                                                                                                                                                   |
| Ports              | The image listens on 8080. Map to a host port with `-p`.                                                                                                                                                                                                                                       |
| Entry point        | Entrypoint is `["/usr/bin/tini", "--"]`, default cmd is `["/opt/netbox/docker-entrypoint.sh", "/opt/netbox/launch-netbox.sh"]`. Override `cmd` to switch to worker mode (see compose example).                                                                                                 |
| Shell              | Runtime images ship `bash` (required by the entrypoint). They do not ship `sh`/`dash` as a separate binary, but `/bin/sh` is symlinked to bash for POSIX compatibility.                                                                                                                        |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened runtime images contain no debugging tools beyond `bash`. Use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach a shell with diagnostic utilities to a
running container:

```bash
$ docker debug netbox
```

### Permissions on media volume

NetBox stores user-uploaded files (image attachments, custom scripts, reports) under `/opt/netbox/netbox/media`. If you
migrate the volume from upstream `netboxcommunity/netbox` (often owned by uid 999 on the volume, even though the process
runs as root) to this image (uid 65532), chown the host directory before starting:

```bash
$ sudo chown -R 65532:65532 /path/to/netbox-media
```

### Privileged ports

The runtime image runs as nonroot uid 65532 and cannot bind to ports below 1024. Granian listens on 8080 by default; use
the host-side `-p 80:8080` mapping if you need NetBox on port 80.

### No shell beyond bash

The runtime image has no `sh` interpreter beyond `bash`. Most scripts work; if you have legacy POSIX-only scripts that
fail under bash strict mode, run them with `bash --posix`.

### Entry point

The DHI NetBox image runs `tini -- docker-entrypoint.sh launch-netbox.sh`, mirroring the upstream startup sequence:
`docker-entrypoint.sh` waits for the database, runs migrations, optionally creates a superuser, then `exec`s its
arguments. `launch-netbox.sh` starts Granian. To switch roles, override `cmd`:

```bash
# Worker
$ docker run ... dhi.io/netbox:<tag> /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py rqworker
```
