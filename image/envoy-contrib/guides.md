## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Envoy Contrib image

This Docker Hardened Envoy Contrib image ships upstream's statically linked contrib build of Envoy: the complete
high-performance L7 proxy, with the additional protocol proxies, filters, and engines from Envoy's `contrib/` tree
compiled in alongside the standard built-in extensions and Envoy's admin, metrics, and tracing surface. The binary runs
on a minimal, security-hardened base that provides CA certificates for secure upstream connections and timezone data,
and nothing else: the runtime variants carry no shell, no package manager, and no default configuration.

## Choosing between `dhi/envoy` and `dhi/envoy-contrib`

`dhi/envoy-contrib` is `dhi/envoy` with Envoy's contrib extensions compiled in. It is built from the same upstream
source tag, runs as the same nonroot user, and exposes the same admin interface — the functional difference is the set
of extensions the binary can instantiate.

**One invocation difference to be aware of when switching from `dhi/envoy`.** This image sets
`ENTRYPOINT ["/usr/local/bin/envoy"]`, matching upstream's distroless contrib image, so arguments are passed straight to
Envoy. `dhi/envoy` instead carries no entrypoint and `CMD ["envoy"]`, which means it requires you to repeat `envoy`
before the flags. In Kubernetes this makes no difference, because a pod's `command:` and `args:` override both. It only
affects direct `docker run` usage:

```bash
# dhi/envoy-contrib (this image) — flags go straight through
docker run --rm dhi.io/envoy-contrib:<tag> --config-path /etc/envoy/envoy.yaml

# dhi/envoy — the binary name has to be repeated
docker run --rm dhi.io/envoy:<tag> envoy --config-path /etc/envoy/envoy.yaml
```

Contrib extensions are maintained to a lower support bar upstream than core extensions, which is why upstream ships them
in a separate binary rather than enabling them by default. Use `dhi/envoy-contrib` only when your configuration
references one of them; otherwise use `dhi/envoy`, which ships a smaller binary with a smaller attack surface.

You can confirm which binary you are running from its version string. The contrib build appends a `-contrib` suffix to
the version, which the core `dhi/envoy` binary does not carry:

```bash
docker run --rm dhi.io/envoy-contrib:<tag> --version
# /usr/local/bin/envoy  version: <sha>/<VERSION>-contrib/Modified/RELEASE/BoringSSL
#                                            ^^^^^^^^ present only on the contrib build
```

FIPS variants additionally report `BoringSSL-FIPS` in place of `BoringSSL`.

### Which contrib extensions are available

The image builds every contrib extension that upstream enables for the target platform and TLS backend. Upstream
excludes a handful itself, via the `select()` in `contrib/all_contrib_extensions.bzl`, so the available set differs by
platform and variant. Everything not listed below — the Postgres, MySQL, SIP, RocketMQ, and Kafka proxies, the Golang
filters, the Hyperscan regex engine and input matcher, the peak-EWMA load balancing policy, the SXG and checksum
filters, and the rest — is present on every platform and in every variant:

| Extension                              | amd64 | amd64 FIPS | arm64 (both) |
| -------------------------------------- | ----- | ---------- | ------------ |
| `envoy.tls.key_providers.cryptomb`     | yes   | yes        | no           |
| `envoy.tls.key_providers.qat`          | yes   | yes        | no           |
| `envoy.compression.qatzstd.compressor` | yes   | yes        | no           |
| `envoy.compression.qatzip.compressor`  | yes   | no         | no           |
| `envoy.tls.key_providers.kae`          | no    | no         | yes          |

