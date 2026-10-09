## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Trivy Policy Reporter Plugin Hardened image

This image contains `trivy-plugin`, a Policy Reporter component that enriches Trivy vulnerability findings with
detailed CVE and GHSA metadata. It reads `PolicyReports` produced from Trivy Operator `VulnerabilityReports` (via the
Trivy Operator Polr Adapter) and exposes a REST API with descriptions, affected/fixed versions, and references for
each finding.

## Start a trivy-plugin instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `trivy-plugin` is primarily designed to run within a Kubernetes cluster alongside Policy Reporter, Trivy
Operator, and the Trivy Operator Polr Adapter. The following standalone Docker command displays the available
configuration options.

```bash
docker run -d --name trivy-plugin -p 8080:8080 dhi.io/trivy-plugin:<tag>
```

## Common trivy-plugin use cases

### Install Policy Reporter with the Trivy plugin using Helm

You can install Policy Reporter with the Trivy plugin enabled using the official Helm chart and replace the image.
Replace `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update

helm upgrade --install policy-reporter policy-reporter/policy-reporter \
  --create-namespace -n policy-reporter \
  --set ui.enabled=true \
  --set plugin.trivy.enabled=true \
  --set "images.pullSecrets[0].name=<your-registry-secret>" \
  --set plugin.trivy.image.registry=dhi.io \
  --set plugin.trivy.image.repository=trivy-plugin \
  --set plugin.trivy.image.tag=<tag>
```

This assumes Trivy Operator and the Trivy Operator Polr Adapter are already installed in the cluster and producing
`PolicyReports` from Trivy `VulnerabilityReports`.

### Access the vulnerability API

Access the plugin's REST API at http://localhost:8080/v1/policies via kubectl port forward:

```bash
kubectl port-forward service/policy-reporter-trivy-plugin 8080:8080 -n policy-reporter
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Trivy Plugin            | Docker Hardened Trivy Plugin                         |
| --------------- | ------------------------------------- | ---------------------------------------------------- |
| Security        | Standard base with common utilities   | Minimal, hardened base with security patches         |
| Shell access    | Full shell (bash/sh) available        | No shell in runtime variants                         |
| Package manager | apt/apk available                     | No package manager in runtime variants                |
| User            | Runs as root by default               | Runs as nonroot user                                  |
| Attack surface  | Larger due to additional utilities    | Minimal, only essential components                    |
| Debugging       | Traditional shell debugging           | Use Docker Debug or Image Mount for troubleshooting   |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods
for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable
layer that only exists during the debugging session.

For example, you can use Docker Debug:
docker debug dhi-trivy-plugin
or mount debugging tools with the Image Mount feature:
docker run --rm -it --pid container:my-container 
--mount=type=image,source=dhi.io/busybox,destination=/dbg,ro 
dhi.io/trivy-plugin:<tag> /dbg/bin/sh
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
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image.
This and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image          | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                              |
| Package management  | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                        |
| Non-root user       | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.        |
| Multi-stage build   | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                           |
| TLS certificates    | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                |
| Ports               | Non-dev hardened images run as a nonroot user by default. trivy-plugin binds to port 8080 by default. Because hardened images run as nonroot, avoid privileged ports (\<1024). |
| Entry point         | Docker Hardened Images may have different entry points than standard images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell            | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Kubernetes RBAC     | Ensure RBAC permissions are correctly configured as trivy-plugin requires read access to `PolicyReports` and related cluster resources.                          |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your
   needs. Remember that the full stack requires multiple components: Trivy Operator, the Trivy Operator Polr Adapter,
   Policy Reporter, and this plugin.

1. **Update your image references in your Kubernetes manifests.**

   Update the image references in your Policy Reporter deployment manifests to use the hardened image. If using Helm,
   update your values file accordingly:

   - From: `ghcr.io/kyverno/policy-reporter/trivy-plugin:<tag>`
   - To: `dhi.io/trivy-plugin:<tag>`

1. **For custom deployments, update the runtime image in your Dockerfile.**

   If you're building custom images based on trivy-plugin, ensure that your final image uses the hardened
   trivy-plugin as the base. For multi-stage builds, use images tagged as `dev` for build stages and non-dev images
   for runtime.

1. **Verify component compatibility.**

   Ensure Trivy Operator, the Trivy Operator Polr Adapter, Policy Reporter, and this plugin are all using compatible
   versions. Check if your manifests include command: or args: overrides and ensure they align with the hardened
   image defaults.

1. **Test vulnerability reporting.**

   After migration, verify that `VulnerabilityReports` are being converted to `PolicyReports` and that the plugin's
   API returns enriched CVE/GHSA details as expected.

## Troubleshoot migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method
for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories
are accessible to the nonroot user. You may need to copy files to different directories or change permissions so
your application running as the nonroot user can access them.

trivy-plugin requires read access to **PolicyReports and ClusterPolicyReports** in the cluster. Ensure your RBAC
configuration grants appropriate permissions.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug
containers with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use
`docker inspect` to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
