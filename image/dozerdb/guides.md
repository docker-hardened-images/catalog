## How to use this image

All examples use the public image. If you mirror the repository, replace `dhi.io/dozerdb:<tag>` with your mirrored image.
Authenticate before pulling with `docker login dhi.io`.

### Start DozerDB

Replace `<tag>` and `<password>` with the image tag and a password of at least eight characters:

```bash
docker run -d --name dozerdb \
  -e NEO4J_AUTH=neo4j/<password> \
  -p 7473:7473 \
  -p 7474:7474 \
  -p 7687:7687 \
  -v dozerdb-data:/data \
  -v dozerdb-logs:/logs \
  dhi.io/dozerdb:<tag>
```

Open `http://localhost:7474` for the browser UI or connect a Bolt client to `bolt://localhost:7687`.

To disable authentication for local-only testing, set `NEO4J_AUTH=none`. Do not disable authentication on an exposed or
production instance.

### Configure DozerDB

The image retains the Neo4j Docker environment-variable convention. Prefix a setting with `NEO4J_`, replace dots with
single underscores, and replace literal underscores with double underscores. For example:

```bash
docker run --rm \
  -e NEO4J_AUTH=none \
  -e NEO4J_server_memory_heap_initial__size=512m \
  -e NEO4J_server_memory_heap_max__size=512m \
  -p 7474:7474 \
  -p 7687:7687 \
  dhi.io/dozerdb:<tag>
```

The entrypoint also supports readable mounts at `/conf`, `/ssl`, `/plugins`, `/import`, and `/licenses`. The runtime
variant runs as UID/GID `7474:7474`; mounted writable directories must therefore be writable by UID 7474. `/data` and
`/logs` are the persistent writable data paths.

### Install registered Neo4j plugins

The pinned DozerDB plugin registry supports `apoc`, `apoc-extended`, `graph-data-science` (mapped to open GDS), `open-gds`, `n10s`, and `genai`.
Request plugins with a JSON array:

```bash
docker run --rm \
  -e NEO4J_AUTH=none \
  -e 'NEO4J_PLUGINS=["apoc"]' \
  -p 7474:7474 \
  -p 7687:7687 \
  dhi.io/dozerdb:<tag>
```

Plugin downloads happen at container startup and require outbound HTTPS access. A mounted `/plugins` directory is
optional; if supplied, ensure UID 7474 can write to it before starting the runtime image.

### Use the development variant

Tags ending in `-dev` run as root and include a shell, package manager, and common debugging tools. Use a dev variant for
interactive diagnosis, not as the default production runtime:

```bash
docker run --rm -it --entrypoint bash dhi.io/dozerdb:<tag>-dev
```

## Non-hardened images vs Docker Hardened Images

| Feature | `graphstack/dozerdb` | Docker Hardened DozerDB |
| --- | --- | --- |
| Base | General-purpose distribution | Minimal Debian 13 hardened base |
| Runtime user | Starts as root and drops privileges | Starts directly as non-root UID 7474 |
| Java | Upstream bundled/runtime Java | DHI Eclipse Temurin Java 21 runtime |
| Package manager | Available in the standard image | Available only in `-dev` variants |
| Entrypoint | Neo4j-compatible entrypoint | Same behavior, with `gosu` replacing `su-exec` |
| Ports | 7473, 7474, and 7687 | 7473, 7474, and 7687 |
| Persistent paths | `/data` and `/logs` | `/data` and `/logs` |

## Migrate from `graphstack/dozerdb`

1. Replace `graphstack/dozerdb:5.26.27` with `dhi.io/dozerdb:<tag>`.
2. Keep the existing `NEO4J_*` configuration and port mappings.
3. Ensure data, log, plugin, and import mounts are accessible to UID/GID `7474:7474`.
4. Test authentication, plugin compatibility, and database upgrades against a copy of production data before switching.
5. Use a `-dev` tag only when shell or package-manager access is required.

This image consumes the checksum-pinned DozerDB 5.26.27.0 full distribution because no exact source tag maps to that
release. See the catalog overview for the complete provenance boundary.

## Troubleshooting

### Permission errors

The runtime image cannot change ownership of host paths because it starts as UID 7474. Pre-create bind-mounted
directories with the correct ownership, or use named volumes. For a bind mount on Linux:

```bash
sudo install -d -o 7474 -g 7474 /srv/dozerdb/data /srv/dozerdb/logs
```

### Container exits during startup

Inspect logs with `docker logs dozerdb`. Common causes are an invalid `NEO4J_AUTH` value, a password shorter than eight
characters, a read-only mount, or a requested plugin that is unavailable for Neo4j 5.26.27.

### Debugging the runtime image

Use Docker Debug instead of adding tools to the production image:

```bash
docker debug dozerdb
```

Alternatively, reproduce the issue with the matching `-dev` tag. Do not use the dev variant as the long-running
production image.
