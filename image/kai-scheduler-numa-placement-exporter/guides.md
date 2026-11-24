## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kai-scheduler-numa-placement-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-kai-scheduler-numa-placement-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kai-scheduler-numa-placement-exporter image

The NUMA placement exporter is the per-node agent of [KAI Scheduler](https://github.com/kai-scheduler/KAI-Scheduler). It
runs as a DaemonSet, reads the kubelet podresources socket and the node's sysfs CPU map, and writes the NUMA node each
pod's exclusive CPUs landed on into the pod annotation `kai.scheduler/numa-placement-observed`. KAI's NUMA plugin reads
that annotation. The exporter opens no ports and logs to stderr.

Use the tag line of your KAI Scheduler release: `0.19` for KAI v0.19.x, `0.18` for v0.18.x, and `0.16` for v0.16.x.

- Debian 13 tags: `0.19`, `0.19.0` and `0.19.0-debian13`. Only the 0.19 line also publishes `0`.
- Alpine 3.24 tags: `0.19-alpine3.24` and `0.19.0-alpine3.24`.
- Variants append `-dev`, `-fips` or `-fips-dev`, for example `0.19-fips` or `0.19.0-alpine3.24-fips-dev`.
- The Debian 13 tags also come in KAI's own tag form, such as `v0.19.0`, `v0.19.0-dev`, `v0.19.0-fips` and
  `v0.19.0-fips-dev` (and `v0.18.8`, `v0.16.18` for the other lines). These match the tag KAI's Helm chart resolves, so
  you can keep that tag and change only where the image comes from. Alpine tags have no `v` form.

Outside a cluster the exporter has nothing to read, so it only prints its flags:

```bash
$ docker run --rm dhi.io/kai-scheduler-numa-placement-exporter:<tag> --help
```

The flags you are most likely to need are `--podresources-socket` (default
`/var/lib/kubelet/pod-resources/kubelet.sock`), `--sysfs-root` (default `/sys`), and `--node-name`, which defaults to
the `NODE_NAME` environment variable. The exporter exits at startup if neither is set.

### Node prerequisites

The exporter only reports placement that the kubelet made. Pods get exclusive CPUs only when the kubelet runs the
`static` CPU Manager policy (`cpuManagerPolicy: static`, with some CPUs reserved for the system), and only Guaranteed
pods with integer CPU requests receive them. On a node without the static policy, or for Burstable and BestEffort pods,
there is nothing to observe and the exporter writes no `kai.scheduler/numa-placement-observed` annotation. KAI's
[NUMA guide](https://github.com/kai-scheduler/KAI-Scheduler/blob/v0.19.0/docs/numa/README.md) covers the full kubelet
setup.

## Common kai-scheduler-numa-placement-exporter use cases

### Use the hardened image with KAI Scheduler

KAI's operator creates the `numa-placement-exporter` DaemonSet from the cluster `Config` named `kai-config`, which the
Helm chart writes. The chart builds the image as `<global.registry>/numa-placement-exporter:<tag>` and has no registry
setting for this component alone, so point the exporter at the hardened image in `kai-config` itself:

```bash
$ kubectl create namespace kai-scheduler
$ kubectl -n kai-scheduler create secret docker-registry dhi-pull \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<access-token>
$ helm upgrade -i kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  -n kai-scheduler --version v0.19.0 \
  --set 'global.imagePullSecrets[0].name=dhi-pull' \
  --set numaPlacementExporter.enabled=true
$ kubectl patch configs.kai.scheduler kai-config --type merge \
  -p '{"spec":{"numaPlacementExporter":{"service":{"image":{"repository":"dhi.io","name":"kai-scheduler-numa-placement-exporter"}}}}}'
```

The patch keeps the tag the chart resolved, `v0.19.0`, which the Debian 13 image publishes. Check the image the operator
rolled out:

```bash
$ kubectl -n kai-scheduler rollout status daemonset numa-placement-exporter
$ kubectl -n kai-scheduler get daemonset numa-placement-exporter \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
dhi.io/kai-scheduler-numa-placement-exporter:v0.19.0
```

- The chart's post-install and post-upgrade hook re-applies `kai-config` from the chart values, which resets the image
  to the upstream one. Run the `kubectl patch` again after every `helm upgrade`.
- `numaPlacementExporter.enabled=true` deploys the exporter right away. Without it, the operator deploys the exporter
  once a `SchedulingShard` enables the `numa` plugin. Either way, the DaemonSet runs only on nodes labelled
  `feature.node.kubernetes.io/memory-numa=true` (set by Node Feature Discovery). The chart value
  `numaPlacementExporter.nodeSelector` replaces that label.
- For the other lines, use `--version v0.18.8` or `--version v0.16.18`. The values and the patch are the same.
- For FIPS, add `--set global.fipsMode=on` on 0.19 and 0.18, or `--set global.fips=true` on 0.16. The chart then
  resolves the `-fips` tag, such as `v0.19.0-fips`, which the Debian 13 FIPS image publishes. `global.fipsMode=only`
  also sets `GODEBUG=fips140=only,tlsmlkem=0`, and the FIPS image works with it.
- For the Alpine image, also set the tag in the patch, because Alpine has no `v` tags:

```bash
$ kubectl patch configs.kai.scheduler kai-config --type merge \
  -p '{"spec":{"numaPlacementExporter":{"service":{"image":{"repository":"dhi.io","name":"kai-scheduler-numa-placement-exporter","tag":"0.19.0-alpine3.24"}}}}}'
```

From a mirrored repository, set `repository` to `docker.io/<your-namespace>` and `name` to
`dhi-kai-scheduler-numa-placement-exporter`, and make the pull secret's server `docker.io`.

### Run the exporter without the KAI operator

This DaemonSet matches the one KAI's operator creates. Save it as `numa-placement-exporter.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: numa-placement-exporter
  namespace: numa-placement-exporter
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: numa-placement-exporter
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "patch", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: numa-placement-exporter
subjects:
  - kind: ServiceAccount
    name: numa-placement-exporter
    namespace: numa-placement-exporter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: numa-placement-exporter
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: numa-placement-exporter
  namespace: numa-placement-exporter
spec:
  selector:
    matchLabels:
      app: numa-placement-exporter
  template:
    metadata:
      labels:
        app: numa-placement-exporter
    spec:
      serviceAccountName: numa-placement-exporter
      imagePullSecrets:
        - name: dhi-pull
      containers:
        - name: numa-placement-exporter
          image: dhi.io/kai-scheduler-numa-placement-exporter:0.19
          args:
            - --podresources-socket=/var/lib/kubelet/pod-resources/kubelet.sock
            - --sysfs-root=/host/sys
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          securityContext:
            runAsUser: 0
            runAsNonRoot: false
          volumeMounts:
            - name: podresources
              mountPath: /var/lib/kubelet/pod-resources
              readOnly: true
            - name: sysfs
              mountPath: /host/sys
              readOnly: true
      volumes:
        - name: podresources
          hostPath:
            path: /var/lib/kubelet/pod-resources
            type: Directory
        - name: sysfs
          hostPath:
            path: /sys
            type: Directory
```

- The container runs as root because the kubelet podresources socket and its directory are owned by root. The image's
  own default user can't connect to it.
- The host's `/sys` is mounted at `/host/sys`, not over the container's own `/sys`, and `--sysfs-root` points there.
- The ClusterRole above is the one for 0.19, which reads its own Node at startup and watches pods. For `0.18` and
  `0.16`, change the image tag and replace the ClusterRole `rules` with:

```yaml
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "patch"]
```

Deploy it:

```bash
$ kubectl create namespace numa-placement-exporter
$ kubectl -n numa-placement-exporter create secret docker-registry dhi-pull \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<access-token>
$ kubectl apply -f numa-placement-exporter.yaml
$ kubectl -n numa-placement-exporter rollout status daemonset numa-placement-exporter
```

### Check the observed placement

Start a Guaranteed pod with one whole CPU. Save it as `numa-demo.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: numa-demo
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      resources:
        requests:
          cpu: "1"
          memory: 64Mi
        limits:
          cpu: "1"
          memory: 64Mi
```

Within a few seconds of the pod starting, the exporter annotates it with the NUMA node and the number of CPUs it holds
there:

```bash
$ kubectl apply -f numa-demo.yaml
$ kubectl wait --for=condition=Ready pod/numa-demo
$ kubectl get pod numa-demo -o jsonpath='{.metadata.annotations.kai\.scheduler/numa-placement-observed}'
[{"zone":"node-0","amount":{"cpu":"1"}}]
```

The 0.19 line also writes `kai.scheduler/numa-memory-groups-observed` on every pod of its node, `[]` on pods that are
not Guaranteed. The 0.16 and 0.18 lines do not write it.

## Non-hardened images vs. Docker Hardened Images

- Entry point: both images run `/workspace/app`. In the hardened image, it is a link to
  `/usr/bin/numa-placement-exporter`, so a `command` that names either path starts the same binary.
- User: runtime and FIPS variants run as uid 65532 (`nonroot`), the same uid as the upstream image. The `dev` variants
  run as root. In Kubernetes, run every variant as root, as KAI's operator does. Otherwise the pod stays running,
  annotates nothing, and logs `dial unix /var/lib/kubelet/pod-resources/kubelet.sock: connect: permission denied`.
- License files: the upstream image ships `/workspace/NOTICE` (and `/workspace/COPYRIGHT` on 0.19). The hardened image
  keeps `LICENSE`, `NOTICE` and, on 0.19, `COPYRIGHT` in `/usr/share/licenses/kai-scheduler-numa-placement-exporter/`.
- Environment: the upstream image sets `TARGETARCH` and `SERVICE_NAME`, which the exporter never reads. The hardened
  image doesn't set them.
- FIPS: the FIPS variants build the exporter with the Go FIPS 140-3 module and FIPS mode on by default (`fips140=on`),
  the same as upstream's `-fips` images.
- Tags: the Debian 13 tags include KAI's `v` tag form, such as `v0.19.0` and `v0.19.0-fips`. The Alpine 3.24 tags do
  not.

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
