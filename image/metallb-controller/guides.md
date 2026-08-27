## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Deploy MetalLB controller

The MetalLB controller component runs as a Deployment in your cluster and is responsible for managing IP address
allocations for LoadBalancer services from configured pools.

Run the following command to deploy MetalLB with the controller component. Replace `<your-namespace>` with your
organization's namespace and `<tag>` with the image variant you want to run.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
```

Or for BGP mode with FRR support:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
```

If you prefer to use the Docker Hardened Image directly in your deployment, replace the controller image in your
manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller
  namespace: metallb-system
spec:
  selector:
    matchLabels:
      app: metallb
      component: controller
  template:
    metadata:
      labels:
        app: metallb
        component: controller
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: controller
        image: dhi.io/metallb-controller:<tag>
        args:
        - --port=7472
        - --log-level=info
        ports:
        - name: metrics
          containerPort: 7472
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Helm charts to use
the new image. The following table outlines common migration considerations:

| Item             | Migration note                                                                                                                                                                             |
| :--------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | Replace your controller image with the Docker Hardened Image in your Deployment or Helm values.                                                                                            |
| Capabilities     | The controller does not require elevated capabilities. Ensure capabilities are dropped for security.                                                                                       |
| Nonroot user     | By default, the hardened controller image runs as a nonroot user. Verify that necessary files and directories are accessible to that user.                                                 |
| Service account  | The controller requires appropriate RBAC permissions to watch and update services, endpoints, and MetalLB custom resources.                                                                |
| TLS certificates | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                         |
| Volume mounts    | Ensure any mounted configuration files or directories are accessible to the nonroot user running the controller.                                                                           |
| Entry point      | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your manifests if necessary. |
| No shell         | The hardened controller image doesn't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                  |

The following steps outline the general migration process:

1. Find hardened images for your deployment.

   Identify which MetalLB images you are using (controller, speaker) and select the corresponding Docker Hardened Image
   variants. A hardened image may have several variants. Inspect the image tags and find the image variant that meets
   your needs.

1. Update your image references.

   Update the image references in your Kubernetes manifests, Helm values, or deployment tools to point to the Docker
   Hardened Images.

1. Review security contexts.

   Ensure your pod security policies and security contexts are compatible with the hardened image's security
   requirements.

1. Test in a non-production environment.

   Deploy to a test cluster first to verify that the hardened image works correctly with your IP pool configuration and
   service definitions.

1. Update documentation and runbooks.

   Document the new image versions and any associated configuration changes in your deployment documentation.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to adjust volume mount permissions or change directory ownership so the controller
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### RBAC permissions

The MetalLB controller requires appropriate Kubernetes RBAC permissions to function properly. Ensure your service
account has permissions to:

- Watch and update Service resources
- Watch EndpointSlice resources
- Create and update Service status
- Watch and manage MetalLB custom resources (IPAddressPool, L2Advertisement, BGPAdvertisement, etc.)

If RBAC permissions are missing, the controller will fail to allocate IP addresses or update service status.

### IP address allocation

If the controller cannot allocate IP addresses to services:

- Verify that IPAddressPool resources are correctly configured in the metallb-system namespace
- Check that the pool has available IP addresses
- Use `kubectl describe service` to check for allocation errors in events
- Review controller logs with `kubectl logs` for detailed error messages

### Configuration validation

Verify that your MetalLB configuration resources are valid:

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
kubectl get bgpadvertisement -n metallb-system
kubectl describe ipaddresspool -n metallb-system
```

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell. If you need to run diagnostic commands, create a temporary debug container in your cluster to investigate
issues.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
