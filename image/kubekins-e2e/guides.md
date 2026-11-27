## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this kubekins-e2e image

This Docker Hardened kubekins-e2e image includes:

- **runner.sh**: the entrypoint, unchanged from upstream. It runs the command you pass, activates gcloud credentials
  when `GOOGLE_APPLICATION_CREDENTIALS` is set, and starts Docker Engine first when `DOCKER_IN_DOCKER_ENABLED=true`.
- **kubetest2** with the `gce`, `gke` and `kind` deployers, the `noop` deployer, and the `exec`, `ginkgo`, `node` and
  `clusterloader2` testers.
- **kubetest2-kops** and **kubetest2-tester-kops**, the kops deployer and tester.
- **kind** and **kubectl**.
- **Docker Engine**, the Docker CLI and the buildx plugin, for Docker-in-Docker.
- **Go**, with gcc for cgo builds, and `make` and `git`.
- **Google Cloud CLI** (`gcloud`, `gsutil`, `bq`) with **gke-gcloud-auth-plugin**, **helm**, the **GitHub CLI** (`gh`),
  and **cfssl** with **cfssljson**.
- **AWS CLI version 2**, on Debian tags only.
- Python 3.13 with `pip`, `curl`, `jq`, `rsync`, `wget`, `zip`, `unzip`, `xz`, `ip` and `ssh`, and `graphviz` on Alpine
  tags only.

Every tag has `gcc` and the C library headers, which the Go toolchain depends on. The `-dev` tags run as root and add
`apt` or `apk`, to install what a job needs beyond this list; the Debian `-dev` tags also set the `en_US.UTF-8` locale.
The Alpine tags have `bc` and `ping` as BusyBox commands: every Alpine package that provides `/bin/sh` depends on
BusyBox.

## Start a kubekins-e2e image

The entrypoint runs whatever command follows the image name. This starts Docker Engine inside the container, creates a
kind cluster with kubetest2, lists its nodes with kubectl and deletes the cluster:

```bash
$ docker run --rm --privileged --user 0 \
  -v kubekins-docker:/docker-graph \
  -e DOCKER_IN_DOCKER_ENABLED=true \
  dhi.io/kubekins-e2e:<tag> \
  kubetest2 kind --cluster-name demo --up --down --test=exec -- kubectl get nodes
```

kubectl lists the cluster's node, `demo-control-plane`, with the role `control-plane`; then kind deletes the cluster and
runner.sh stops Docker Engine. The node image is kind's default, which is Kubernetes 1.37; on the `1.36` and `1.35` tags
pass `--image-name kindest/node:<version>` with a node image of that Kubernetes line.

Docker-in-Docker needs root and a privileged container: on the runtime tags pass `--user 0 --privileged` (in Kubernetes,
`runAsUser: 0` and `privileged: true`). Mount a volume at `/docker-graph`, where Docker Engine keeps its images and
containers, as Prow's Docker-in-Docker preset mounts an `emptyDir` there. Without `--user 0`, runner.sh cannot start
Docker Engine, waits for it, and then runs the command, which fails if it needs Docker.

Docker Engine uses the legacy iptables backend, as in upstream's image, so the host kernel must provide legacy iptables.
On a host without it, Docker Engine stops with `` can't initialize iptables table `nat': Table does not exist ``. Point
the iptables tools at the nf_tables backend before runner.sh starts Docker Engine:

```bash
$ docker run --rm --privileged --user 0 \
  -v kubekins-docker:/docker-graph \
  -e DOCKER_IN_DOCKER_ENABLED=true \
  --entrypoint bash \
  dhi.io/kubekins-e2e:<tag> \
  -c 'for t in iptables iptables-save iptables-restore ip6tables ip6tables-save ip6tables-restore; do ln -sf xtables-nft-multi "/usr/sbin/$t"; done; exec runner.sh "$@"' bash \
  kubetest2 kind --cluster-name demo --up --down --test=exec -- kubectl get nodes
```

### Environment variables

runner.sh reads these variables. None of them is set in the image.

