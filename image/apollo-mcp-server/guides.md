## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this apollo-mcp-server image

This image ships the `apollo-mcp-server` binary, built from upstream Rust sources as a hardened system package. It
serves both Model Context Protocol transports — stdio and streamable HTTP — and reads its GraphQL schema and operations
from local files, a persisted-query manifest, or an Apollo GraphOS graph. Unlike upstream's build, native TLS links the
hardened system OpenSSL rather than a vendored copy, so OpenSSL fixes arrive as a package update.

### Check the version

```bash
docker run --rm dhi.io/apollo-mcp-server:<tag> --version
```

```text
apollo-mcp-server <VERSION>
```

## Start an apollo-mcp-server instance

The server takes the path to its config file as a single positional argument. Upstream's default argument is the
placeholder `/dev/null`, which is not a valid config, so **every** run must supply a real path — a bare
`docker run dhi.io/apollo-mcp-server:<tag>` exits with `invalid type: unit value, expected a map`. This image keeps
upstream's default argument unchanged, so the behavior matches the image you are migrating from.

The server also needs a schema. Its default schema source is the Apollo GraphOS uplink, which requires credentials, so
the smallest self-contained setup points at a local schema file and lets agents introspect it:

```yaml
# config.yaml
endpoint: https://api.example.com/graphql
transport:
  type: streamable_http
  address: 0.0.0.0
  port: 8000
schema:
  source: local
  path: /data/graphql/schema.graphql
introspection:
  introspect:
    enabled: true
  execute:
    enabled: true
health_check:
  enabled: true
```

The config points at a schema under `/data/graphql`, which the second mount below provides. Create the directory next to
`config.yaml` — any valid schema works for a first run:

```bash
mkdir -p graphql
cat > graphql/schema.graphql <<'EOF'
type Query {
  hello: String
}
EOF
```

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -v "$PWD/config.yaml:/data/config.yaml:ro" \
  -v "$PWD/graphql:/data/graphql:ro" \
  dhi.io/apollo-mcp-server:<tag> /data/config.yaml
```

The MCP endpoint is served at `/mcp`. With `health_check.enabled` set, the server also answers `GET /health`, which
works as a container or Kubernetes probe; health checks are disabled by default. The image already sets
`transport.address` to `0.0.0.0` in the environment — the server's own default is `127.0.0.1`, which is unreachable from
outside the container.

The MCP endpoint itself is unauthenticated by default: anyone who can reach the published port can call every exposed
tool. The examples in this guide therefore bind the published port to loopback (`-p 127.0.0.1:8000:8000`). Before
exposing the endpoint beyond the local machine, require OAuth tokens through the config's `transport.auth` block — see
[Require OAuth authentication on the MCP endpoint](#require-oauth-authentication-on-the-mcp-endpoint).

Omitting both a schema source and an operations source is the most common startup failure: the server exits with
`Missing environment variable: APOLLO_KEY` (it fell back to the GraphOS uplink) or
`You must define operations or enable introspection`.

## Common apollo-mcp-server use cases

### Serve operations from local GraphQL files

The most common production setup pins the tools an agent may call to a reviewed set of `.graphql` operation files rather
than allowing arbitrary introspected queries. Mount a schema and an operations directory alongside the config:

```yaml
# config.yaml
endpoint: https://api.example.com/graphql
transport:
  type: streamable_http
  address: 0.0.0.0
  port: 8000
schema:
  source: local
  path: /data/graphql/schema.graphql
operations:
  source: local
  paths:
    - /data/graphql/operations
```

Reusing the `graphql/` directory and schema from the previous section, add a reviewed operation:

```bash
mkdir -p graphql/operations
cat > graphql/operations/hello.graphql <<'EOF'
query Hello {
  hello
}
EOF
```

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -v "$PWD/config.yaml:/data/config.yaml:ro" \
  -v "$PWD/graphql:/data/graphql:ro" \
  dhi.io/apollo-mcp-server:<tag> /data/config.yaml
```

