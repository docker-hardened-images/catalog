## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Consul image

The image runs the `consul` binary. With no arguments it starts a single-node development agent
(`agent -dev -client 0.0.0.0`), the same default command as the upstream `hashicorp/consul` image.

### Basic usage

Dev mode keeps all state in memory and is for local testing only. The HTTP API and web UI listen on port 8500, bound
here to the loopback interface because dev mode enables no ACLs:

```bash
$ docker run -d --name consul-dev -p 127.0.0.1:8500:8500 dhi.io/consul:<tag>
$ curl http://127.0.0.1:8500/v1/status/leader
"127.0.0.1:8300"
```

The web UI is at `http://127.0.0.1:8500/ui`.

### Use the consul CLI

The image's entry point is the CLI, so any subcommand runs directly. Against the agent started above:

```bash
$ docker exec consul-dev consul kv put app/greeting hello
Success! Data written to: app/greeting
$ docker exec consul-dev consul kv get app/greeting
hello
```

Inspect the Raft peers and take a snapshot of the cluster state, then restore it:

```bash
$ docker exec consul-dev consul operator raft list-peers
Node          ID                                    Address         State   Voter  RaftProtocol  Commit Index  Trails Leader By
4982c1f62d09  daa46a78-184f-7615-e9ae-76ccb2110dcc  127.0.0.1:8300  leader  true   3             1             -
$ docker exec consul-dev consul snapshot save /consul/data/backup.snap
Saved and verified snapshot to index 19
$ docker exec consul-dev consul snapshot restore /consul/data/backup.snap
Restored snapshot
```