| Variable                         | Description                                                                                      | Default | Required |
| -------------------------------- | ------------------------------------------------------------------------------------------------ | ------- | -------- |
| `DOCKER_IN_DOCKER_ENABLED`       | `true` starts Docker Engine before the command and stops it after.                               | `false` | No       |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to a service account key; runner.sh runs `gcloud auth activate-service-account` first.      | unset   | No       |
| `BOOTSTRAP_MTU_WORKAROUND`       | `true` adds an iptables rule that clamps the TCP MSS, after Docker Engine starts.                | `false` | No       |
| `PROW_CLOUD_PROVIDER`            | `amazon` makes Docker Engine pull through `public.ecr.aws/docker/library`, else `mirror.gcr.io`. | unset   | No       |

The image sets upstream's environment: `WORKSPACE=/workspace`, `GOPATH=/go`, `KUBETEST_IN_DOCKER=true`,
`CLOUDSDK_CORE_DISABLE_PROMPTS=1`, `TERM=xterm`, and `PATH` starting with `/go/bin`, `/usr/local/go/bin` and
`/google-cloud-sdk/bin`. It does not set upstream's `TENV_AUTO_INSTALL`, because it does not ship tenv.

## Common kubekins-e2e use cases

### Run a command through runner.sh

runner.sh passes the arguments through and exits with the command's status. It also prints its own setup messages on
stderr, which this example discards:

```bash
$ docker run --rm dhi.io/kubekins-e2e:<tag> sh -c 'exit 7' 2>/dev/null; echo $?
7
```

### Build Go code

The Go toolchain builds with cgo on or off:

```bash
$ docker run --rm -v "$PWD:/workspace/src" -w /workspace/src dhi.io/kubekins-e2e:<tag> go build ./...
```

The runtime tags run as uid 65532, so the mounted directory must be writable by that user. `/workspace`, `/go` and the
user's home directory are writable by uid 65532.

To build as your own uid and gid, give Go writable build and module cache directories:

```bash
$ docker run --rm --user "$(id -u):$(id -g)" \
  -e GOCACHE=/tmp/go-build -e GOPATH=/tmp/go \
  -v "$PWD:/workspace/src" -w /workspace/src \
  dhi.io/kubekins-e2e:<tag> go build ./...
```

### Use the Docker CLI with the host's Docker Engine

Mount the socket and add its group, since the runtime tags do not run as root:

```bash
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  dhi.io/kubekins-e2e:<tag> docker version
```

### Helm test image of the AWS EBS CSI driver chart

The `aws-ebs-csi-driver` chart runs this image as its Helm test pod (`helm test`), named by the chart value
`helmTester.image`. Set it to `dhi.io/kubekins-e2e:<tag>`.

The test pod sets no `securityContext`, so it runs as the image's user: uid 65532 on the runtime tags, root upstream. It
writes only to `/workspace` and its home directory, which uid 65532 can write.

### Pick a tag

Tags are dates: `2026.10.29` is the day upstream last changed the image's source (the `images/kubekins-e2e-v2` directory
of `kubernetes/test-infra`), not a build day. Upstream tags read `v<build date>-<commit>-<variant>` and are rebuilt
every Monday from the same source, so an upstream tag maps to the newest DHI date at or before the date in it:
`v20261116-33c2327245-master` and `v20261029-cd3d638333-master` both map to `2026.10.29`, and
`v20261116-33c2327245-1.37` maps to `2026.10.29-1.37`. Upstream's `latest-<variant>` has no exact counterpart; the year
tag (`2026`, `2026-1.37`) is the closest.

The DHI tag changes only when upstream's source changes. In between, the same tag is rebuilt when an included package
(kubectl, Go, Docker, the cloud CLIs) gets an update, and gets a new digest. To follow every rebuild, pin the image by
digest and let your update tool move the digest.

The variants of upstream are flavors here: `master` is the tag without a flavor, and `1.37`, `1.36` and `1.35` select
the kubectl and Go lines of those Kubernetes release branches.

## Non-hardened images vs. Docker Hardened Images

