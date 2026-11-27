## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rancher-agent:<tag>`
- Mirrored image: `<your-namespace>/dhi-rancher-agent:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Rancher Agent image

Rancher Agent runs as the `cattle-cluster-agent` Deployment in the `cattle-system` namespace of every cluster Rancher
manages. Rancher generates that Deployment and its credentials when you import or create a cluster, so you don't start
the agent yourself. The agent connects back to the Rancher server, carries Rancher's API traffic to the cluster, and
installs Rancher's system charts there, such as `rancher-webhook`.

Rancher also runs the agent image for two short-lived workloads, which work unchanged with the hardened image:

- The `cattle-cleanup` Job, which Rancher creates in a downstream cluster when you delete it from Rancher. It runs as
  user 1000 with `CLUSTER_CLEANUP=true`, and `run.sh` hands it straight to the agent, which removes Rancher's
  namespaces, roles and webhooks.
- The `rke2-machineconfig-cleanup` CronJob in the Rancher cluster. It runs `/bin/sh /helper/cleanup.sh` as user 65534,
  and the script uses `kubectl`, `jq`, `grep`, `sort` and `xargs` from the image to delete machine configs that no
  cluster owns.

Rancher deploys the agent of its own version. Use the hardened tag of the same version, for example `2.15.4` for Rancher
v2.15.4. Tags exist for the 2.12, 2.13, 2.14 and 2.15 lines. The Debian-based tags also come in the upstream form, for
example `v2.15.4`. The Alpine-based tags, for example `2.15.4-alpine`, do not.

The entrypoint is the upstream `run.sh` script. On its own, without the variables Rancher sets, it stops with an error:

```bash
$ docker run --rm dhi.io/rancher-agent:2.15.4
WARN: Docker socket is not available!
WARN: Please bind mount in the docker socket to /var/run/docker.sock if docker errors occur
WARN: example:  docker run -v /var/run/docker.sock:/var/run/docker.sock ...
ERROR: -- --token is a required option
```

As upstream, `run.sh` runs any command given after `--` instead of the agent:

```bash
$ docker run --rm dhi.io/rancher-agent:2.15.4 -- kubectl version --client
INFO: Arguments: -- kubectl version --client
Client Version: v1.36.7
Kustomize Version: v5.8.1
```

## Common Rancher Agent use cases

The FIPS tags come only with a DHI Select or DHI Enterprise subscription, from a mirrored repository. For them, use
`<your-namespace>/dhi-rancher-agent` instead of `dhi.io/rancher-agent` in the setups below, with a FIPS tag such as
`2.15.4-fips`.

There are two ways to make Rancher deploy the hardened agent. With a private registry, copy the image to the path
Rancher already uses. Without one, point Rancher at the hardened image. Don't combine them: with a private registry set,
Rancher puts the registry in front of any agent image you name.

### Run the agent from a private registry

With a system default registry or a cluster private registry set, Rancher deploys the agent from
`<registry>/rancher/rancher-agent:v<rancher-version>`. Copy the hardened image of the same version to that path and tag
before Rancher installs or upgrades the agent. Rancher then pulls it with no other change.

On the cluster Rancher runs on, check the image Rancher deploys, before it adds the registry:

```bash
$ kubectl get settings.management.cattle.io agent-image -o jsonpath='{.value}'
rancher/rancher-agent:v2.15.4
```

Copy the hardened image into your registry, with every platform. Replace `<rancher-version>` with your Rancher version,
without the `v`, for example `2.15.4`:

```bash
$ docker buildx imagetools create \
  --tag <registry>/rancher/rancher-agent:v<rancher-version> \
  dhi.io/rancher-agent:<rancher-version>
```

Rancher deploys the agent with `imagePullPolicy: IfNotPresent`, so a node that already holds the upstream image under
that tag keeps running it.

### Point Rancher at the hardened image

Without a private registry, set the agent image in the Rancher chart. The Rancher server image sets
`CATTLE_AGENT_IMAGE`, which takes precedence over the `agent-image` setting, so editing the setting has no effect. Set
the variable through the chart's `extraEnv` value instead.

The Rancher Prime server image, `registry.rancher.com/rancher/rancher`, also sets
`CATTLE_BASE_REGISTRY=registry.rancher.com`. That makes `registry.rancher.com` the system default registry, so Rancher
puts it in front of the agent image and the pull fails. With that server image, also add an empty `CATTLE_BASE_REGISTRY`
to the `extraEnv` list below:

```yaml
  - name: CATTLE_BASE_REGISTRY
    value: ""
