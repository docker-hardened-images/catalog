## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Vault image

This Docker Hardened Vault image contains the Vault binary and the minimal runtime needed to operate the Vault server
and CLI tools. It is intended to be used as a runtime image for running Vault or as a base for building custom Vault
images. Runtime variants run as a nonroot user by default and do not include a shell or package manager.

## Start a Vault image

The examples below show common ways to run Vault using the hardened image.

### A quick note about `--cap-add=IPC_LOCK`

The `--cap-add=IPC_LOCK` flag in Docker grants the container the Linux `CAP_IPC_LOCK` capability, which allows processes
inside the container to use the mlock system call. This is important for security-sensitive applications like HashiCorp
Vault, which use `mlock` to lock memory and prevent secrets from being written to disk via swap. By default, Docker
containers do not have this capability, so `mlock` will fail unless it’s explicitly added. Using `--cap-add=IPC_LOCK`
enables secure memory locking without requiring full root privileges or the use of the `--privileged` flag, making it a
safer and more targeted way to allow necessary system capabilities. This is especially important in production
environments where security and compliance matter.

This is explained in the [Hashicorp Vault](https://developer.hashicorp.com/vault/docs/configuration#disable_mlock)
documentation further.

To run without the `mlock` capability, use the `compat` variant.

### Basic (dev) usage — quick local testing only

The Vault "dev" mode is useful for local testing and CI but is insecure and should never be used in production. The dev
server runs in-memory storage and automatically initializes and unseals Vault.

```bash
$ docker run --rm --name vault-dev -p 8200:8200 \
  --cap-add=IPC_LOCK \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  dhi.io/vault:<tag> server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
```

After the container starts, you can interact with Vault on http://localhost:8200 using the root token set above (here:
"root").

### Persistent file backend (single-node)

For simple persistent storage, run Vault with a file storage backend and mount a host volume. Create a small HCL config
file on the host (e.g. ./vault.hcl):

```hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
storage "file" {
  path = "/vault/data"
}
ui = true
```

Run the container and mount the config and data directories:

```bash
$ docker run -d --name vault -p 8200:8200 \
  --cap-add=IPC_LOCK \
  -v /path/on/host/vault-data:/vault/data \
  -v /path/on/host/vault.hcl:/vault/config/vault.hcl:ro \
  dhi.io/vault:<tag> server -config=/vault/config/vault.hcl
```

Notes:

- The container process will write data to `/vault/data` inside the container; mount a host directory to persist data
  beyond the container lifecycle.
- In this mode, Vault must be initialized and unsealed before it can serve secrets. Use `vault operator init` and
  `vault operator unseal` (or an auto-unseal mechanism) as described in official Vault docs.

### High-availability with Consul storage (example)

For HA setups, use a supported HA storage backend such as Consul. Example Docker Compose snippet (simplified):

```yaml
services:
  consul:
    image: consul:1.14
    command: agent -server -bootstrap-expect=1 -client=0.0.0.0
    ports:
      - "8500:8500"
    volumes:
      - consul-data:/consul/data

  vault:
    image: dhi.io/vault:<tag>
    ports:
      - "8200:8200"
    depends_on:
      - consul
    volumes:
      - ./vault.hcl:/vault/config/vault.hcl:ro
    command: server -config=/vault/config/vault.hcl
    cap_add:
      - IPC_LOCK

volumes:
  consul-data: {}
```

Example `vault.hcl` for Consul backend (hosted/configured accordingly):

```hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
storage "consul" {
  address = "consul:8500"
  path    = "vault/"
}
ui = true
```

## Environment variables

Common environment variables and options that are useful when running Vault inside a container:

| Variable                  | Description                                                                                       | Default | Required      |
| ------------------------- | ------------------------------------------------------------------------------------------------- | ------- | ------------- |
| `VAULT_DEV_ROOT_TOKEN_ID` | When running `server -dev`, sets the root token ID for the dev server                             | (none)  | No (dev only) |
| `VAULT_LOCAL_CONFIG`      | JSON string used as an alternative to a config file (useful for small configs)                    | (none)  | No            |
| `VAULT_ADDR`              | Client-side address used by vault CLI/tools to talk to the server (set by users when interacting) | (none)  | No            |
| `VAULT_API_ADDR`          | Address advertised to clients (set in production so clients can reach the Vault API)              | (none)  | No            |

Example using `VAULT_LOCAL_CONFIG` (quick single-host config):

```bash
$ docker run -d --name vault -p 8200:8200 \
  --cap-add=IPC_LOCK \
  -e VAULT_LOCAL_CONFIG='{"listener":{"tcp":{"address":"0.0.0.0:8200","tls_disable":1}},"storage":{"file":{"path":"/vault/data"}},"ui":true}' \
  -v /path/on/host/vault-data:/vault/data \
  dhi.io/vault:<tag> server -config=/vault/config
```

Using `VAULT_LOCAL_CONFIG` with the `server -config` flag instructs Vault to read the local config; when using complex
configs prefer mounting a file.

## Security notes and recommended practices

- Do not use dev mode in production. The dev server auto-unseals and is in-memory which is insecure for real workloads.
- For production, configure a proper storage backend (Consul, integrated storage in supported versions, or a cloud
  KMS-backed auto-unseal) and enable TLS. Mount certificates at runtime and set `tls_disable = 0`.
- Hardened images run as a nonroot user by default. Ensure any mounted volumes and configuration files are readable and
  writable by the nonroot user inside the container.

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

- Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
  circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

  - Run as a nonroot user
  - Improve compatibility with upstream helm charts
  - Include optional tools that are critical for certain use-cases

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item                                                                     | Migration note                                                                                                                                                                                                                                                                                                                                                               |
| :----------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image                                                               | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                                                                    |
| Package management                                                       | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                                                                  |
| Non-root user                                                            | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure                                                                                                                                                                                                                                                                                            |
| that necessary files and directories are accessible to the nonroot user. |                                                                                                                                                                                                                                                                                                                                                                              |
| Multi-stage build                                                        | Utilize images with a `dev` tag for build stages and non-dev images for runtime. To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your final runtime stage should use a non-dev image variant. |
| TLS certificates                                                         | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                                                           |
| Ports                                                                    | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on the host. |
| Entry point                                                              | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                                                                  |
| No shell                                                                 | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                                                |

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