Each operation file in `/data/graphql/operations` becomes one MCP tool, named after the GraphQL operation — the query
`query Hello { hello }` above is exposed as a tool called `Hello`.

### Override settings with environment variables

Every config key can also be set through an `APOLLO_MCP_`-prefixed environment variable, with `__` separating nested
keys. This is the right way to inject values you don't want in a committed config file:

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -v "$PWD/config.yaml:/data/config.yaml:ro" \
  -v "$PWD/graphql:/data/graphql:ro" \
  -e APOLLO_MCP_ENDPOINT="https://staging.example.com/graphql" \
  dhi.io/apollo-mcp-server:<tag> /data/config.yaml
```

Environment variables take precedence over the file, so the same config can be promoted across environments unchanged.

### Connect to an Apollo GraphOS graph

Instead of local files, the server can read the published schema and an operation collection straight from GraphOS.
GraphOS uplink is the default schema source, so the config needs no `schema` block at all — just supply the graph
reference and API key through the environment:

```yaml
# graphos.yaml
endpoint: https://api.example.com/graphql
transport:
  type: streamable_http
  address: 0.0.0.0
  port: 8000
health_check:
  enabled: true
```

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -v "$PWD/graphos.yaml:/data/config.yaml:ro" \
  -e APOLLO_GRAPH_REF="my-graph@current" \
  -e APOLLO_KEY="$APOLLO_KEY" \
  dhi.io/apollo-mcp-server:<tag> /data/config.yaml
```

| Variable              | Description                                                      |
| :-------------------- | :--------------------------------------------------------------- |
| `APOLLO_MCP_ENDPOINT` | URL of the GraphQL endpoint operations execute against.          |
| `APOLLO_GRAPH_REF`    | GraphOS graph reference, `graph-id@variant`.                     |
| `APOLLO_KEY`          | GraphOS API key used with `APOLLO_GRAPH_REF`. Treat as a secret. |

### Require OAuth authentication on the MCP endpoint

The server enforces OAuth 2.1 bearer-token authentication whenever the config carries a `transport.auth` block. It acts
as a resource server only — it never issues tokens. On each request it validates the JWT's signature against the
identity provider's JWKS (discovered through the provider's RFC 8414 / OpenID Connect metadata and cached), checks the
token's `aud` and `iss` claims against the configured allow-lists, and enforces scopes according to `scope_mode`.
Requests without a valid token are rejected with `401 Unauthorized`; valid tokens missing a required scope get
`403 Forbidden`. The server also serves RFC 9728 protected-resource metadata so MCP clients can discover the
authorization flow on their own. Its path is derived from `transport.auth.resource` by inserting
`/.well-known/oauth-protected-resource` ahead of the resource path — with the `resource` configured below, that is
`/.well-known/oauth-protected-resource/mcp`. Rejected requests carry a `WWW-Authenticate` header naming that same URL,
so clients need no prior knowledge of the layout.

```yaml
# config.yaml
endpoint: https://api.example.com/graphql
transport:
  type: streamable_http
  address: 0.0.0.0
  port: 8000
  auth:
    servers:
      - https://idp.example.com # OAuth 2.1 identity provider serving discovery metadata and a JWKS
    audiences:
      - apollo-mcp-server
    issuers:
      - https://idp.example.com
    resource: https://mcp.example.com/mcp # this server's externally reachable MCP URL
    scopes: []
    scope_mode: disabled
schema:
  source: local
  path: /data/graphql/schema.graphql
operations:
  source: local
  paths:
    - /data/graphql/operations
```

With token validation enforced, the port can be published beyond loopback:

```bash
docker run --rm -p 8000:8000 \
  -v "$PWD/config.yaml:/data/config.yaml:ro" \
  -v "$PWD/graphql:/data/graphql:ro" \
  dhi.io/apollo-mcp-server:<tag> /data/config.yaml
```

MCP clients must then send `Authorization: Bearer <token>` on every request, with a token issued by one of the
configured identity providers for the configured audience.

