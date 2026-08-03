## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs `qdrant`, a vector database and similarity-search engine. The server exposes a REST API on port 6333 and
a gRPC API on port 6334, and serves a built-in web dashboard at `/dashboard`.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

## Image layout

- `/usr/bin/qdrant` — the Qdrant server binary (installed from the `dhi/pkg-qdrant` package; the image entry point)
- `/qdrant/config` — the bundled configuration directory (`config.yaml` plus the `production.yaml` overlay)
- `/qdrant/storage` — the default storage directory (collections, WAL, raft state)
- `/qdrant/snapshots` — the default snapshots directory
- `/qdrant/static` — the web-UI dashboard assets

For full feature documentation, see the [Qdrant documentation](https://qdrant.tech/documentation/).

## Run the container

Check the version:

```
$ docker run --rm dhi.io/qdrant:<tag> --version
```

Start a server and expose the REST (6333) and gRPC (6334) APIs:

```
$ docker run --rm -p 6333:6333 -p 6334:6334 \
    -v qdrant_storage:/qdrant/storage \
    dhi.io/qdrant:<tag>
```

Confirm the server is healthy:

```
$ curl http://localhost:6333/healthz
healthz check passed
```

Create a collection:

```
$ curl -X PUT http://localhost:6333/collections/demo \
    -H "Content-Type: application/json" \
    --data '{"vectors":{"size":4,"distance":"Dot"}}'
```

Add a point, then search for it by vector:

```
$ curl -X PUT "http://localhost:6333/collections/demo/points?wait=true" \
    -H "Content-Type: application/json" \
    --data '{"points":[{"id":1,"vector":[0.05,0.61,0.76,0.74],"payload":{"city":"Berlin"}}]}'

$ curl -X POST http://localhost:6333/collections/demo/points/query \
    -H "Content-Type: application/json" \
    --data '{"query":[0.05,0.61,0.76,0.74],"limit":1,"with_payload":true}'
```

Open the web dashboard in a browser at `http://localhost:6333/dashboard`.

## Configuration

Qdrant reads `config/config.yaml` and then the overlay named by `RUN_MODE` (`config/production.yaml` by default), both
relative to the container's working directory (`/qdrant`). Any setting can also be overridden with an environment
variable using the `QDRANT__SECTION__KEY` convention (double underscores). Common settings:

| Variable                        | Description                                                                            |
| :------------------------------ | :------------------------------------------------------------------------------------- |
| `RUN_MODE`                      | Selects the config overlay under `/qdrant/config`. Defaults to `production`.           |
| `QDRANT__SERVICE__API_KEY`      | API key required on requests. Unset by default (open access) — set it for production.  |
| `QDRANT__SERVICE__HTTP_PORT`    | REST API port. Defaults to `6333`.                                                     |
| `QDRANT__SERVICE__GRPC_PORT`    | gRPC API port. Defaults to `6334`.                                                     |
| `QDRANT__STORAGE__STORAGE_PATH` | Path to the storage directory. Defaults to `./storage`, resolved to `/qdrant/storage`. |

See the [Qdrant configuration reference](https://qdrant.tech/documentation/guides/configuration/) for the full list.

## Persisting data

Qdrant stores all collection data under `/qdrant/storage` and snapshots under `/qdrant/snapshots`. Mount named volumes
or host directories there to persist data across container restarts:

```
$ docker run --rm -p 6333:6333 -p 6334:6334 \
    -v qdrant_storage:/qdrant/storage \
    -v qdrant_snapshots:/qdrant/snapshots \
    dhi.io/qdrant:<tag>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                                       |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                          |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that `/qdrant/storage` and `/qdrant/snapshots` are accessible to that user (UID 65532).                                                                                                                                                              |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                   |
| Entry point        | The image uses `/usr/bin/qdrant` as the entry point and `/qdrant` as the working directory. Pass any Qdrant flags as `docker run` arguments after the image reference.                                                                                                                                                               |
| Init process       | Upstream wraps the entry point in a shell script (`entrypoint.sh`) that forwards signals and offers an opt-in OOM recovery mode. The hardened runtime runs `qdrant` directly as PID 1; it handles `SIGTERM` for graceful shutdown on its own. The opt-in recovery mode requires a shell and is not available in the runtime variant. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                          |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

The `/qdrant/storage` and `/qdrant/snapshots` directories in this image are owned by the nonroot user (UID 65532). If
you mount host directories there, make sure they are writable by that UID.

To view the user for an image variant, select the **Tags** tab for this repository.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

The image uses `/usr/bin/qdrant` as the entry point, with `/qdrant` as the working directory. Pass any Qdrant
command-line flags as `docker run` arguments after the image reference. Configuration is read from `/qdrant/config`,
keyed by the `RUN_MODE` environment variable (`production` by default).

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
