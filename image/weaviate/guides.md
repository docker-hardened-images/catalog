## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs `weaviate`, an AI-native vector database. The server exposes a REST and GraphQL API on port 8080 and a
gRPC API on port 50051.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

## Image layout

- `/usr/bin/weaviate` — the Weaviate server binary (installed from the `dhi/pkg-weaviate` package)
- `/bin/weaviate` — a symlink to `/usr/bin/weaviate` and the image entry point, matching the upstream image path
- `/var/lib/weaviate` — the default data directory (set through `PERSISTENCE_DATA_PATH`), owned by the nonroot user

For full feature documentation, see the [Weaviate documentation](https://docs.weaviate.io/weaviate).

## Run the container

Start a server and expose the REST (8080) and gRPC (50051) APIs:

```
$ docker run --rm -p 8080:8080 -p 50051:50051 \
    -v weaviate_data:/var/lib/weaviate \
    dhi.io/weaviate:<tag>
```

Confirm the server is ready:

```
$ curl -i http://localhost:8080/v1/.well-known/ready
HTTP/1.1 200 OK
```

Check the server version:

```
$ curl http://localhost:8080/v1/meta
```

Create a collection that accepts vectors you provide yourself:

```
$ curl -X POST http://localhost:8080/v1/schema \
    -H "Content-Type: application/json" \
    --data '{"class":"Demo","vectorizer":"none","properties":[{"name":"city","dataType":["text"]}]}'
```

Add an object with its vector, then search for it by vector:

```
$ curl -X POST http://localhost:8080/v1/objects \
    -H "Content-Type: application/json" \
    --data '{"class":"Demo","properties":{"city":"Berlin"},"vector":[0.05,0.61,0.76,0.74]}'

$ curl -X POST http://localhost:8080/v1/graphql \
    -H "Content-Type: application/json" \
    --data '{"query":"{ Get { Demo(nearVector: {vector: [0.05,0.61,0.76,0.74]}, limit: 1) { city } } }"}'
```

## Configuration

Weaviate is configured with environment variables. The image sets `PERSISTENCE_DATA_PATH=/var/lib/weaviate` and starts
the server with `--host 0.0.0.0 --port 8080 --scheme http`. Common settings:

| Variable                             | Description                                                                                             |
| :----------------------------------- | :------------------------------------------------------------------------------------------------------ |
| `PERSISTENCE_DATA_PATH`              | Path to the data directory. Defaults to `/var/lib/weaviate` in this image.                              |
| `AUTHENTICATION_APIKEY_ENABLED`      | Set to `true` to require API keys on requests.                                                          |
| `AUTHENTICATION_APIKEY_ALLOWED_KEYS` | Comma-separated list of accepted API keys.                                                              |
| `AUTHENTICATION_APIKEY_USERS`        | Comma-separated list of users, one per API key.                                                         |
| `AUTHORIZATION_ADMINLIST_ENABLED`    | Set to `true` to restrict write access to the users in `AUTHORIZATION_ADMINLIST_USERS`.                 |
| `ENABLE_MODULES`                     | Comma-separated list of modules to enable, for example `text2vec-openai,generative-openai`.             |
| `CLUSTER_HOSTNAME`                   | Node name in the cluster. Set it to a stable value so the node keeps its identity across restarts.      |
| `PROMETHEUS_MONITORING_ENABLED`      | Set to `true` to serve Prometheus metrics on port 2112.                                                 |
| `BACKUP_FILESYSTEM_PATH`             | Directory for the `backup-filesystem` module. It must be writable by the nonroot user (UID 65532).      |

If no authentication method is configured, Weaviate allows anonymous access. Enable API-key or OIDC authentication for
any deployment reachable by others.

See the [Weaviate environment variable reference](https://docs.weaviate.io/deploy/configuration/env-vars) for the full
list.

## Persisting data

Weaviate stores all data, including its Raft cluster state, under `/var/lib/weaviate`. Mount a named volume or host
directory there to persist data across container restarts:

```
$ docker run --rm -p 8080:8080 -p 50051:50051 \
    -e CLUSTER_HOSTNAME=node1 \
    -v weaviate_data:/var/lib/weaviate \
    dhi.io/weaviate:<tag>
```

## Running a cluster

In a multi-node deployment, nodes also communicate on the following ports, which are not published by default:

| Port | Purpose                     |
| :--- | :-------------------------- |
| 7946 | Gossip (memberlist)         |
| 7947 | Data transfer between nodes |
| 8300 | Raft consensus              |
| 8301 | Raft internal RPC           |

Use the [Weaviate Helm chart](https://github.com/weaviate/weaviate-helm) for Kubernetes deployments. It runs
`/bin/weaviate`, which this image provides.

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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                         |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                              |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                            |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. The upstream image runs as root. Ensure that the data directory and any backup directory are writable by that user (UID 65532).                               |
| Data directory     | The upstream image doesn't set `PERSISTENCE_DATA_PATH`, so data lands in `/data` unless you set it. This image defaults to `/var/lib/weaviate`. If you migrate existing data, mount it at `/var/lib/weaviate` or set the variable.      |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                     |
| Entry point        | The image uses `/bin/weaviate` as the entry point, the same as upstream, with the default arguments `--host 0.0.0.0 --port 8080 --scheme http`.                                                                                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                            |

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

The `/var/lib/weaviate` directory in this image is owned by the nonroot user (UID 65532). If you mount a host directory
there, or reuse a volume created by the upstream image (which runs as root), make sure it is writable by that UID.

To view the user for an image variant, select the **Tags** tab for this repository.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

The image uses `/bin/weaviate` as the entry point. Arguments passed after the image reference replace the default
`--host 0.0.0.0 --port 8080 --scheme http`, so include them again when you add flags of your own.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
