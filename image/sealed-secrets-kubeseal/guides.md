## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this sealed-secrets-kubeseal Hardened image

This image contains `sealed-secrets-kubeseal`, the client side tool used to encrypt Kubernetes secrets to create
SealedSecret resources. The entry point for the image is `kubeseal`, the client side CLI for Sealed Secrets.

## Start a sealed-secrets-kubeseal instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm -it dhi.io/sealed-secrets-kubeseal:<tag> --help
```

## Common sealed-secrets-kubeseal use cases

### Using Kubeseal to Encrypt Secrets

In order to use kubeseal, the sealed-secrets-controller must be deployed on the Kubernetes cluster. Once the
sealed-secrets-controller is deployed, the docker run command can be used to run the sealed-secrets-kubeseal to encrypt
or validate sealed secrets.

First, create a Kubernetes Secret (if it is not already created)

```bash
kubectl create secret generic mysecret --dry-run=client \
  --from-literal=password=secret \
  -o yaml > mysecret.yaml
```

This will generate mysecret.yaml with the following content

```bash
apiVersion: v1
data:
  password: c2VjcmV0
kind: Secret
metadata:
  name: mysecret
```

Once the Kubernetes secret yaml or json is generated, create the SealedSecret resource and confirm it was applied
correctly.

```bash
docker run dhi.io/sealed-secrets-kubeseal:<tag> \
  -v $KUBECONFIG:/.kube/config:ro \
  -e KUBECONFIG=/.kube/config \
  -o yaml \
  mysecret.yaml sealed-secret.yaml

kubectl apply -f sealed-secret.yaml
kubectl get secrets mysecret
```

A created sealed secret can also be validated using the --validate argument.

```bash
docker run dhi.io/sealed-secrets-kubeseal:<tag> \
  -v $KUBECONFIG:/.kube/config:ro \
  -e KUBECONFIG=/.kube/config \
  --validate \
  sealed-secret.yaml
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened sealed-secrets-kubeseal | Docker Hardened sealed-secrets-kubeseal             |
| --------------- | ------------------------------------ | --------------------------------------------------- |
| Security        | Standard base with common utilities  | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available       | No shell in runtime variants                        |
| Package manager | apt/apk available                    | No package manager in runtime variants              |
| User            | Runs as root by default              | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities   | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging          | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/sealed-secrets-kubeseal
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/sealed-secrets-kubeseal:<tag> /dbg/bin/sh
```

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

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                                     |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                               |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                              |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                      |
| Ports              | Non-dev hardened images run as a nonroot user by default. `sealed-secrets-kubeseal` does not bind to any network ports by default. Because hardened images run as nonroot, avoid privileged operations. |
| Entry point        | Docker Hardened Images may have different entry points than standard images. The DHI sealed-secrets-kubeseal entry point is `/usr/local/bin/kubeseal`.                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                             |

The following steps outline the general migration process.

1. **Find hardened images for your CLI usage.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The sealed-secrets-kubeseal CLI is typically used in to generate and verify Sealed Secrets for GitOps workflows.

1. **Update your CI/CD pipeline configurations.**

   Update the image references in your CI/CD scripts, GitHub Actions, or other automation to use the hardened images:

   - From: `ghcr.io/bitnami-labs/sealed-secrets-kubeseal:<tag>`
   - To: `dhi.io/sealed-secrets-kubeseal:<tag>`

1. **For custom containers, update the base image in your Dockerfile.**

   If you're building custom images that include sealed-secrets-kubeseal, ensure that your final image uses the hardened
   sealed-secrets-kubeseal as the base. For multi-stage builds, use images tagged as `dev` for build stages and non-dev
   images for runtime.

1. **Test kubeseal functionality.**

   To verify that kubeseal is functioning properly, verify that is it able to read any existing SealedSecrets or
   generate a new SealedSecret.

   ```
   # If the secret is not already generated
   kubectl create secret generic mysecret --dry-run=client \
     --from-literal=password=secret \
     -o yaml > secret.yaml

   kubeseal -f mysecret.yaml -w mysealedsecret.yaml
   kubectl apply -f sealedsecret.yaml

   kubectl get secret mysecret
   ```

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
