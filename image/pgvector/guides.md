## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This Docker Hardened pgvector image bundles a complete PostgreSQL server with the pgvector extension preinstalled. Tags
follow the format `<pgvector-version>-pg<postgres-major>`, for example `0.8.2-pg18` or the rolling `pg18` tag, which
always points to the latest pgvector release for that PostgreSQL major.

The pgvector extension is available to load into any database with `CREATE EXTENSION vector;`. Once loaded, the `vector`
data type, exact and approximate similarity operators, and HNSW and IVFFlat index access methods become available
alongside the standard PostgreSQL feature set.

## Start a pgvector instance

Run the following command to start a pgvector container. Replace `<tag>` with the variant you want.

```bash
docker run --name some-pgvector \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -d dhi.io/pgvector:<tag>
```

After the container is running, load the extension and create a table that uses it:

```bash
docker exec -it some-pgvector psql -U postgres -c "CREATE EXTENSION vector;"
docker exec -it some-pgvector psql -U postgres -c "CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));"
docker exec -it some-pgvector psql -U postgres -c "INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');"
```

### Environment variables

The image inherits the upstream PostgreSQL entrypoint, so the standard `POSTGRES_*` environment variables apply.

| Variable                    | Description                                                                                                         | Default                            | Required         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------- |
| `POSTGRES_PASSWORD`         | Superuser password used by `initdb` and required for any non-empty cluster.                                         | _(unset)_                          | Yes              |
| `POSTGRES_PASSWORD_FILE`    | Path to a file containing the superuser password. Mutually exclusive with `POSTGRES_PASSWORD`.                      | _(unset)_                          | One of these two |
| `POSTGRES_USER`             | Superuser name created at `initdb` time.                                                                            | `postgres`                         | No               |
| `POSTGRES_USER_FILE`        | Path to a file containing the superuser name.                                                                       | _(unset)_                          | No               |
| `POSTGRES_DB`               | Default database created at `initdb` time. The `postgres` database is always created in addition.                   | `postgres`                         | No               |
| `POSTGRES_INITDB_ARGS`      | Extra arguments forwarded to `initdb` (e.g. `--data-checksums`, `--encoding=UTF8`).                                 | _(unset)_                          | No               |
| `POSTGRES_INITDB_WALDIR`    | Alternate location for the write-ahead log directory passed to `initdb --waldir`.                                   | _(unset)_                          | No               |
| `POSTGRES_HOST_AUTH_METHOD` | Authentication method appended to `pg_hba.conf` for remote hosts. `trust` and `password` are rejected for security. | _(unset)_                          | No               |
| `PGDATA`                    | Versioned data directory. Override with care.                                                                       | `/var/lib/postgresql/<MAJOR>/data` | No               |

## Common pgvector use cases

### Nearest neighbor search

```bash
docker exec -it some-pgvector psql -U postgres <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS items (id bigserial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'), ('[7,8,9]');
SELECT id, embedding FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 3;
SQL
```

The `<->` operator computes L2 distance. pgvector also supports `<#>` for negative inner product, `<=>` for cosine
distance, `<+>` for L1 distance, and additional operators for binary and sparse vectors.

### Building an HNSW index for fast approximate search

```sql
CREATE INDEX ON items USING hnsw (embedding vector_l2_ops);
```

HNSW indexes provide fast approximate nearest neighbor search at the cost of perfect recall. Tune `m` and
`ef_construction` for index build, and `hnsw.ef_search` per query, to trade off speed against recall.

### Persisting data with volumes

Use a named volume mounted at the parent directory `/var/lib/postgresql` so the versioned data subdirectory is managed
by the image:

```bash
docker volume create pgvector-data
docker run --name some-pgvector -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -v pgvector-data:/var/lib/postgresql \
  dhi.io/pgvector:<tag>
```

### Docker Compose example

```yaml
services:
  db:
    image: dhi.io/pgvector:pg18
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - pgvector-data:/var/lib/postgresql
    ports:
      - "5432:5432"

volumes:
  pgvector-data:
```

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
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the postgres user. Ensure that necessary files and directories are accessible to the postgres user.                                                                                                                                                                 |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |
| Tag scheme         | pgvector tags are qualified by the PostgreSQL major (`<pgvector-version>-pg<N>` and `pg<N>`). Pick the tag that matches the PostgreSQL major you are migrating from.                                                                                                                                                         |
| PGDATA path        | DHI pgvector uses versioned `PGDATA` paths (`/var/lib/postgresql/<MAJOR_VERSION>/data`). The recommended approach is to mount volumes to `/var/lib/postgresql` rather than directly to `PGDATA`.                                                                                                                             |

## Troubleshooting migration

If `CREATE EXTENSION vector;` fails with `extension "vector" is not available`, the database is most likely connected to
a stock postgres image rather than this pgvector image. Verify the running image and the tag include `pgvector`:

```bash
docker inspect <container> --format '{{ .Config.Image }}'
```

If you previously installed pgvector at a different version inside an existing database, run
`ALTER EXTENSION vector UPDATE;` after switching to the new image to migrate the extension's catalog state.
