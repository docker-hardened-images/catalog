## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/trino:<tag>`
- Mirrored image: `<your-namespace>/dhi-trino:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Trino image

This Docker Hardened Trino image includes:

- Trino server binaries at `/usr/lib/trino/bin/`, including `run-trino`, `launcher`, and `health-check`
- Trino CLI at `/usr/bin/trino`
- Default CMD: `/usr/lib/trino/bin/run-trino`

Note: By default, only the `server-core` plugin set is included in the runtime and dev variants. The compat variant
includes the full set of optional Trino plugins. See [Image variants](#image-variants) for details.

The `ranger` plugin is currently not present in this image as it cannot be properly hardened. Additionally, the Redshift
JDBC driver has been upgraded as part of hardening; users with extremely long (>127 characters) table names may
experience [a known issue](https://github.com/aws/amazon-redshift-jdbc-driver/issues/148).

## Prerequisites

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
repository**, and then follow the on-screen instructions.

## Start a Trino instance

Run the following command and replace `<your-namespace>` with your organization's namespace and `<tag>` with the image
variant you want to run.

```
docker run -d --name my-trino -p 8080:8080 <your-namespace>/dhi-trino:<tag>
```

Verify the server is running and connect using the Trino CLI:

```
docker exec -it my-trino trino
```

## Common Trino use cases

### Connect with the Trino CLI

Use the Trino CLI to connect to a running Trino server instance and run queries interactively.

```
docker exec -it my-trino trino
```

### Install additional plugins

By default, only the `server-core` plugin set is included in this image. If your application requires additional
plugins, follow Trino's guide for
[installing and configuring additional plugins](https://trino.io/docs/current/installation/plugins.html).

To use all optional plugins without manual installation, use the compat image variant, which includes the
[full plugin set](https://trino.io/docs/current/installation/plugins.html#list-of-plugins) that ships with Trino.

```
docker run -d --name my-trino -p 8080:8080 <your-namespace>/dhi-trino:<compat-tag>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Trino                  | Docker Hardened Trino                               |
| --------------- | -------------------------------------- | --------------------------------------------------- |
| Security        | Standard base, less frequently patched | Minimal, hardened base with active security patches |
| Shell access    | `bash` available                       | `bash` available                                    |
| Package manager | Not available                          | Not available in runtime variants                   |
| User            | `trino` (nonroot)                      | `trino` (nonroot)                                   |
| Attack surface  | Larger due to less hardened base       | Minimal, actively maintained with CVE fixes         |
| Compliance      | None                                   | CIS benchmark compliant                             |
| Debugging       | Traditional shell debugging            | Docker Debug or shell debugging                     |

### Why use Docker Hardened Images?

Docker Hardened Images prioritize security through active patching and a minimal base:

- **Reduced attack surface:** Actively maintained with security patches and CVE fixes.
- **Compliance ready:** CIS benchmark compliant out of the box, with FIPS and STIG variants available for regulated
  environments.
- **Immutable infrastructure:** Runtime containers shouldn't be modified after deployment.

For debugging, you can use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers:

```
docker debug <container-name>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. To view all available image variants
and their tags, select the **Tags** tab for this repository.

**Runtime variant** is designed to run Trino in production. This image:

- Runs as the `trino` nonroot user
- Includes a `bash` shell
- Does not include a package manager
- Contains only the `server-core` plugin set
- Is CIS benchmark compliant

**Dev variant** is intended for use in the first stage of a multi-stage Dockerfile. This image:

- Runs as the `root` user
- Includes a `bash` shell and `apt-get` package manager
- Is used to build or compile applications
- Is CIS benchmark compliant

**Compat variant** is designed to support more seamless usage as a drop-in replacement for the upstream Trino image.
This image:

- Runs as the `trino` nonroot user
- Includes a `bash` shell
- Does not include a package manager
- Includes the full set of optional Trino plugins
- Is CIS benchmark compliant

**Compat-dev variant** combines the compat plugin set with dev tooling. This image:

- Runs as the `root` user
- Includes a `bash` shell and `apt-get` package manager
- Includes the full set of optional Trino plugins
- Is CIS benchmark compliant

**FIPS variant** is available for environments requiring FIPS 140 validated cryptographic modules. This image:

- Runs as the `trino` nonroot user
- Includes a `bash` shell
- Does not include a package manager
- Is CIS, FIPS, and STIG compliant
- Requires a paid subscription — start a 30-day free trial to access this variant

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                 |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                      |
| Package management | Only `dev` variants include a package manager. Use `dev` variants in build stages and runtime variants for production.                                                                                                                                                                         |
| Non-root user      | Runtime and compat variants run as the `trino` nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                          |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                             |
| Ports              | Runtime and compat variants run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Docker Engine versions older than 20.10. Configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | All variants use `run-trino` as the default CMD rather than ENTRYPOINT, meaning it can be overridden easily. Inspect entry points and update your Dockerfile if necessary.                                                                                                                     |
| Plugins            | The runtime variant includes only the `server-core` plugin set. Use the compat variant if you require the full plugin set.                                                                                                                                                                     |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   build stages, use a `dev` variant as it includes the tools needed to install packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image.**

   To ensure that your final image is as minimal as possible, use a multi-stage build. Intermediary stages typically use
   `dev` variants, while your final runtime stage should use a non-dev variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages to reduce the potential attack surface. Install any additional
   packages in the build stage using a `dev` variant, then copy necessary artifacts to the runtime stage.

1. **Select the right plugin set.**

   If your application requires plugins beyond `server-core`, either install them manually following Trino's
   [plugin guide](https://trino.io/docs/current/installation/plugins.html), or use the compat variant which includes the
   full plugin set.

## Troubleshoot migration

### General debugging

The recommended method for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

```
docker debug <container-name>
```

### Permissions

By default, runtime and compat variants run as the `trino` nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### Privileged ports

Runtime and compat variants run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Docker Engine versions older than 20.10. To avoid issues, configure your
application to listen on port 1025 or higher inside the container, even if you map it to a lower port on the host. For
example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### Entry point

All variants use `run-trino` as the default CMD rather than ENTRYPOINT. This means the command can be overridden easily.
Use `docker inspect` to verify the entry point and update your Dockerfile if necessary.