| Upstream                                                                 | This image                                                                                                   |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Runs as root                                                             | Runtime tags run as uid 65532; `-dev` tags run as root                                                       |
| Docker-in-Docker needs only the variable and a privileged container      | Runtime tags also need `--user 0`                                                                            |
| `apt` installed                                                          | Only on `-dev` tags                                                                                          |
| `build-essential`, the zlib headers and `pkg-config` installed           | Not shipped; install them on a `-dev` tag with `apt-get install` or `apk add`                                |
| `yq`, `uv`, `uvx`, `tenv` and its tools, `file`, `bc`, `ping`            | Not shipped; install them on a `-dev` tag (Alpine tags have `bc` and `ping` from BusyBox)                    |
| setuptools and wheel installed                                           | setuptools not shipped, wheel only on Debian tags; run `pip install setuptools wheel` when a job needs them  |
| PyYAML (`python3-yaml`) installed                                        | Not shipped; run `pip install pyyaml` when a job needs it                                                    |
| `graphviz` installed                                                     | Only on Alpine tags                                                                                          |
| Release variants with Docker 28 and a kubectl release candidate          | Docker 29 and the newest stable kubectl of the line                                                          |
| `linux/ppc64le` and `linux/s390x` images                                 | `linux/amd64` and `linux/arm64` only                                                                         |
| kubetest2 and kops helper binaries in `/go/bin`                          | In `/usr/bin`, on `PATH`; `/go/bin/kubetest2` does not exist                                                 |
| `IMAGE` environment variable naming upstream's own build                 | Not set                                                                                                      |
| `GOTOOLCHAIN` unset, so Go downloads a newer toolchain a module asks for | `GOTOOLCHAIN=local` (not on FIPS tags): Go uses the installed toolchain; set `GOTOOLCHAIN=auto` to download  |
| `GODEBUG` unset                                                          | `GODEBUG=tarinsecurepath=0,zipinsecurepath=0`: Go programs reject archive paths outside the target directory |
| Mercurial (`hg`)                                                         | Not shipped                                                                                                  |
| `/google-cloud-sdk/bin/gcloud-crc32c`                                    | Not shipped                                                                                                  |
| `/workspace/gcloud-info.txt`                                             | Not shipped                                                                                                  |
| Tools under `/usr/local/bin`, `/usr/local/go` and `/google-cloud-sdk`    | Installed under `/usr`, with links at upstream's paths                                                       |
| `python3-venv` installed                                                 | `python3 -m venv` works without it                                                                           |
| gcloud runs on its bundled Python 3.14                                   | gcloud runs on the image's Python 3.13                                                                       |
| Tags `v<date>-<commit>-<variant>` and `latest-<variant>`                 | Date tags, with the variant as a flavor (see Pick a tag)                                                     |
| Variant `1.34`                                                           | Not shipped: Kubernetes 1.34 reached end of life on 2026-10-27                                               |

The Alpine tags do not include the AWS CLI. On Alpine the Google Cloud CLI needs Python 3.13, and the only Alpine build
of the AWS CLI needs Python 3.14; the two Python versions cannot be installed together. Use a Debian tag when a job
needs the AWS CLI.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **kubekins-e2e is an exception:** its runtime variants include bash, because the entrypoint is a bash script and test
  jobs run shell commands, and they include `dpkg` on Debian, whose `start-stop-daemon` starts Docker Engine. They
  include no `apt` or `apk`.

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

  In this image, the Go tools (kubetest2, the kops helpers, kind, kubectl, helm, gh, cfssl and gke-gcloud-auth-plugin)
  are FIPS builds of the Go toolchain, and curl, gcloud through the image's Python, and the AWS CLI (Debian) use the
  OpenSSL FIPS provider. **kubekins-e2e is an exception:** some components have no FIPS build and are outside the FIPS
  boundary on every tag:

  | Component                                     | Crypto               | FIPS variants     |
  | --------------------------------------------- | -------------------- | ----------------- |
  | Docker Engine, containerd, Docker CLI, buildx | Go, not a FIPS build | Shipped unchanged |
  | wget (Debian)                                 | GnuTLS               | Shipped unchanged |

  The FIPS tags also set `GOFIPS140=v1.0.0` for the Go toolchain and leave `GOTOOLCHAIN` unset.

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
