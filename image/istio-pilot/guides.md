## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

## Start an Istio Pilot image

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

The Istio Pilot image (also known as Istiod) is the **control plane component** that manages service discovery,
configuration, and certificate management. It runs as a Deployment in Kubernetes and cannot be run standalone.

Replace `<your-namespace>` with your organization's namespace, `<secret name>` with your Kubernetes image pull secret,
and `<tag>` with the image variant you want to use.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istiod
  template:
    metadata:
      labels:
        app: istiod
    spec:
      serviceAccountName: istiod
      imagePullSecrets:
      - name: <secret name>
      containers:
      - name: discovery
        image: <your-namespace>/dhi-istio-pilot:<tag>
        ports:
        - containerPort: 15010
        - containerPort: 15012
```

## Common Istio Pilot use cases

### Control plane for service mesh

Istiod provides service discovery, configuration distribution, and proxy management for all data plane components in the
mesh.

### Certificate authority

Istiod acts as a certificate authority, issuing and rotating certificates for mTLS communication between services.

### Configuration validation

Istiod validates Istio configuration resources and provides webhook endpoints for admission control.

## Docker Official Images vs. Docker Hardened Images

Key differences specific to the Istio Pilot DHI:

- **Security hardening**: Runs as a nonroot user by default
- **Minimal attack surface**: Contains only essential control plane components
- **Enhanced monitoring**: Built-in SBOM and vulnerability scanning capabilities
- **No debugging tools**: Runtime images exclude debugging utilities; use Docker Debug for troubleshooting

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Runtime variants are designed for
production use and run as a nonroot user without a shell or package manager.

To view the image variants and get more information about them, select the **Tags** tab for this repository.

## Migrate to a Docker Hardened Image

To migrate your Istio control plane to use Docker Hardened Images, update your Istio installation configuration:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: control-plane
spec:
  values:
    pilot:
      image: <your-namespace>/dhi-istio-pilot:<tag>
```

Ensure the security context allows running as a nonroot user and that all required volume mounts are configured for
certificates and configuration.

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
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
