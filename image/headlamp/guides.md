## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Headlamp Hardened Image

This Docker Hardened Headlamp image includes the Kubernetes web UI backend and the compiled React frontend it serves.
The `headlamp-server` binary listens on port `4466` and both serves the SPA and proxies requests to the Kubernetes API
using an in-cluster ServiceAccount or a mounted kubeconfig.

The image bundles:

- `headlamp-server` (Go backend) at `/usr/bin/headlamp-server`
- The compiled frontend at `/usr/share/headlamp/frontend`
- User plugin directory at `/headlamp/plugins` and bundled static plugins at `/headlamp/static-plugins`
- A `/headlamp/headlamp-server` symlink pointing to the binary for parity with the upstream image layout

## Start a Headlamp image

Run the container against an existing cluster by mounting a kubeconfig into the nonroot user's home directory:

```bash
docker run --rm -p 4466:4466 \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi.io/headlamp:<tag>
```

Or pass the kubeconfig explicitly with the `-kubeconfig` flag:

```bash
docker run --rm -p 4466:4466 \
  -v ~/.kube/config:/kubeconfig:ro \
  dhi.io/headlamp:<tag> \
  -kubeconfig /kubeconfig
```

Open `http://localhost:4466` in your browser to access the Headlamp UI.

## Common headlamp use cases

### Deploy Headlamp in-cluster

When Headlamp runs inside the cluster it uses its ServiceAccount token instead of a kubeconfig. Replace
`<your-registry-secret>` with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>`
with the desired image tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: headlamp
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: headlamp
  template:
    metadata:
      labels:
        app: headlamp
    spec:
      serviceAccountName: headlamp-admin
      imagePullSecrets:
        - name: <your-registry-secret>
      containers:
        - name: headlamp
          image: dhi.io/headlamp:<tag>
          ports:
            - containerPort: 4466
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532
            allowPrivilegeEscalation: false
```

A `ServiceAccount` with cluster-scoped read permissions (and any write permissions your operators need) must be created
separately. See the upstream Headlamp installation docs for the full role bindings.

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature         | Non-hardened Headlamp   | Docker Hardened Headlamp                            |
| --------------- | ----------------------- | --------------------------------------------------- |
| Security        | Standard base           | Minimal, hardened base with security patches        |
| Shell access    | Full shell available    | No shell in runtime variants                        |
| Package manager | apt available           | No package manager in runtime variants              |
| User            | Runs as root            | Runs as nonroot user (65532)                        |
| Attack surface  | Larger due to utilities | Minimal, only essential components                  |
| Debugging       | Traditional shell       | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/headlamp:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. The Headlamp FIPS build embeds Go's NIST-validated crypto module via `GOFIPS140=v1.0.0`, so
the binary starts in FIPS-aware mode by default. If your cluster's TLS handshake surfaces post-quantum ML-KEM issues,
set `GODEBUG=tlsmlkem=0` on the Deployment.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

Switching to the hardened Headlamp image does not require any special changes. You can use it as a drop-in replacement
for the standard Headlamp (`ghcr.io/headlamp-k8s/headlamp`) image in your existing workflows and configurations. The
default entrypoint and exposed port match upstream; the server, plugin directory (`/headlamp/plugins`), and static
plugins (`/headlamp/static-plugins`) work out of the box. The bundled frontend is served from
`/usr/share/headlamp/frontend` (the image's default `-html-static-dir`); override that flag only if you relocate it.

### Migration steps

1. Replace the image reference in your Docker run command, Compose file, or Kubernetes manifest.

1. All your existing command-line arguments, environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