Certificate generation with `consul tls` is shown in the TLS example below. For every other subcommand, see the
[Consul CLI reference](https://developer.hashicorp.com/consul/commands).

To check a configuration directory before you deploy it, validate it as a whole. A directory holding only a service
definition fails with `data_dir cannot be empty`, so this one carries the agent settings too:

```bash
$ mkdir -p validate-config
$ cat > validate-config/server.hcl <<'EOF'
datacenter       = "dc1"
data_dir         = "/consul/data"
server           = true
bootstrap_expect = 1
client_addr      = "0.0.0.0"

ui_config {
  enabled = true
}
EOF
$ docker run --rm -v "$PWD/validate-config:/consul/config:ro" dhi.io/consul:<tag> validate /consul/config
Configuration is valid!
BootstrapExpect is set to 1; this is the same as Bootstrap mode.
bootstrap = true: do not enable unless necessary
```

## Common Consul use cases

### Single server with persistence and configuration

The image ships `/consul/data` and `/consul/config`, owned by the nonroot user. Pass `-data-dir` and `-config-dir`
explicitly: the runtime image has no entry point script to add them for you (see the differences below). This example
registers a service from a mounted configuration file:

```bash
$ mkdir -p config
$ cat > config/service-web.hcl <<'EOF'
service {
  name = "web"
  port = 8080
}
EOF
$ docker volume create consul_data
$ docker run -d --name consul -p 127.0.0.1:8500:8500 -p 127.0.0.1:8600:8600/udp \
  -v consul_data:/consul/data \
  -v "$PWD/config:/consul/config:ro" \
  dhi.io/consul:<tag> \
  agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0 \
  -data-dir=/consul/data -config-dir=/consul/config
$ curl http://127.0.0.1:8500/v1/catalog/service/web
```

The DNS interface answers on port 8600, for example `dig @127.0.0.1 -p 8600 web.service.consul`.

### Server and client agents with Docker Compose

```yaml
services:
  consul-server:
    image: dhi.io/consul:<tag>
    command: agent -server -bootstrap-expect=1 -node=server -client=0.0.0.0 -ui -data-dir=/consul/data
    ports:
      - "127.0.0.1:8500:8500"
    volumes:
      - consul_data:/consul/data
  consul-client:
    image: dhi.io/consul:<tag>
    command: agent -node=client -retry-join=consul-server -client=0.0.0.0 -data-dir=/consul/data
volumes:
  consul_data:
```

After `docker compose up -d`, `docker compose exec consul-server consul members` lists both agents as `alive`.

### TLS on the HTTPS API

Create a CA and a server certificate with the image's own `consul tls` commands. The directory must be writable by the
nonroot user:

```bash
$ mkdir -p tls && chmod 0777 tls
$ docker run --rm -v "$PWD/tls:/work" -w /work dhi.io/consul:<tag> tls ca create
==> Saved consul-agent-ca.pem
==> Saved consul-agent-ca-key.pem
$ docker run --rm -v "$PWD/tls:/work" -w /work dhi.io/consul:<tag> tls cert create -server -dc dc1
==> WARNING: Server Certificates grants authority to become a
    server and access all state in the cluster including root keys
    and all ACL tokens. Do not distribute them to production hosts
    that are not server nodes. Store them as securely as CA keys.
==> Using consul-agent-ca.pem and consul-agent-ca-key.pem
==> Saved dc1-server-consul-0.pem
==> Saved dc1-server-consul-0-key.pem
```

Enable the HTTPS port in a configuration file, start the agent with the certificates mounted, and query it over HTTPS:

```bash
$ mkdir -p tls-config
$ cat > tls-config/https.hcl <<'EOF'
ports {
  https = 8501
}

tls {
  https {
    ca_file   = "/consul/config/tls/consul-agent-ca.pem"
    cert_file = "/consul/config/tls/dc1-server-consul-0.pem"
    key_file  = "/consul/config/tls/dc1-server-consul-0-key.pem"
  }
}
EOF
$ docker run -d --name consul-tls -p 127.0.0.1:8501:8501 \
  -v "$PWD/tls-config/https.hcl:/consul/config/https.hcl:ro" \
  -v "$PWD/tls:/consul/config/tls:ro" \
  dhi.io/consul:<tag> agent -dev -client 0.0.0.0 -config-dir=/consul/config
$ curl --cacert tls/consul-agent-ca.pem https://127.0.0.1:8501/v1/status/leader
"127.0.0.1:8300"
```

In FIPS variants the listener negotiates only FIPS 140-approved cipher suites and key exchange groups: AES-GCM over
P-256 works, while ChaCha20-Poly1305 and X25519 are refused.

Consul does not run under `GODEBUG=fips140=only`: its Connect CA fingerprints certificates with SHA-1, which that mode
refuses, so the agent exits at startup. Leave `GODEBUG` unset; the FIPS binary already runs with `fips140=on`.

### Kubernetes with the consul-k8s Helm chart

The consul-k8s chart starts the server and client pods through `/bin/sh` and upstream's
`/usr/local/bin/docker-entrypoint.sh`, and its readiness probes run `curl`. The runtime image has neither, so set the
chart's `global.image` to a `compat` tag:

```bash
$ helm repo add hashicorp https://helm.releases.hashicorp.com
$ helm install consul hashicorp/consul --version <version> \
  --namespace consul --create-namespace \
  --set global.image=dhi.io/consul:<tag>-compat \
  --set server.replicas=1
```

## Non-hardened images vs. Docker Hardened Images

| Feature                       | `hashicorp/consul`                                                                 | Docker Hardened Consul runtime                                                    | Docker Hardened Consul `compat`                         |
| ----------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Entry point                   | `docker-entrypoint.sh`                                                             | `/usr/local/bin/consul`                                                           | `/usr/local/bin/docker-entrypoint.sh` (upstream script) |
| Default command               | `agent -dev -client 0.0.0.0`                                                       | Same                                                                              | Same                                                    |
| User                          | Starts as root, drops to `consul` (uid 100, gid 1000)                              | Nonroot, uid 65532                                                                | Same as upstream                                        |
| `-data-dir` and `-config-dir` | Added to every `agent` command by the script                                       | Pass them yourself                                                                | Same as upstream                                        |
| Environment variables         | `CONSUL_BIND_INTERFACE`, `CONSUL_CLIENT_INTERFACE`, `CONSUL_LOCAL_CONFIG` and more | Not read: use `-bind`, `-client` and configuration files                          | Same as upstream                                        |
| Shell and tools               | `sh`, `curl`, `jq`, `nft`, `ping` and others                                       | None                                                                              | `sh`, `curl` and the tools the script calls             |
| `VOLUME`                      | `/consul/data`                                                                     | None declared; `/consul/data` exists and is writable                              | Same, owned by `consul` (uid 100)                       |
| Platforms                     | `linux/amd64`, `linux/arm64`, `linux/386`, `linux/arm/v6`                          | `linux/amd64`, `linux/arm64`                                                      | Same as runtime                                         |
| Binary path                   | `/bin/consul`                                                                      | `/usr/bin/consul`, with `/usr/local/bin/consul` and `/bin/consul` resolving to it | Same as runtime                                         |

**The `compat` variants are an exception:** they run as root at startup and include a shell, so that upstream's entry
point script can fix ownership of `/consul/data` and `/consul/config` and then run Consul as the `consul` user. Use them
when a tool depends on that script, such as the consul-k8s chart, and the runtime variants everywhere else.

On Alpine `compat` tags, `/bin/consul` is a symlink, so the script's `setcap` step fails and the container exits when
`CONSUL_ALLOW_PRIVILEGED_PORTS` is set. Leave it unset: Docker lets containers bind ports below 1024 by default. On
Kubernetes, keep Consul on its default ports.

Upstream data volumes are owned by uid 100. To reuse one with a runtime variant, run the container with
`--user 100:1000`, or change the volume's ownership to `65532:65532`.

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
