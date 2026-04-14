## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Deploy MetalLB speaker

The MetalLB speaker component runs as a DaemonSet in your cluster and is responsible for announcing LoadBalancer
services to the network using either Layer 2 (ARP) or BGP protocols.

Run the following command to deploy MetalLB with the speaker component. Replace `<your-namespace>` with your
organization's namespace and `<tag>` with the image variant you want to run.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
```

Or for BGP mode with FRR support:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
```

If you prefer to use the Docker Hardened Image directly in your deployment, replace the speaker image in your manifests:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: speaker
  namespace: metallb-system
spec:
  selector:
    matchLabels:
      app: metallb
      component: speaker
  template:
    metadata:
      labels:
        app: metallb
        component: speaker
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: speaker
        image: dhi.io/metallb-speaker:<tag>
        args:
        - --port=7472
        - --log-level=info
        ports:
        - name: metrics
          containerPort: 7472
        securityContext:
          allowPrivilegeEscalation: true
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
            - SYS_ADMIN
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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Helm charts to use
the new image. The following table outlines common migration considerations:

| Item             | Migration note                                                                                                                                                                             |
| :--------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | Replace your speaker image with the Docker Hardened Image in your DaemonSet or Helm values.                                                                                                |
| Capabilities     | The speaker requires `NET_ADMIN`, `NET_RAW`, and `SYS_ADMIN` capabilities. Ensure your pod security policies allow these.                                                                  |
| Nonroot user     | By default, the hardened speaker image runs as a nonroot user. Verify that necessary files and directories are accessible to that user.                                                    |
| Privileged mode  | In some configurations, the speaker may require privileged mode. Review your security context settings.                                                                                    |
| TLS certificates | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                         |
| Volume mounts    | Ensure any mounted configuration files or directories are accessible to the nonroot user running the speaker.                                                                              |
| Entry point      | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your manifests if necessary. |
| No shell         | The hardened speaker image doesn't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                     |

The following steps outline the general migration process:

1. Find hardened images for your deployment.

   Identify which MetalLB images you are using (speaker, controller) and select the corresponding Docker Hardened Image
   variants. A hardened image may have several variants. Inspect the image tags and find the image variant that meets
   your needs.

1. Update your image references.

   Update the image references in your Kubernetes manifests, Helm values, or deployment tools to point to the Docker
   Hardened Images.

1. Review security contexts.

   Ensure your pod security policies and security contexts are compatible with the hardened image's security
   requirements, particularly for speaker which requires specific capabilities.

1. Test in a non-production environment.

   Deploy to a test cluster first to verify that the hardened image works correctly with your network configuration and
   routing protocols.

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
accessible to that user. You may need to adjust volume mount permissions or change directory ownership so the speaker
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### Capabilities

The MetalLB speaker requires elevated Linux capabilities to function properly. Ensure your pod security policy and
security context include the required capabilities:

- `NET_ADMIN`: Required for network interface management
- `NET_RAW`: Required for raw socket access
- `SYS_ADMIN`: Required for system administrative operations

If capabilities are missing, the speaker will fail to initialize the network protocols.

### Network communication

If the speaker cannot communicate with BGP peers or ARP neighbors:

- Verify that network policies allow the speaker to send and receive traffic on the required protocols
- Check that the speaker pod can reach BGP peers on port 179
- For Layer 2 mode, ensure ARP traffic is not filtered at the network level
- Use `kubectl logs` to check the speaker logs for connection errors

### Configuration validation

Verify that your MetalLB configuration (IPAddressPool, BGPPeer, advertisements) is valid:

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get bgppeer -n metallb-system
kubectl describe bgpadvertisement -n metallb-system
```

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell. If you need to run diagnostic commands, create a temporary debug container alongside your speaker pod to
investigate network issues.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