### Run over stdio for a desktop MCP client

Desktop MCP clients launch the server per session and talk to it over stdin/stdout. Run the container with `-i` so stdin
stays open; no port mapping is needed. Three environment overrides are required, and all three apply equally to
upstream's image:

- `APOLLO_MCP_TRANSPORT__TYPE=stdio` — environment values take precedence over the config file, and the image ships
  `streamable_http`, so setting `transport.type` in YAML alone has no effect.
- `-e APOLLO_MCP_TRANSPORT__ADDRESS` with **no value** — the stdio transport rejects the `address` key, so the image's
  `0.0.0.0` default must be removed. Passing `-e NAME` without `=value` makes Docker omit the variable entirely.
- `APOLLO_MCP_LOGGING__PATH=<dir>` — with no logging path the server writes its logs to **stdout**, which corrupts the
  JSON-RPC stream. Point it at a writable directory so logs go to a file instead.

```yaml
# stdio.yaml
endpoint: https://api.example.com/graphql
schema:
  source: local
  path: /data/graphql/schema.graphql
introspection:
  introspect:
    enabled: true
  execute:
    enabled: true
```

The mounted `graphql/` directory must contain the schema the config points at — if you skipped the earlier sections,
create it first:

```bash
mkdir -p graphql
cat > graphql/schema.graphql <<'EOF'
type Query {
  hello: String
}
EOF
```

```bash
docker run --rm -i \
  -e APOLLO_MCP_TRANSPORT__TYPE=stdio \
  -e APOLLO_MCP_TRANSPORT__ADDRESS \
  -e APOLLO_MCP_LOGGING__PATH=/tmp/apollo-mcp-logs \
  -v "$PWD/stdio.yaml:/data/stdio.yaml:ro" \
  -v "$PWD/graphql:/data/graphql:ro" \
  dhi.io/apollo-mcp-server:<tag> /data/stdio.yaml
```

The equivalent Claude Desktop entry in `claude_desktop_config.json` (macOS:
`~/Library/Application Support/Claude/claude_desktop_config.json`) — replace both `/absolute/path/to/...` mounts with
the real paths on your machine, since Claude Desktop does not expand `$PWD`:

```json
{
  "mcpServers": {
    "apollo": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "APOLLO_MCP_TRANSPORT__TYPE=stdio",
        "-e", "APOLLO_MCP_TRANSPORT__ADDRESS",
        "-e", "APOLLO_MCP_LOGGING__PATH=/tmp/apollo-mcp-logs",
        "-v", "/absolute/path/to/stdio.yaml:/data/stdio.yaml:ro",
        "-v", "/absolute/path/to/graphql:/data/graphql:ro",
        "dhi.io/apollo-mcp-server:<tag>",
        "/data/stdio.yaml"
      ]
    }
  }
}
```

For advanced setup including per-operation OAuth scopes, CORS and DNS-rebinding protection, Rhai request scripting,
custom scalar maps, and OpenTelemetry export, see the
[upstream Apollo MCP Server docs](https://www.apollographql.com/docs/apollo-mcp-server).

## Non-hardened images vs. Docker Hardened Images

This image's entry point is `/usr/local/bin/apollo-mcp-server`, the same path upstream's image serves the binary from.
The package installs the binary at the distro-canonical `/usr/bin/apollo-mcp-server`, and `/usr/local/bin` holds a
symlink to it, so scripts that exec the binary by either path keep working.

Two other differences matter when migrating:

- Upstream's image runs as UID/GID `1000:1000`; this image runs as the `nonroot` user, UID/GID `65532`. The working
  directory `/data` is root-owned and read-only to that user, matching upstream. If you mount files into `/data`, make
  them readable by UID 65532.
- Upstream compiles a private copy of OpenSSL into the binary. This image disables vendoring so native TLS links the
  distro-provided `libssl3t64` and receives OpenSSL fixes through image updates.

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
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

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

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