`envoy.network.connection_balance.dlb` is **not built on any platform**. Upstream disabled it in 1.39 because Intel's
mirror returns HTTP 202 instead of 200, which aborts the Bazel fetch and breaks the whole contrib binary; its
registration is commented out in `contrib/contrib_build_config.bzl`
([envoyproxy/envoy#45491](https://github.com/envoyproxy/envoy/issues/45491)). It returns when upstream re-enables it.

The Intel QAT/DLB and Huawei KAE extensions are hardware-accelerator integrations: they require the corresponding host
hardware and kernel drivers at runtime even where the extension is compiled in.

If a configuration references an extension that is not present, Envoy fails at startup with a "Didn't find a registered
implementation for name" error. Validate before deploying (see
[Start an Envoy Contrib instance](#start-an-envoy-contrib-instance)).

## Start an Envoy Contrib instance

Envoy requires a configuration file to define its behavior and will not start without one. Create a minimal working
configuration, validate it, then run it, replacing `<tag>` with the image variant you want to run.

```bash
# Create a minimal Envoy configuration
cat > envoy.yaml << 'EOF'
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 10000
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: example_cluster
                  host_rewrite_literal: example.com
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
  - name: example_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: example_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: example.com
                port_value: 80
EOF
```

Validate the configuration:

```bash
docker run --rm -v $(pwd)/envoy.yaml:/tmp/envoy.yaml:ro \
  dhi.io/envoy-contrib:<tag> \
  --mode validate --config-path /tmp/envoy.yaml
```

Run it in the background:

```bash
docker run -d --name my-envoy-contrib -p 9901:9901 -p 10000:10000 \
  dhi.io/envoy-contrib:<tag> \
  --config-yaml "$(cat envoy.yaml)"
```

Test that it's working:

```bash
# Check admin interface
curl http://localhost:9901/server_info

# Test the proxy (forwards requests to example.com)
curl --fail --show-error http://localhost:10000
```

Stop and remove when done:

```bash
docker stop my-envoy-contrib && docker rm my-envoy-contrib
```

## Monitoring and observability

Envoy's built-in admin interface is available on whichever port your configuration binds it to (9901 in the examples in
this guide):

```bash
curl http://localhost:9901/server_info   # server status and version
curl http://localhost:9901/stats         # runtime statistics
curl http://localhost:9901/clusters      # upstream cluster status
curl http://localhost:9901/config_dump   # the loaded configuration
```

For the full admin endpoint reference and for configuration guides on load balancing, observability, and traffic
management, see the [upstream Envoy documentation](https://www.envoyproxy.io/docs/envoy/latest/).

## Troubleshooting Envoy Contrib

### Envoy requires a configuration

Unlike some services, Envoy cannot start without a valid configuration file. Provide one inline or from a mounted file.
Unlike the upstream image, this one ships no default `CMD`, so point Envoy at the mounted path explicitly:

```bash
# Inline configuration
docker run dhi.io/envoy-contrib:<tag> --config-yaml "$(cat envoy.yaml)"

# Mounted configuration
docker run -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml:ro \
  dhi.io/envoy-contrib:<tag> \
  --config-path /etc/envoy/envoy.yaml
```

Always validate a configuration before deploying it (see
[Start an Envoy Contrib instance](#start-an-envoy-contrib-instance)).

### File permissions

The runtime variants run as the nonroot user (65532). For Envoy this particularly affects:

- Configuration files (must be readable)
- Certificate files for TLS (must be readable)
- Log files (directory must be writable if logging to files)

```bash
# Ensure configuration is readable
chmod 644 envoy.yaml

# Ensure certificates are readable but secure
chmod 600 server.key
chmod 644 server.pem
chown 65532:65532 server.key server.pem
```

### Migrating from upstream contrib images

Upstream retired the standalone `envoyproxy/envoy-contrib` repository after v1.35.0; newer contrib images ship as
`envoyproxy/envoy:contrib-*` tags. Both migrate to `dhi/envoy-contrib`. Extensions gated by platform (see the table
above) are unchanged from upstream's own gating.

The upstream `contrib-distroless-*` images and this image both run as UID 65532. The upstream non-distroless `contrib-*`
images run as root, so migrations from those tags must account for the nonroot user; see
[Privileged ports](#privileged-ports) below for the below-1024 listener implications.

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
