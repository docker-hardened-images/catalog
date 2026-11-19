## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-profile-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-profile-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What the image runs

The image's entrypoint is the `/manager` binary, the Kubeflow profile controller. The image has no default command, so
any arguments you pass to `docker run` are flags for the controller.

The controller reconciles `Profile` resources into tenant namespaces. It needs a Kubernetes cluster, either through
in-cluster service account credentials when it runs in a pod or through a kubeconfig file (`-kubeconfig`) when it runs
outside the cluster. Install the `Profile` CRD and the RBAC the controller needs in the cluster before you start it.

## Check the flags

Print the controller's flags. This command needs no cluster:

```bash
$ docker run --rm dhi.io/kubeflow-profile-controller:2.0.1 -h
```

The flags you are most likely to set:

| Flag                         | Default                                         | Purpose                                                                    |
| ---------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------- |
| `-kubeconfig`                | none                                            | Kubeconfig path. Only needed when the controller runs outside the cluster. |
| `-namespace-labels-path`     | `/etc/profile-controller/namespace-labels.yaml` | YAML map of labels set on every Profile namespace.                         |
| `-leader-elect`              | `false`                                         | Enable leader election when running more than one replica.                 |
| `-metrics-bind-address`      | `:8080`                                         | Address for the Prometheus metrics endpoint (`/metrics`).                  |
| `-health-probe-bind-address` | `:9876`                                         | Address for the health endpoints (`/healthz`, `/readyz`).                  |

## Provide the namespace labels file

At startup the controller reads the labels file at `-namespace-labels-path`. The default path is
`/etc/profile-controller/namespace-labels.yaml`. The image does not ship that file. If the file is missing, the
controller exits during setup with
`Failed to watch file /etc/profile-controller/namespace-labels.yaml: no such file or directory`.

Mount a file at the default path, or pass `-namespace-labels-path` with the path of a mounted file. The file is a YAML
map of label keys to values. An empty map (`{}`) is accepted.

## Run in Kubernetes

The following manifest runs the controller as a nonroot process with a read-only root filesystem and mounts the labels
file from a ConfigMap. It uses the image's numeric user, `65532`. The Deployment also needs a `profile-controller`
ServiceAccount, the `Profile` CRD, and the RBAC from the upstream Kubeflow manifests.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: profile-namespace-labels
  namespace: kubeflow
data:
  namespace-labels.yaml: |
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: profile-controller
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: profile-controller
  template:
    metadata:
      labels:
        app: profile-controller
    spec:
      serviceAccountName: profile-controller
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: manager
          image: dhi.io/kubeflow-profile-controller:2.0.1
          ports:
            - name: metrics
              containerPort: 8080
            - name: health
              containerPort: 9876
          livenessProbe:
            httpGet:
              path: /healthz
              port: 9876
          readinessProbe:
            httpGet:
              path: /readyz
              port: 9876
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: namespace-labels
              mountPath: /etc/profile-controller
              readOnly: true
      volumes:
        - name: namespace-labels
          configMap:
            name: profile-namespace-labels
```

The ConfigMap mounts at `/etc/profile-controller`, so the controller finds `namespace-labels.yaml` at its default path
and you don't need to pass `-namespace-labels-path`.

Health endpoints listen on port `9876` (`/healthz` and `/readyz`). Prometheus metrics are served on port `8080`
(`/metrics`).

## Debugging

The runtime image has no shell and no package manager. To inspect the filesystem or the environment, use the `-dev` tag,
which runs as root and includes a shell. Its entrypoint is still `/manager`, so override it:

```bash
$ docker run --rm --entrypoint /bin/bash dhi.io/kubeflow-profile-controller:2.0.1-dev -c 'id'
```

Do not use the `-dev` tag in the Deployment above. Dev images run as root (uid `0`), and a Deployment with
`runAsNonRoot: true` rejects them: the kubelet does not start a container whose image user is root. Dev leaves are
rejected by an upstream-style `runAsNonRoot` deployment and are for debugging only. Run them in a separate debug pod or
with `docker run`, never in the production Deployment.

For the full upstream reference, including every Profile field and the cluster-side setup, see the
[Kubeflow dashboard project](https://github.com/kubeflow/dashboard).

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
