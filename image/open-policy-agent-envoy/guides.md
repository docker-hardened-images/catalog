## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/open-policy-agent-envoy:<tag>`
- Mirrored image: `<your-namespace>/dhi-open-policy-agent-envoy:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an Open Policy Agent Envoy container

The image runs `opa-envoy run` by default, the same `opa` command line as upstream with the Envoy External Authorization
plugin built in. Create a policy and a configuration that enables the plugin:

```bash
$ mkdir -p policy config
$ cat > policy/policy.rego <<'REGO'
package envoy.authz

default allow := false

allow if input.attributes.request.http.method == "GET"
REGO
$ cat > config/config.yaml <<'YAML'
plugins:
  envoy_ext_authz_grpc:
    addr: :9191
    path: envoy/authz/allow
decision_logs:
  console: true
YAML
```

Then start the server. The gRPC port answers Envoy's `ext_authz` checks and the diagnostic port serves the health
endpoint; both are published on loopback only, because neither requires authentication:

```bash
$ docker run -d --name opa-envoy \
  -p 127.0.0.1:9191:9191 -p 127.0.0.1:8282:8282 \
  -v "$PWD/policy:/policy:ro" -v "$PWD/config:/config:ro" \
  dhi.io/open-policy-agent-envoy:<tag> \
  run --server --config-file=/config/config.yaml --addr=localhost:8181 \
  --diagnostic-addr=0.0.0.0:8282 --ignore='.*' /policy/policy.rego
```

Check that the plugin is up:

```bash
$ curl -s 'http://127.0.0.1:8282/health?plugins'
{}
```

## Common Open Policy Agent Envoy use cases

### Authorize requests for an Envoy proxy

Envoy calls the image through its `ext_authz` HTTP filter. This Compose file runs Envoy in front of the image with the
policy and configuration from the previous section; Envoy answers allowed requests with a fixed response in place of a
backend:

```yaml
services:
  opa-envoy:
    image: dhi.io/open-policy-agent-envoy:<tag>
    command:
      - run
      - --server
      - --config-file=/config/config.yaml
      - --addr=localhost:8181
      - --diagnostic-addr=0.0.0.0:8282
      - --ignore=.*
      - /policy/policy.rego
    volumes:
      - ./policy:/policy:ro
      - ./config:/config:ro
  envoy:
    image: envoyproxy/envoy:v1.37-latest
    command: ["envoy", "--config-path", "/config/envoy.yaml"]
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - ./envoy.yaml:/config/envoy.yaml:ro
    depends_on:
      - opa-envoy
```

Save the Envoy configuration as `envoy.yaml` next to the Compose file:

```yaml
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 8000
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            virtual_hosts:
            - name: backend
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                direct_response:
                  status: 200
                  body:
                    inline_string: "allowed\n"
          http_filters:
          - name: envoy.filters.http.ext_authz
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
              failure_mode_allow: false
              grpc_service:
                google_grpc:
                  target_uri: opa-envoy:9191
                  stat_prefix: ext_authz
                timeout: 0.5s
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
```

Start both services and send a request the policy allows and one it denies:

```bash
$ docker compose up -d
$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/people
200
$ curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8000/people
403
```

Each decision appears in the container log as a JSON line with `"msg":"Decision Log"`, carrying the request and the
result:

```bash
$ docker compose logs opa-envoy | grep '"Decision Log"'
```

### Listen on a Unix socket

When Envoy and the image share a pod or a volume, the plugin can listen on a Unix domain socket instead of a TCP port.
Set the address in the plugin configuration:

```yaml
plugins:
  envoy_ext_authz_grpc:
    addr: unix:///run/opa/sockets/auth.sock
    path: envoy/authz/allow
```

Mount a volume at `/run/opa/sockets` in both containers, writable by the user the image runs as (a Kubernetes `emptyDir`
is; a new Docker named volume is owned by root, so make it writable first), run both containers as the same user so that
Envoy can open the socket, and point Envoy's `ext_authz` filter at an `envoy_grpc` cluster whose endpoint address is
`pipe: {path: /run/opa/sockets/auth.sock}`. Upstream's
[envoy-uds example](https://github.com/open-policy-agent/opa-envoy-plugin/tree/main/examples/envoy-uds) shows the
complete Kubernetes manifest.

### Run as a sidecar in Kubernetes

Upstream's [quick start](https://github.com/open-policy-agent/opa-envoy-plugin/blob/main/quick_start.yaml) and the
[Istio example](https://github.com/open-policy-agent/opa-envoy-plugin/tree/main/examples/istio) run the image as a
sidecar next to Envoy. Replace `openpolicyagent/opa:latest-envoy` (or `latest-istio` in the Istio injection policy) with
`dhi.io/open-policy-agent-envoy:<tag>`; the container `args` and the `/health?plugins` probes on port 8282 work
unchanged. The quick start's `runAsUser: 1111` also works, because the image reads its policy and configuration from the
mounted volumes and writes no files.

### Use the opa command line

The `opa` subcommands (`eval`, `test`, `check`, `fmt`, `build`, `exec` and the others `opa-envoy help` lists) work as
upstream. For example, evaluate the policy against an input:

```bash
$ echo '{"attributes":{"request":{"http":{"method":"GET"}}}}' > input.json
$ docker run --rm -v "$PWD/policy:/policy:ro" -v "$PWD/input.json:/input.json:ro" \
  dhi.io/open-policy-agent-envoy:<tag> \
  eval --format=raw -d /policy/policy.rego -i /input.json data.envoy.authz.allow
true
```

## Non-hardened images vs. Docker Hardened Images

| Item                    | `openpolicyagent/opa:<version>-envoy`                                                                                 | Docker Hardened Image                                                                                                                                           |
| :---------------------- | :-------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Build                   | `-envoy` and `-istio` tags: dynamically linked with WebAssembly support; `-envoy-static`: static, without WebAssembly | Static, with WebAssembly support: `opa-envoy version` reports `WebAssembly: available` and policies compiled to WebAssembly evaluate as with the `-envoy` tags. |
| Tags                    | `<version>-envoy`, `<version>-envoy-static`, `<version>-istio`, `latest-envoy`, and others                            | No suffix, for example `1.22.2`. The same image serves the Envoy and Istio integrations.                                                                        |
| Platforms               | `-envoy`: `linux/amd64`; `-envoy-static`: `linux/amd64` and `linux/arm64`                                             | `linux/amd64` and `linux/arm64`.                                                                                                                                |
| User                    | `1000:1000`                                                                                                           | `65532`. The image runs under any uid you set, for example the quick start's `runAsUser: 1111`.                                                                 |
| Entry point and command | Entry point `/opa`, command `run`                                                                                     | Entry point `/usr/local/bin/opa-envoy`, command `run`. `/opa` resolves to the same binary, so a `command` that starts with `/opa` keeps working.                |
| Environment             | `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`                                                                    | Not set. The CA bundle is at that path, where Go reads it by default.                                                                                           |

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

  **open-policy-agent-envoy is an exception:** the FIPS variants restrict the OPA server's TLS to FIPS 140-3 approved
  algorithms, but Rego built-in functions such as `crypto.md5` and `crypto.sha1` still return results. Do not rely on
  them in policies that must stay within the FIPS boundary.

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
