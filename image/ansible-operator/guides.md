## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this ansible-operator image

This Docker Hardened Ansible Operator image is the base image for Kubernetes operators written in Ansible with the
[Operator SDK](https://sdk.operatorframework.io/docs/building-operators/ansible/).

- `ansible-operator`: the Operator SDK controller that watches the custom resources listed in `watches.yaml` and runs
  the matching Ansible role or playbook on every reconcile
- the Ansible runtime it drives: `ansible-core`, `ansible-runner` with the operator's HTTP event plugin, and the
  `kubernetes` Python client, installed as a virtual environment under `/usr/lib/ansible-operator-runtime` with the
  `ansible*` and `ansible-runner` commands on the `PATH`
- `tini` as the init process at `/tini`, the path the upstream entrypoint uses

No Ansible collections are bundled. As upstream does, each operator installs the collections its roles use, usually
`kubernetes.core` and `operator_sdk.util`, from its own `requirements.yml`.

Unlike most hardened runtime images, this one ships a POSIX shell and core utilities (`dash` and `coreutils` on Debian,
`busybox` on Alpine): Ansible's local connection executes every module through `/bin/sh`, so the operator cannot run
without them.

## Build an operator on this image

The Operator SDK scaffolds an Ansible operator as a `watches.yaml`, a `requirements.yml`, and `roles/` and `playbooks/`
directories next to a Dockerfile. Point that Dockerfile at this image; nothing else changes:

```dockerfile
FROM dhi.io/ansible-operator:<tag>

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/
```

`HOME` is `/opt/ansible`, the working directory the controller starts in, which is why the default entrypoint finds
`./watches.yaml` there. The image runs as user `1001` in group `0` like the upstream image, so files copied into
`${HOME}` are readable by the operator and `ansible-galaxy` can write the collections under `${HOME}/.ansible`.

Build and deploy it with the scaffolded Makefile targets:

```bash
make docker-build docker-push IMG=<registry>/<operator>:<version>
make deploy IMG=<registry>/<operator>:<version>
```

## Run the container standalone

The controller is designed to run inside a Kubernetes cluster. Running it standalone only verifies that the image
starts:

```bash
docker run --rm dhi.io/ansible-operator:<tag>
```

Without a cluster it logs `Failed to get config.` because no in-cluster configuration exists, then exits. That is the
expected standalone behavior.

To check the controller version:

```bash
docker run --rm --entrypoint /usr/local/bin/ansible-operator dhi.io/ansible-operator:<tag> version
```

To check the bundled Ansible version:

```bash
docker run --rm --entrypoint ansible dhi.io/ansible-operator:<tag> --version
```

### Ports

| Port   | Description                                        |
| ------ | -------------------------------------------------- |
| `6789` | Health probes at `/healthz` and `/readyz`          |
| `8443` | Metrics, overridable with `--metrics-bind-address` |

### Environment variables

| Variable            | Description                                                                | Default                                                          |
| ------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `WATCH_NAMESPACE`   | Namespace the controller watches; unset watches the whole cluster          | unset                                                            |
| `ANSIBLE_GATHERING` | Fact gathering policy passed to every run; `explicit` speeds reconciles up | Ansible default (`implicit`)                                     |
| `PYTHONPATH`        | Points the interpreter Ansible modules run with at the runtime venv        | `/usr/lib/ansible-operator-runtime/lib/python3.12/site-packages` |
| `LANG`, `LC_ALL`    | UTF-8 locale Ansible requires                                              | `C.UTF-8`                                                        |
| `SSL_CERT_FILE`     | CA bundle for Python TLS clients such as `ansible-galaxy`                  | `/etc/ssl/certs/ca-certificates.crt`                             |

## Non-hardened images vs. Docker Hardened Images

- The controller binary is installed at `/usr/bin/ansible-operator`; `/usr/local/bin/ansible-operator`, the path the
  upstream image and its entrypoint use, is a symlink to it. The same applies to the `ansible*` and `ansible-runner`
  commands, and `/tini` links to the distribution's `tini` package (`/usr/bin/tini` on Debian, `/sbin/tini` on Alpine).
- The Ansible runtime is a virtual environment under `/usr/lib/ansible-operator-runtime` instead of the interpreter's
  global `site-packages`. `PYTHONPATH` makes its packages visible to the system interpreter Ansible discovers for its
  modules, so `kubernetes.core` modules run unchanged. Overriding `PYTHONPATH` in a derived image, or pointing
  `ansible_python_interpreter` at a different Python minor, drops that path.
- The Debian variants ship only `dash` and `coreutils` next to Ansible; the `grep`, `sed`, `awk`, `find` and `tar`
  binaries the upstream UBI base carried are not present there, so `shell` and `command` tasks that call them need a
  `dev` build stage that installs them. The Alpine variants cover them with `busybox` applets.
- There is no package manager in the runtime variants, so the common scaffold step `USER root`, `dnf install ...`,
  `USER 1001` has no equivalent. Install extra packages in a build stage based on the `dev` variant and copy the files
  into the runtime stage, or base the operator on the `dev` variant when a package manager is acceptable.
- `pip`, `setuptools`, `wheel`, `ansible-test` and the `pip-audit` tooling the upstream image leaves behind are not
  shipped. Install Python packages in a `dev` build stage and copy the result if an operator needs extra libraries.
- Debian and Alpine variants are published for `linux/amd64` and `linux/arm64`; upstream also publishes `ppc64le` and
  `s390x`.
- The `ansible` account's home in `/etc/passwd` is `/home/ansible` (writable by uid 1001), while `HOME` and the working
  directory are `/opt/ansible` as upstream; `ansible_user_dir` therefore resolves to `/home/ansible`, upstream resolves
  `/opt/ansible`.
- The image sets `LANG`, `LC_ALL`, `SSL_CERT_FILE` and `PYTHONPATH` and declares the health and metrics ports; upstream
  sets neither.
- The FIPS variants cover the controller binary through the Go FIPS module and the Ansible runtime, including the
  `cryptography` library, through the system OpenSSL FIPS provider; hashing with MD5 fails in both.
- User `1001:0`, `HOME` and working directory `/opt/ansible`, the `/etc/ansible/ansible.cfg` and `/etc/ansible/hosts`
  files and the entrypoint stay as upstream.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **ansible-operator is an exception:** its runtime variants ship `/bin/sh` and core utilities because Ansible runs its
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

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. **ansible-operator is an exception:** its runtime variants keep `/bin/sh` for Ansible.                                                           |

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

**ansible-operator is an exception:** the runtime variants ship `/bin/sh` and core utilities because Ansible executes
its modules through them. They still ship no package manager.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
