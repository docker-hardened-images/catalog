## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this kiali-operator image

This image includes:

- the Operator SDK `ansible-operator` controller
- Kiali's Kubernetes and OpenShift watch configurations, Ansible roles, and playbooks under `/opt/ansible`
- the `community.general`, `kubernetes.core`, `operator_sdk.util`, and `ansible.posix` collections pinned by upstream
- the Ansible runtime and Python `jmespath` dependency used by the Kiali roles
- `tini`, a POSIX shell, and core utilities required by Ansible

## Deploy Kiali Operator

Kiali recommends deploying the operator with its Helm chart. First create the namespace and a pull secret that
Kubernetes can use to authenticate to `dhi.io`:

```bash
kubectl create namespace kiali-operator
kubectl create secret docker-registry dhi-pull-secret \
  --namespace kiali-operator \
  --docker-server=dhi.io \
  --docker-username='<username>' \
  --docker-password='<access-token>'
```

Install the upstream chart while overriding its operator image:

```bash
helm repo add kiali https://kiali.org/helm-charts
helm repo update kiali
helm upgrade --install kiali-operator kiali/kiali-operator \
  --namespace kiali-operator \
  --set image.repo=dhi.io/kiali-operator \
  --set image.tag=<tag> \
  --set image.pullSecrets[0]=dhi-pull-secret
```

The chart selects `watches-k8s.yaml` on Kubernetes and `watches-os.yaml` on OpenShift. It also mounts a writable
`emptyDir` at `/tmp`, which the operator uses for temporary Ansible files.

### Verify the packaged playbook

The runtime image retains `/bin/sh` because Ansible requires it. You can use it to validate the primary Kiali playbook:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/kiali-operator:<tag> \
  -c 'ansible-playbook --syntax-check playbooks/kiali-deploy.yml'
```

### Ports

| Port   | Description                               |
| ------ | ----------------------------------------- |
| `6789` | Health probes at `/healthz` and `/readyz` |
| `8080` | Operator metrics                          |

### Environment variables

| Variable          | Description                                                      | Default                    |
| ----------------- | ---------------------------------------------------------------- | -------------------------- |
| `WATCH_NAMESPACE` | Namespace containing Kiali custom resources; empty means all     | empty                      |
| `WATCHES_FILE`    | Watch configuration selected for Kubernetes or OpenShift         | unset                      |
| `ANSIBLE_CONFIG`  | Ansible configuration; the chart changes this for task profiling | `/etc/ansible/ansible.cfg` |

## Non-hardened images vs. Docker Hardened Images

- The image keeps upstream's user `1001:0`, working directory `/opt/ansible`, payload paths, and `tini`-wrapped
  `ansible-operator` entrypoint.
- The runtime variants use Debian instead of UBI and omit build-only tools such as `git`, `pip`, and package managers.
- The runtime variants retain `/bin/sh` and core utilities because Ansible executes local modules through them.
- The operator payload under `/opt/ansible` is read-only. The upstream chart already directs Ansible temporary files to
  its writable `/tmp` volume.
- Debian variants are published for `linux/amd64` and `linux/arm64`; upstream also publishes `ppc64le` and `s390x`.
- FIPS variants use the Go FIPS module for `ansible-operator` and the system OpenSSL FIPS provider for the Ansible
  runtime.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **kiali-operator is an exception:** its runtime variants ship `/bin/sh` and core utilities because Ansible runs its
  modules through them; they still ship no package manager.

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

| Item               | Migration note                                                                                                                                                                                                                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                  |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure the application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                 |
| No shell           | By default, non-dev images don't contain a shell. Kiali Operator retains `/bin/sh` because Ansible requires it.                                                                                                                                                                                                             |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged with `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages.

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged with `dev` typically have package managers. You should use a multi-stage Dockerfile to install
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The recommended method for debugging hardened runtime containers is
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/). Docker Debug provides common debugging tools in an
ephemeral, writable layer that only exists during the debugging session.

### Permissions

Runtime variants run as user `1001` in group `0`. Ensure that mounted files are readable by this user and that writable
volumes permit group `0` access. The upstream Helm chart mounts `/tmp` as an `emptyDir` for Ansible temporary files.

### Entry point

The image uses the upstream entrypoint. The Kiali Helm chart supplies `WATCHES_FILE` and controller arguments; when
running the image outside that chart, select the appropriate watch file explicitly.
