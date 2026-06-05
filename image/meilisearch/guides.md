## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs `meilisearch`, a lightning-fast search engine that exposes a RESTful HTTP API on port 7700. The image
also includes `meilitool`, a utility for offline maintenance of the Meilisearch data directory (snapshots, dump exports,
key recovery).

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

## What's included

- `/bin/meilisearch` — the search engine binary
- `/bin/meilitool` — offline maintenance utility for the data directory
- `/meili_data` — the default data directory (working directory of the container)
- A `/meilisearch` compatibility symlink that mirrors upstream's pre-v0.27 install location

For full feature documentation, see the [Meilisearch documentation](https://www.meilisearch.com/docs).

## Run the container

Check the version:

```
$ docker run --rm dhi.io/meilisearch:<tag> --version
```

Start a server in development mode and expose the API on port 7700:

```
$ docker run --rm -p 7700:7700 \
    -e MEILI_MASTER_KEY=your-master-key-here \
    -v meili_data:/meili_data \
    dhi.io/meilisearch:<tag>
```

Confirm the server is healthy:

```
$ curl http://localhost:7700/health
{"status":"available"}
```

Create an index and add documents:

```
$ curl -X POST -H "Authorization: Bearer your-master-key-here" \
    -H "Content-Type: application/json" \
    --data '[{"id":1,"title":"Carol"}]' \
    http://localhost:7700/indexes/movies/documents
```

Search the index:

```
$ curl -X POST -H "Authorization: Bearer your-master-key-here" \
    -H "Content-Type: application/json" \
    --data '{"q":"carol"}' \
    http://localhost:7700/indexes/movies/search
```

## Configuration

Meilisearch is configured entirely through environment variables and command-line flags. The most common settings:

| Variable             | Description                                                                                                                 |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| `MEILI_MASTER_KEY`   | API authentication key. Required for production deployments.                                                                |
| `MEILI_HTTP_ADDR`    | Address Meilisearch listens on. Defaults to `0.0.0.0:7700`.                                                                 |
| `MEILI_ENV`          | `development` (default) or `production`. Production requires `MEILI_MASTER_KEY`.                                            |
| `MEILI_DB_PATH`      | Path to the data directory. Defaults to `./data.ms`, resolved to `/meili_data/data.ms` with this image's working directory. |
| `MEILI_NO_ANALYTICS` | Set to `true` to disable anonymous usage analytics.                                                                         |

See the [Meilisearch configuration reference](https://www.meilisearch.com/docs/learn/configuration/instance_options) for
the complete list.

## Persisting data

Meilisearch stores all data under `/meili_data` (the container's working directory). Mount a named volume or host
directory there to persist indexes across container restarts:

```
$ docker run --rm -p 7700:7700 \
    -e MEILI_MASTER_KEY=your-master-key-here \
    -v meili_data:/meili_data \
    dhi.io/meilisearch:<tag>
```

## Offline maintenance with meilitool

Use `meilitool` for data directory maintenance operations such as exporting dumps or recovering corrupted indexes. Stop
the running Meilisearch container first, then run `meilitool` against the same data volume:

```
$ docker run --rm -v meili_data:/meili_data \
    --entrypoint /bin/meilitool dhi.io/meilisearch:<tag> --help
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

| Item               | Migration note                                                                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                 |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                           |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Entry point        | The image uses `/bin/meilisearch` as the entry point. A `/meilisearch` symlink is provided for compatibility with pre-v0.27 deployments that referenced that path.          |
| Init process       | Upstream wraps the entry point with `tini`. The hardened image runs `meilisearch` directly as PID 1; it handles signals correctly and does not require an init wrapper.     |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |

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

The `/meili_data` directory in this image is owned by the nonroot user (UID 65532). If you mount a host directory there,
make sure it is writable by that UID.

To view the user for an image variant, select the **Tags** tab for this repository.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

The image uses `/bin/meilisearch` as the entry point. Pass any Meilisearch command-line flags as `docker run` arguments
after the image reference. The data directory defaults to `/meili_data`, which is also the container's working
directory.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