```

After the upgrade, this prints nothing:

```bash
$ kubectl get settings.management.cattle.io system-default-registry -o jsonpath='{.default}'
```

Rancher adds a pull secret to the agent only for a private registry, so every node must be able to pull the image on its
own. Use a mirror of the repository that your nodes can reach. Replace:

- `<rancher-version>` with the Rancher version you run, for example `2.15.4`, in both places.
- `<rancher-repo>` with the Helm repository you installed Rancher from.

```bash
$ cat > agent-values.yaml <<'EOF'
extraEnv:
  - name: CATTLE_AGENT_IMAGE
    value: <your-namespace>/dhi-rancher-agent:<rancher-version>
EOF
$ helm upgrade rancher <rancher-repo>/rancher --namespace cattle-system --version <rancher-version> \
  --reuse-values -f agent-values.yaml
```

The file replaces the whole `extraEnv` list, so add any entries you already set. The value pins the agent version: set
it to the new version in the same `helm upgrade` that upgrades Rancher.

Check that Rancher took the image:

```bash
$ kubectl get settings.management.cattle.io agent-image -o jsonpath='{.value}'
```

Rancher redeploys the agent of a cluster when the image changes. A cluster imported through
`clusters.provisioning.cattle.io` keeps the image Rancher chose when it was registered, in `spec.desiredAgentImage` of
its management cluster. To find the management cluster of an imported cluster and make it follow the new image, replace
`<cluster-name>` with its name and `<cluster-id>` with the ID the first command prints:

```bash
$ kubectl -n fleet-default get clusters.provisioning.cattle.io <cluster-name> -o jsonpath='{.status.clusterName}'
$ kubectl get clusters.management.cattle.io <cluster-id> -o jsonpath='{.spec.desiredAgentImage}'
$ kubectl patch clusters.management.cattle.io <cluster-id> --type merge -p '{"spec":{"desiredAgentImage":""}}'
```

On the downstream cluster, check that the agent runs the hardened image:

```bash
$ kubectl -n cattle-system rollout status deployment cattle-cluster-agent
$ kubectl -n cattle-system get deployment cattle-cluster-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Air-gapped clusters: mirror the chart repositories

The upstream image bundles a copy of Rancher's three chart repositories and falls back to it when it can't reach them.
The hardened image doesn't, so the agent clones them from their URLs. A cluster that can't reach them can't install
Rancher's system charts, `rancher-webhook` among them. Mirror the repositories to a Git server the cluster can reach,
and give the agent their URLs.

| ClusterRepo              | Upstream repository                     | Branch               | Variable                           |
| ------------------------ | --------------------------------------- | -------------------- | ---------------------------------- |
| `rancher-charts`         | `https://git.rancher.io/charts`         | `release-v2.<minor>` | `CATTLE_CHART_DEFAULT_URL`         |
| `rancher-partner-charts` | `https://git.rancher.io/partner-charts` | `main`               | `CATTLE_PARTNER_CHART_DEFAULT_URL` |
| `rancher-rke2-charts`    | `https://git.rancher.io/rke2-charts`    | `main`               | `CATTLE_RKE2_CHART_DEFAULT_URL`    |

Rancher adds `rancher-rke2-charts` only when its `rke2` feature is on. The `rancher-charts` branch follows the Rancher
minor version, for example `release-v2.15` for Rancher 2.15. Mirror the new branch too when you upgrade to a new minor.

From a machine with internet access, clone each branch and push it to your Git server. Replace `<git-server>` with its
address. Rancher clones with `--depth=1`, so the server must speak Git's smart HTTP protocol. A static file server
doesn't work.

```bash
$ git clone --bare --single-branch --branch release-v2.15 https://git.rancher.io/charts charts.git
$ git clone --bare --single-branch --branch main https://git.rancher.io/partner-charts partner-charts.git
$ git clone --bare --single-branch --branch main https://git.rancher.io/rke2-charts rke2-charts.git
$ git -C charts.git push https://<git-server>/rancher/charts.git release-v2.15
$ git -C partner-charts.git push https://<git-server>/rancher/partner-charts.git main
$ git -C rke2-charts.git push https://<git-server>/rancher/rke2-charts.git main
```

