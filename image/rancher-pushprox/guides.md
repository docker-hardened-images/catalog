## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rancher-pushprox:0.1.11`
- Mirrored image: `<your-namespace>/dhi-rancher-pushprox:0.1.11`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Rancher PushProx image

This Docker Hardened Rancher PushProx image includes:

- `pushprox-proxy` - The proxy that Prometheus scrapes. It listens on port 8080 and relays each scrape request to the
  client that registered the target. This is the default command.
- `pushprox-client` - The client that runs beside a scrape target. It polls the proxy for scrape requests and serves its
  own metrics on port 9369 by default. Change that address with `--metrics-addr`.

For the full flag reference and background on the pull model, see the
[upstream project](https://github.com/rancher/PushProx).

## Start a Rancher PushProx image

A PushProx setup has one proxy that Prometheus can reach and one client on each host that runs a scrape target. Start
the proxy first.

### Start the proxy

```bash
docker network create pushprox
docker run -d --name pushprox-proxy --network pushprox -p 8080:8080 dhi.io/rancher-pushprox:0.1.11
```

The container runs the default command, `pushprox-proxy`. Check that the proxy answers and that no client has registered
yet:

```bash
curl -s http://localhost:8080/clients
curl -s http://localhost:8080/metrics | head -n 5
```

`/clients` lists the registered clients. `/metrics` reports the proxy's own metrics.

### Run a client

Run a client on the host that runs the target. The image has no entry point, so the arguments you pass after the image
name replace the default command. Start the client with `pushprox-client`:

```bash
docker run -d --name pushprox-client --network pushprox dhi.io/rancher-pushprox:0.1.11 pushprox-client \
  --proxy-url=http://pushprox-proxy:8080 --fqdn=pushprox-client --metrics-addr=:9369
```

This example runs the client on the same Docker network as the proxy, so both containers resolve each other by name. On
another host, replace `http://pushprox-proxy:8080` with the address where the proxy is reachable, for example
`http://<proxy-host>:8080`. The client fetches each scrape target itself, so `--fqdn` must be a name that resolves from
the client's network to the host that runs the target. The client then appears in the proxy's client list:

```bash
curl -s http://localhost:8080/clients
```

## Common Rancher PushProx use cases

### Scrape a target through the proxy

Prometheus reaches each target through `proxy_url`, and the proxy hands the request to the client that owns the target.
The target host must match the `--fqdn` that the client registered with, followed by the port the target listens on,
such as a node exporter on port 9100:

```yaml
scrape_configs:
  - job_name: pushprox
    scrape_interval: 15s
    proxy_url: http://<proxy-host>:8080
    static_configs:
      - targets:
          - <client-fqdn>:9100
```

To check the same path without Prometheus, send the request through the proxy with `curl`. The proxy requires the
`X-Prometheus-Scrape-Timeout-Seconds` header, which Prometheus sends on every scrape. This example scrapes the client's
own metrics endpoint on port 9369:

```bash
curl -s -x http://localhost:8080 -H 'X-Prometheus-Scrape-Timeout-Seconds: 10' http://pushprox-client:9369/metrics | head -n 5
```

Without the header, the proxy refuses the request, so the scrape does not return `200`.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened Rancher PushProx image differs from the upstream `rancher/pushprox` image in the following ways:

| Item          | Upstream `rancher/pushprox:v0.1.11`                      | Docker Hardened Image                                                                                                                                                                    |
| :------------ | :------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User          | Runs as root.                                            | Runs as the nonroot user, UID `65532`. A manifest that sets `runAsUser: 1000`, as the upstream chart does, also runs the image, because no path needs to be owned by the runtime user.   |
| Entry point   | No entry point. The default command is `pushprox-proxy`. | No entry point. The default command is `pushprox-proxy`. Arguments replace that command, so to run the client, pass `pushprox-client` first. In Kubernetes, set `args` to the same list. |
| Exposed ports | None declared.                                           | `8080/tcp`, the proxy's listen port. The client's `9369` is not declared because the client is not the default command.                                                                  |

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
