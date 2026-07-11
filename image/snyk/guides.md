## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Most Snyk commands require authentication. Provide an API token through the `SNYK_TOKEN` environment variable when
running the container.

### Start a Snyk DHI container

Replace `<tag>` with the image variant you want to run.

```bash
# Check the Snyk CLI version
$ docker run --rm dhi.io/snyk:<tag> --version
```

## Common Snyk DHI use cases

### Test a project for vulnerabilities

Mount your project and pass your API token:

```bash
$ docker run --rm -e SNYK_TOKEN -v "$PWD:/project" -w /project dhi.io/snyk:<tag> test
```

### Scan a container image

```bash
$ docker run --rm -e SNYK_TOKEN dhi.io/snyk:<tag> container test alpine:3.20
```

### Run the Model Context Protocol (MCP) server

The Snyk CLI ships an MCP server in the same binary. Start it over stdio so an AI assistant can call Snyk scans as
tools:

```bash
$ docker run --rm -i -e SNYK_TOKEN dhi.io/snyk:<tag> mcp -t stdio
```

### Use in a CI pipeline (multi-stage Dockerfile)

```dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/snyk:<tag> AS scan
ARG SNYK_TOKEN
COPY . /project
WORKDIR /project
RUN snyk test --severity-threshold=high
```

## Non-hardened images vs Docker Hardened Images

| Feature             | Standard Snyk images                | Docker Hardened Snyk                 |
| ------------------- | ----------------------------------- | ------------------------------------ |
| **Security**        | Standard base with common utilities | Hardened base with reduced utilities |
| **Package manager** | Full package managers (apk, apt)    | System package managers removed      |
| **User**            | Runs as root                        | Runs as nonroot user                 |
| **Attack surface**  | Full system utilities available     | Significantly reduced                |

## Image variants

**Runtime variants** are designed to run Snyk commands in production and CI. These images typically:

- Run as the nonroot user
- Contain only the Snyk CLI and essential dependencies (ca-certificates)
- Require `docker debug` for any debugging needs

**Dev variants** include `-dev` in the variant name and tag. They are build-time images intended for multi-stage
Dockerfiles. These variants:

- Run as root user
- Include a shell and system package manager
- Include standard development packages (bash, ca-certificates, coreutils, findutils)
- Should not be used in production

## Migrate to a Docker Hardened Image

To migrate from the official `snyk/snyk` images to Docker Hardened Images, update your deployment configuration and
potentially your Dockerfile.

| Item                   | Migration note                                                               |
| ---------------------- | ---------------------------------------------------------------------------- |
| **Base image**         | Replace `snyk/snyk` images with Docker Hardened Snyk images                  |
| **Entrypoint**         | The entrypoint is `snyk`; pass subcommands such as `test` or `mcp` directly  |
| **Package management** | System package managers removed in runtime variants                          |
| **Non-root user**      | Runtime images run as the nonroot user                                       |
| **Authentication**     | Provide `SNYK_TOKEN` as an environment variable rather than baking in config |

## Troubleshooting migration

### Authentication

Most Snyk commands require an authenticated session. Pass `-e SNYK_TOKEN` to the container, or run `snyk auth` from a
dev variant to populate the configuration mounted at the user's home directory.

### Permissions

By default, runtime image variants run as the nonroot user. Snyk writes its cache and configuration under the home
directory (`/home/nonroot`). Ensure any mounted project files are accessible to the nonroot user.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.
