## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Deploy NodeLocal DNS Cache in Kubernetes (recommended)

NodeLocal DNS Cache is normally deployed as a DaemonSet with `hostNetwork: true`. Follow the upstream
[NodeLocal DNSCache guide](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/) and replace the image
reference with the Docker Hardened Image:

```
image: dhi.io/k8s-dns-node-cache:<tag>
```

The container entrypoint remains `/node-cache`, so existing manifest arguments and volume mounts can stay the same.

### Run locally for testing

For a local smoke test, skip the node-local interface and iptables setup (which require host networking) and bind the
cache to the loopback address:

```
$ docker run --rm \
  -v /path/to/Corefile:/etc/Corefile:ro \
  dhi.io/k8s-dns-node-cache:<tag> \
  -localip=127.0.0.1 -conf=/etc/Corefile \
  -setupinterface=false -setupiptables=false
```

When deployed as a DaemonSet, drop the `-setupinterface=false -setupiptables=false` flags and grant the `NET_ADMIN` and
`NET_RAW` capabilities so node-cache can create the node-local interface and program iptables rules.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

## Migrate to a Docker Hardened Image

| Item       | Migration note                                                                                                 |
| :--------- | :------------------------------------------------------------------------------------------------------------- |
| Base image | Replace `registry.k8s.io/dns/k8s-dns-node-cache` with `dhi.io/k8s-dns-node-cache:<tag>`.                       |
| Entrypoint | Upstream uses `/node-cache`; this image preserves the same entrypoint.                                         |
| Ports      | Exposes `53/tcp` and `53/udp` like upstream. In Kubernetes, NodeLocal DNS Cache runs with `hostNetwork: true`. |
| Privileges | Requires `NET_ADMIN` and `NET_RAW` capabilities (or privileged mode) to manage iptables and node networking.   |

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
