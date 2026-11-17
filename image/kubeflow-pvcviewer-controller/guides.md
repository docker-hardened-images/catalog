## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-pvcviewer-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-pvcviewer-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Run the controller

This image is the Kubeflow PVCViewer Controller, a Kubernetes operator. It watches `PVCViewer` resources in the
`kubeflow.org/v1alpha1` API group and creates a Deployment for each viewer (by default, a file browser pod). When
`spec.networking` is set, it also creates a Service and an Istio VirtualService. It serves the mutating and validating
admission webhooks for `PVCViewer`. The image runs the `/manager` entrypoint as user `65532`. The controller is
upstream's `pvcviewer-controller` from the
[Kubeflow Notebooks project](https://github.com/kubeflow/notebooks/tree/notebooks-v1/components/pvcviewer-controller).

Print the supported flags with:

```bash
docker run --rm dhi.io/kubeflow-pvcviewer-controller:1.11.1-alpine3.24 --help
```

The Debian 13 build takes the same arguments:

```bash
docker run --rm dhi.io/kubeflow-pvcviewer-controller:1.11.1-debian13 --help
```

The flags that matter for deployment are:

| Flag                          | Default | Purpose                                                                       |
| ----------------------------- | ------- | ----------------------------------------------------------------------------- |
| `--health-probe-bind-address` | `:8081` | Serves `/healthz` and `/readyz`.                                              |
| `--metrics-bind-address`      | `:8080` | Serves Prometheus metrics.                                                    |
| `--leader-elect`              | off     | Enables leader election. Requires in-cluster configuration.                   |
| `--kubeconfig`                |         | Path to a kubeconfig. Only needed when the controller runs outside a cluster. |
| `--zap-*`                     |         | Log encoder, level, stack trace, and time encoding options.                   |

The controller needs a Kubernetes API server. Started without one, it exits with status `1` and logs
`unable to get kubeconfig`.

## Deploy in a Kubernetes cluster

Deploy the controller with the upstream manifests from the `v1.11.1` tag of `kubeflow/notebooks`, under
`components/pvcviewer-controller`. Use the upstream `config/default` overlay and point its manager container at the DHI
image. Before you apply it, the cluster needs:

- The `PVCViewer` CustomResourceDefinition from `config/crd/bases/kubeflow.org_pvcviewers.yaml`.
- The RBAC from `config/rbac`, bound to the `controller-manager` service account.
- A TLS certificate for the webhook server, stored in the Secret `webhook-server-cert` (the upstream overlay issues it
  with cert-manager and injects the CA into the webhook configurations).
- The Istio `virtualservices.networking.istio.io` CRD. The controller watches VirtualServices on start, whether or not
  you set `spec.networking`, and it reconciles no `PVCViewer` until that kind exists.

The manager container needs these settings. The image's user is numeric (`65532`), so `runAsNonRoot` can be verified:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
  containers:
    - name: manager
      image: dhi.io/kubeflow-pvcviewer-controller:1.11.1-alpine3.24
      args:
        - --health-probe-bind-address=:8081
        - --metrics-bind-address=127.0.0.1:8080
        - --leader-elect
      ports:
        - containerPort: 9443
          name: webhook-server
          protocol: TCP
      volumeMounts:
        - mountPath: /tmp/k8s-webhook-server/serving-certs
          name: cert
          readOnly: true
  volumes:
    - name: cert
      secret:
        secretName: webhook-server-cert
        defaultMode: 420
```

The metrics endpoint listens on `127.0.0.1:8080` only. The upstream overlay adds a `kube-rbac-proxy` sidecar that serves
metrics on port `8443` with authentication. That sidecar is not part of this image.

Create a `PVCViewer` for a PersistentVolumeClaim in the same namespace. This example is based on the upstream sample.
The `pvc` and `rwoScheduling` fields are required:

```yaml
apiVersion: kubeflow.org/v1alpha1
kind: PVCViewer
metadata:
  name: example-viewer
  namespace: kubeflow-user-example-com
spec:
  pvc: example-pvc
  rwoScheduling: true
  networking:
    targetPort: 8080
    basePrefix: "/pvcviewer"
    rewrite: "/"
```

Omit `spec.networking` if you do not want a Service and a VirtualService for the viewer. Without it, the controller
creates only the Deployment. The VirtualService CRD is still required, as listed above.

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
