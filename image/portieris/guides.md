## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/portieris:<tag>`
- Mirrored image: `<your-namespace>/dhi-portieris:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included

This image packages the `portieris` binary, a Kubernetes mutating admission webhook that enforces image security
policies defined in `ImagePolicy` and `ClusterImagePolicy` resources. It serves the webhook over HTTPS on port 8000
(`/admit`, `/health/liveness`, `/health/readiness`) and Prometheus metrics over HTTP on port 8080 (`/metrics`). See the
[upstream project](https://github.com/IBM/portieris) and its
[policy reference](https://github.com/IBM/portieris/blob/main/POLICIES.md) for the full policy syntax.

## Install Portieris with the upstream Helm chart

Portieris runs inside a Kubernetes cluster. The upstream Helm chart, published with each
[release](https://github.com/IBM/portieris/releases), installs the CRDs, the Deployment, the Service, the RBAC and the
`MutatingWebhookConfiguration`. Point its `image.host`, `image.image` and `image.tag` values at this image, and set
`securityContext.runAsUser` to `65532`: the chart defaults to `1000060001`, which can't write the image's `/run` work
directory.

Download and unpack the chart for the release that matches the image tag, then generate the webhook certificates for the
`portieris` namespace with the script the chart ships (it needs `bash` and `openssl`):

```bash
$ curl -fsSLO https://github.com/IBM/portieris/releases/download/v<version>/portieris-v<version>.tgz
$ tar xzf portieris-v<version>.tgz
$ bash portieris/gencerts portieris
```

Create the namespace and a pull secret for `dhi.io`, then install the chart:

```bash
$ kubectl create namespace portieris
$ kubectl create secret docker-registry dhi-pull --namespace portieris \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<access-token>
$ helm install portieris ./portieris --namespace portieris \
  --set image.host=dhi.io \
  --set image.image=portieris \
  --set image.tag=<tag> \
  --set image.pullSecret=dhi-pull \
  --set securityContext.runAsUser=65532
$ kubectl --namespace portieris rollout status deployment/portieris
```

The chart's `ImagePolicy` in the `portieris` namespace allows `dhi.io/portieris`, so Portieris can admit its own pods.

## Common Portieris use cases

### Allow images cluster-wide

With the chart's default `PolicySet: None`, Portieris denies every image in a namespace that has no `ImagePolicy` while
no `ClusterImagePolicy` exists. Create a `ClusterImagePolicy` that lists the repositories your cluster may run:

```bash
$ kubectl apply -f - <<'EOF'
apiVersion: portieris.cloud.ibm.com/v1
kind: ClusterImagePolicy
metadata:
  name: allow-trusted-registries
spec:
  repositories:
    - name: "registry.example.com/*"
EOF
```

### Restrict one namespace

An `ImagePolicy` in a namespace replaces the cluster policies for that namespace. A pattern can carry a wildcard inside
the path:

```bash
$ kubectl create namespace payments
$ kubectl apply -f - <<'EOF'
apiVersion: portieris.cloud.ibm.com/v1
kind: ImagePolicy
metadata:
  name: payments-only
  namespace: payments
spec:
  repositories:
    - name: "registry.example.com/payments/*"
    - name: "registry.example.com/*/sidecar"
EOF
```

A pod in `payments` whose image no pattern matches is refused by the webhook:

```bash
$ kubectl run web --namespace payments --image=registry.example.com/web/app:1 --dry-run=server
Error from server: admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request:
Deny "registry.example.com/web/app:1", no matching repositories in the ImagePolicies
```

### Require signed images

A `simple` policy admits an image only when it carries a signature from the key in its `keySecret` Secret, which holds
the armored public key under `key`. `storeURL` names the lookaside store that serves the signatures when the registry
does not serve them itself:

```bash
$ kubectl create namespace releases
$ gpg --export --armor <fingerprint> > signer.pub
$ kubectl create secret generic signer-key --namespace releases --from-file=key=signer.pub
$ kubectl apply -f - <<'EOF'
apiVersion: portieris.cloud.ibm.com/v1
kind: ImagePolicy
metadata:
  name: releases-signed
  namespace: releases
spec:
  repositories:
    - name: "registry.example.com/releases/*"
      policy:
        simple:
          requirements:
            - type: signedBy
              keySecret: signer-key
          storeURL: https://sigstore.example.com
EOF
```

The webhook rewrites an admitted image to the digest the signature covers. It refuses an unsigned image with
`simple: policy denied the request: A signature was required, but no signature exists`, and an image signed by another
key with `Key not found for key ID <id> in signature`.

### Monitor admission decisions

The webhook counts its decisions in `portieris_pod_admission_decision_allow_count` and
`portieris_pod_admission_decision_deny_count` on port 8080. The chart annotates the pods with `prometheus.io/scrape` and
`prometheus.io/port: "8080"` for annotation-based scraping. To read the counters directly:

```bash
$ kubectl --namespace portieris port-forward deployment/portieris 8080:8080
$ curl -s http://127.0.0.1:8080/metrics | grep portieris_pod_admission_decision
```

## Non-hardened images vs. Docker Hardened Images

| Item                      | `icr.io/portieris/portieris`                                       | Docker Hardened Image                                                                                                                                                                                                                                                                                      |
| :------------------------ | :----------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                      | `1000060001`                                                       | `65532`. Upstream makes the `/run` work directory, where Portieris writes its Notary trust cache, writable by group 0 for any uid; here only `65532` can write it. Install the upstream chart with `--set securityContext.runAsUser=65532`, which its OpenShift `SecurityContextConstraints` also follows. |
| Entry point and command   | No entry point; the command is `/portieris --alsologtostderr -v=4` | The entry point is `/usr/local/bin/portieris` and the command is `--alsologtostderr -v=4`. If you override a container's `args` with a list that starts with `/portieris`, set that list as `command` instead. `/portieris` resolves to the same binary.                                                   |
| Tags                      | `v`-prefixed, for example `v0.16.2`                                | No prefix, for example `0.16.2`.                                                                                                                                                                                                                                                                           |
| Platforms                 | `linux/amd64`                                                      | `linux/amd64` and `linux/arm64`.                                                                                                                                                                                                                                                                           |
| Read-only root filesystem | Not set by the chart                                               | Portieris writes its Notary trust cache under `/run` and its log files under `/tmp`. When you set `readOnlyRootFilesystem: true`, mount writable volumes, such as `emptyDir`, at both paths.                                                                                                               |

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