To update the mirror, fetch each branch and push it again, for example:

```bash
$ git -C charts.git fetch origin release-v2.15:release-v2.15
$ git -C charts.git push https://<git-server>/rancher/charts.git release-v2.15
```

Each variable takes the full URL of one repository. Set them as agent environment variables of each cluster. For a new
imported cluster, add them to its Cluster resource:

```bash
$ cat > cluster.yaml <<'EOF'
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: <cluster-name>
  namespace: fleet-default
spec:
  agentEnvVars:
    - name: CATTLE_CHART_DEFAULT_URL
      value: https://<git-server>/rancher/charts.git
    - name: CATTLE_PARTNER_CHART_DEFAULT_URL
      value: https://<git-server>/rancher/partner-charts.git
    - name: CATTLE_RKE2_CHART_DEFAULT_URL
      value: https://<git-server>/rancher/rke2-charts.git
EOF
$ kubectl apply -f cluster.yaml
```

After registration, the management cluster holds the agent environment variables of an imported cluster. For a cluster
that's already imported, patch its management cluster, with the `<cluster-id>` found as in
[Point Rancher at the hardened image](#point-rancher-at-the-hardened-image). The patch replaces the whole list, so add
any variables you already set:

```bash
$ kubectl patch clusters.management.cattle.io <cluster-id> --type merge -p '{"spec":{"agentEnvVars":[
  {"name":"CATTLE_CHART_DEFAULT_URL","value":"https://<git-server>/rancher/charts.git"},
  {"name":"CATTLE_PARTNER_CHART_DEFAULT_URL","value":"https://<git-server>/rancher/partner-charts.git"},
  {"name":"CATTLE_RKE2_CHART_DEFAULT_URL","value":"https://<git-server>/rancher/rke2-charts.git"}]}}'
```

Rancher redeploys the agent with the new variables. On the downstream cluster, check that `rancher-charts` comes from
your mirror and has a commit:

```bash
$ kubectl get clusterrepos.catalog.cattle.io rancher-charts -o jsonpath='{.spec.gitRepo}{" "}{.status.commit}'
```

## Non-hardened images vs. Docker Hardened Images

- User: like upstream, every variant of the hardened image runs as root. The agent reads its credentials from a mount
  that only root can read, `run.sh` writes Rancher's CA certificate under `/etc/kubernetes/ssl/certs`, and the agent
  listens on ports 80 and 443.
- Shell: runtime variants of the hardened image ship `bash`, because `run.sh` is a Bash script, along with the `git`,
  `curl`, `jq`, `openssl` and `kubectl` that the agent and `run.sh` call.
- Chart repositories: the upstream image bundles `rancher-charts`, `rancher-partner-charts` and `rancher-rke2-charts`
  under `/var/lib/rancher-data/local-catalogs/v2`. The hardened image doesn't, and the `bundled` value of the
  `system-catalog` setting has nothing to use. Air-gapped clusters need a mirror, as in
  [Air-gapped clusters: mirror the chart repositories](#air-gapped-clusters-mirror-the-chart-repositories).
- Troubleshooting tools: the upstream image includes tools such as `dig`, `xz`, `getfacl`, `vim`, `sar`, `less` and Bash
  completion. Runtime variants of the hardened image leave them out, except that the Alpine-based ones have `less` from
  busybox. The `dev` variants add `dig`, `xz`, `getfacl`, `less` and a package manager to install others. Like upstream,
  every variant includes `ssh`, which `git` runs for `ssh://` chart repositories, and `tar` and `gzip`, which
  `kubectl cp` runs in the agent container.
- Scripts: the upstream 2.12 and 2.13 images include `kubectl-shell.sh` and `shell-setup.sh`, which later Rancher
  releases dropped. The hardened images don't include them on any line.
- Tags: the Debian-based tags include the upstream tag form, such as `v2.15.4`, `v2.15.4-dev` and `v2.15.4-fips`. The
  Alpine-based tags do not.

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
