## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Trivy Operator Polr Adapter Hardened image

This image contains `trivy-operator-polr-adapter`, a Kubernetes controller that watches Trivy Operator custom
resources (`VulnerabilityReport`, `ConfigAuditReport`, and others) and maps them into the vendor-neutral
`PolicyReport` and `ClusterPolicyReport` resources. It requires Trivy Operator to already be installed and running in
the cluster, along with either the PolicyReport or OpenReports CRDs.

## Start a trivy-operator-polr-adapter instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `trivy-operator-polr-adapter` is designed to run inside a Kubernetes cluster with access to the API server,
watching Trivy Operator CRDs and reconciling PolicyReports. The following standalone Docker command displays the
available configuration options.

```bash
docker run --rm dhi.io/trivy-operator-polr-adapter:<tag> run --help
```

## Common trivy-operator-polr-adapter use cases

### Install via Helm

The upstream project publishes its own Helm chart. Replace `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add trivy-operator-polr-adapter https://fjogeleit.github.io/trivy-operator-polr-adapter
helm repo update

helm upgrade --install trivy-operator-polr-adapter trivy-operator-polr-adapter/trivy-operator-polr-adapter \
  --create-namespace -n trivy-adapter \
  --set "image.pullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=trivy-operator-polr-adapter \
  --set image.tag=<tag> \
  --set crds.install=true
```

This assumes Trivy Operator is already installed and producing `VulnerabilityReport`/`ConfigAuditReport` resources in
the cluster.

### Enable specific report mappings

The adapter supports enabling individual report mappings via CLI flags, commonly set through Helm values or a
container `args` override:

```bash
trivy-operator-polr-adapter run --enable-vulnerability --enable-config-audit
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Trivy Operator Polr Adapter | Docker Hardened Trivy Operator Polr Adapter          |
| --------------- | ----------------------------------------- | ----------------------------------------------------- |
| Security        | Standard base with common utilities       | Minimal, hardened base with security patches           |
| Shell access    | Full shell (bash/sh) available            | No shell in runtime variants                           |
| Package manager | apt/apk available                         | No package manager in runtime variants                 |
| User            | Runs as root by default                   | Runs as nonroot user                                    |
| Attack surface  | Larger due to additional utilities        | Minimal, only essential components                      |
| Debugging       | Traditional shell debugging                | Use Docker Debug or Image Mount for troubleshooting      |

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
docker debug dhi-trivy-operator-polr-adapter
or mount debugging tools with the Image Mount feature:
docker run --rm -it --pid container:my-container 
--mount=type=image,source=dhi.io/busybox,destination=/dbg,ro 
dhi.io/trivy-operator-polr-adapter:<tag> /dbg/bin/sh
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
| Ports               | Non-dev hardened images run as a nonroot user by default. trivy-operator-polr-adapter binds its health probe to port 8080 by default. Avoid privileged ports (\<1024). |
| Entry point         | Docker Hardened Images may have different entry points than standard images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell            | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Kubernetes RBAC     | Ensure RBAC permissions are correctly configured; the adapter requires read access to Trivy Operator CRDs and write access to PolicyReports/ClusterPolicyReports. |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your
   needs. Remember that Trivy Operator itself must already be installed and running for this adapter to have data to
   map.

1. **Update your image references in your Kubernetes manifests.**

   Update the image references in your deployment manifests to use the hardened image. If using the upstream Helm
   chart, update your values file accordingly:

   - From: `ghcr.io/fjogeleit/trivy-operator-polr-adapter:<tag>`
   - To: `dhi.io/trivy-operator-polr-adapter:<tag>`

1. **For custom deployments, update the runtime image in your Dockerfile.**

   If you're building custom images based on trivy-operator-polr-adapter, ensure that your final image uses the
   hardened image as the base. For multi-stage builds, use images tagged as `dev` for build stages and non-dev images
   for runtime.

1. **Verify RBAC and CRD compatibility.**

   Ensure the ServiceAccount used by the adapter has the necessary permissions to watch Trivy Operator CRDs and
   create/update PolicyReport or ClusterPolicyReport resources, and that the correct CRDs (PolicyReport or
   OpenReports) are installed in the cluster.

1. **Test report mapping.**

   After migration, verify that Trivy Operator's `VulnerabilityReport`/`ConfigAuditReport` resources are being
   correctly mapped into `PolicyReport`/`ClusterPolicyReport` resources, and that downstream tooling such as Policy
   Reporter picks them up as expected.

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

trivy-operator-polr-adapter requires read access to **VulnerabilityReports and ConfigAuditReports**, and write access
to **PolicyReports and ClusterPolicyReports**, in the cluster. Ensure your RBAC configuration grants appropriate
permissions.

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
