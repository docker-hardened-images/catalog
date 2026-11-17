## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Teleport image

This Docker Hardened Teleport image includes:

- `teleport`, the Auth Service, Proxy Service and agent binary, at `/usr/local/bin/teleport`
- `tctl`, the cluster administration tool, at `/usr/local/bin/tctl`
- `tsh`, the client, at `/usr/local/bin/tsh`
- `tbot`, the Machine & Workload Identity agent, at `/usr/local/bin/tbot`
- `fdpass-teleport`, the `tsh` SSH multiplexing helper, at `/usr/local/bin/fdpass-teleport`

### Generate a configuration file

The entrypoint starts Teleport with `/etc/teleport/teleport.yaml`. Generate a starting configuration for a single
container running the Auth Service and Proxy Service and store it on the host. The `--hostname localhost` flag makes
`localhost` the node name, and therefore the cluster name, so a browser on the same machine trusts the Proxy Service's
self-signed certificate:

```
$ mkdir -p ~/teleport/config ~/teleport/data
$ docker run --rm --hostname localhost \
  --entrypoint /usr/local/bin/teleport \
  dhi.io/teleport:<tag> configure --roles=proxy,auth > ~/teleport/config/teleport.yaml
```

### Run the Auth Service and Proxy Service

Mount the configuration and a data directory and publish the Proxy Service web port (3080) and the Auth Service port
(3025). The image runs as the nonroot user, so the mounted data directory must be writable by UID 65532:

```
$ chmod 0770 ~/teleport/data && sudo chown 65532:65532 ~/teleport/data
$ docker run -d --name teleport --hostname localhost \
  -v ~/teleport/config:/etc/teleport:ro \
  -v ~/teleport/data:/var/lib/teleport \
  -p 127.0.0.1:3080:3080 -p 127.0.0.1:3025:3025 \
  dhi.io/teleport:<tag>
```

The example binds both ports to loopback because the generated configuration uses a self-signed certificate and has no
users yet. Check the Proxy Service web API:

```
$ curl --insecure https://localhost:3080/webapi/ping
{"auth":{"type":"local","second_factor":"otp",...},"proxy":{...},"server_version":"<version>",...}
```

### Create the first user

Run `tctl` inside the running container; it talks to the Auth Service through the data directory:

```
$ docker exec teleport tctl users add admin --roles=editor,access --logins=root
User "admin" has been created but requires a password. Share this URL with the user to complete user setup, link is valid for 1h:
https://<proxyhost>:3080/web/invite/<token>

NOTE: Make sure <proxyhost>:3080 points at a Teleport proxy which users can access.
```

Open the invite link in a browser, with `<proxyhost>` replaced by `localhost`, to set the password and enrol a second
factor. Set `public_addr` under `proxy_service` in `teleport.yaml` to have `tctl` print the final address.

### Run a Teleport agent

Join an SSH node or other agent to an existing cluster with a join token. Generate a node configuration pointing at the
Proxy Service address, create a data directory the nonroot user can write, then start the container with that
configuration:

```
$ mkdir -p ~/teleport/node ~/teleport/node-data && chmod 0770 ~/teleport/node-data && sudo chown 65532:65532 ~/teleport/node-data
$ docker run --rm --entrypoint /usr/local/bin/teleport dhi.io/teleport:<tag> \
  node configure --proxy=teleport.example.com:443 --token=<join-token> --output=stdout > ~/teleport/node/teleport.yaml
$ docker run -d --name teleport-node \
  -v ~/teleport/node:/etc/teleport:ro \
  -v ~/teleport/node-data:/var/lib/teleport \
  dhi.io/teleport:<tag>
```

An SSH agent that must create host user sessions, use PAM or enhanced session recording needs root and the matching host
privileges; run it with `--user 0` and the capabilities your policy allows.

### Run Machine & Workload Identity (tbot)

`tbot` is in the same image. Create a bot and a join token with `tctl bots add <name> --roles=<role>`, write a
configuration that points at the Proxy Service and renews an identity into the data directory, then start the container
with the `tbot` entrypoint:

```
$ mkdir -p ~/teleport/tbot ~/teleport/tbot-data && chmod 0770 ~/teleport/tbot-data && sudo chown 65532:65532 ~/teleport/tbot-data
$ cat > ~/teleport/tbot/tbot.yaml <<'YAML'
version: v2
proxy_server: teleport.example.com:443
onboarding:
  join_method: token
  token: <bot-join-token>
storage:
  type: directory
  path: /var/lib/teleport/bot
outputs:
  - type: identity
    destination:
      type: directory
      path: /var/lib/teleport/out
YAML
$ docker run -d --name tbot \
  --entrypoint /usr/local/bin/tbot \
  -v ~/teleport/tbot:/etc/tbot:ro \
  -v ~/teleport/tbot-data:/var/lib/teleport \
  dhi.io/teleport:<tag> start -c /etc/tbot/tbot.yaml
```

The renewed identity lands in `~/teleport/tbot-data/out`, and
`tsh -i ~/teleport/tbot-data/out/identity --proxy=teleport.example.com:443 ls` uses it.

### Deploy with the teleport-cluster Helm chart

The upstream `teleport-cluster` chart accepts an image repository and a tag override. Point it at this image and pin the
tag to the version you deploy:

```
$ helm repo add teleport https://charts.releases.teleport.dev
$ helm install teleport-cluster teleport/teleport-cluster \
  --namespace teleport-cluster --create-namespace \
  --version <version> \
  --set clusterName=teleport.example.com \
  --set image=dhi.io/teleport \
  --set teleportVersionOverride=<tag>
```

## Non-hardened images vs. Docker Hardened Images

- The upstream `teleport-distroless` image runs as root. This image runs as the nonroot user (UID 65532), so mounted
  data directories must be writable by that UID, and SSH agents that need host privileges must be started with
  `--user 0`.
- This image declares the default Teleport ports (3023, 3024, 3025, 3026 and 3080); the upstream image declares none.
  Listen addresses are unchanged.
- `teleport`, `tctl`, `tsh`, `tbot` and `fdpass-teleport` are installed at `/usr/bin` and linked from `/usr/local/bin`,
  so the upstream paths keep working.
- The image does not ship the `teleport-update` binary, matching the upstream distroless image.
- The image is published for `linux/amd64` and `linux/arm64`; the upstream image also publishes `linux/arm/v7`.
- The image sets `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt` as upstream does, pointing at the standard Docker
  Hardened Images CA bundle.
- FIPS variants use the Go FIPS 140-3 module for all Go cryptography. The Windows desktop access (RDP) client and the
  FIDO2 and PAM libraries are C and Rust components outside that module, and the Community Edition `--fips` flag is not
  available.

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
