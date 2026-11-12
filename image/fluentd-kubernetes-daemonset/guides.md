## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Prerequisites

- A Kubernetes cluster and `kubectl`.
- A reachable log backend for your chosen destination (Elasticsearch, S3, Kafka, CloudWatch, etc.).
- Read access to the node log paths the DaemonSet tails (`/var/log` and the container runtime log dir). See
  [Running as the non-root user](#running-as-the-non-root-user).

## What's included in this image

This image is the Kubernetes DaemonSet build of Fluentd. It tails container and node logs, enriches each record with
Kubernetes metadata, and forwards records to a single output destination. The destination is encoded in the tag
**flavor**:

| Tag flavor                                                                                | Output                 |
| ----------------------------------------------------------------------------------------- | ---------------------- |
| `elasticsearch7`, `elasticsearch8`                                                        | Elasticsearch          |
| `opensearch`                                                                              | OpenSearch             |
| `s3`                                                                                      | Amazon S3              |
| `cloudwatch`                                                                              | Amazon CloudWatch Logs |
| `kinesis`                                                                                 | Amazon Kinesis         |
| `kafka`, `kafka2`                                                                         | Apache Kafka           |
| `gcs`                                                                                     | Google Cloud Storage   |
| `azureblob`                                                                               | Azure Blob Storage     |
| `datadog`, `loggly`, `logzio`, `papertrail`, `graylog`, `logentries`, `syslog`, `forward` | Hosted/forward outputs |

For example, `dhi.io/fluentd-kubernetes-daemonset:1.19-elasticsearch8` ships to Elasticsearch 8. Every flavor includes
the shared Kubernetes plugins (metadata filter, systemd, Prometheus, concat, grok, multi-format parser) plus the output
plugin for that destination.

Configuration lives in `/etc/fluent` (`fluent.conf` includes `systemd.conf`, `prometheus.conf`, `kubernetes.conf`, and
`conf.d/*.conf`). The custom parsers are in `/etc/fluent/plugins`. The runtime listens on `24231/tcp` for Prometheus
metrics.

## Deploy as a DaemonSet

The image runs as the non-root `nonroot` user (uid `65532`) and reads its destination settings from environment
variables. A minimal Elasticsearch DaemonSet:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: fluentd, namespace: kube-system }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: { name: fluentd }
rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: fluentd }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: fluentd }
subjects:
  - { kind: ServiceAccount, name: fluentd, namespace: kube-system }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels: { app: fluentd }
  template:
    metadata:
      labels: { app: fluentd }
    spec:
      serviceAccountName: fluentd
      securityContext:
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
      containers:
        - name: fluentd
          image: dhi.io/fluentd-kubernetes-daemonset:1.19-elasticsearch8
          env:
            - { name: FLUENT_ELASTICSEARCH_HOST, value: elasticsearch.logging.svc }
            - { name: FLUENT_ELASTICSEARCH_PORT, value: "9200" }
            - { name: FLUENT_ELASTICSEARCH_SCHEME, value: https }
          ports:
            - { name: metrics, containerPort: 24231 }
          volumeMounts:
            - { name: varlog, mountPath: /var/log, readOnly: true }
            - { name: varlibdockercontainers, mountPath: /var/lib/docker/containers, readOnly: true }
            - { name: state, mountPath: /fluentd/log }
      volumes:
        - { name: varlog, hostPath: { path: /var/log } }
        - { name: varlibdockercontainers, hostPath: { path: /var/lib/docker/containers } }
        - { name: state, emptyDir: {} }
```

The `ServiceAccount` + `ClusterRole` above give the Kubernetes metadata filter the `get`/`list`/`watch` access to pods
and namespaces it needs; the API connection uses the in-cluster credentials automatically
(`KUBERNETES_SERVICE_HOST`/`KUBERNETES_SERVICE_PORT` are injected by Kubernetes). To also collect logs from
control-plane nodes, add a `tolerations` block to the pod spec that tolerates the control-plane taints.

The default config also enables the `systemd` input (journald). If you are not collecting node journald logs, set
`FLUENTD_SYSTEMD_CONF=disable` to silence the "No such file or directory" warnings; to collect them, mount the host
journal (e.g. `/var/log/journal` or `/run/log/journal`) read-only and add the `systemd-journal` group via
`securityContext.supplementalGroups`.

### Running as the non-root user

Upstream `fluent/fluentd-kubernetes-daemonset` runs as root so it can both read host logs and write its state files
under `/var/log`. This image runs as `nonroot` (uid `65532`) and does not add a `-root` or `-compat` flavor, so a
deployment must arrange two things:

- **Read access to the node logs.** The collector tails `/var/log/containers/*.log` (symlinks into the container runtime
  log dir). Mount host `/var/log` and `/var/lib/docker/containers` (or the containerd equivalent) **read-only**. On most
  distributions these files are group-readable; if your nodes make them root-only, add the owning group via
  `securityContext.supplementalGroups` (note: `fsGroup` does **not** apply to `hostPath` volumes). Confirm with
  `ls -l /var/log/containers` inside the pod.
- **A writable state directory.** fluentd writes in_tail position files, journald cursors, and (for `s3`/`gcs`/`logzio`/
  `azureblob`) disk buffers to `/fluentd/log`. The image creates `/fluentd/log` owned by uid `65532`, so it starts out
  of the box, but that is container-ephemeral — mount a writable volume there (an `emptyDir` as above, or a per-node
  `hostPath` you own) so read positions and buffered events survive pod restarts. Do **not** point state back under the
  read-only `/var/log` mount.

This is the key difference from running upstream as root: writes go to `/fluentd/log`, not `/var/log`.

## Configure the destination

Each flavor reads `FLUENT_<DESTINATION>_*` environment variables (the same names upstream uses). Examples:

- Elasticsearch: `FLUENT_ELASTICSEARCH_HOST`, `FLUENT_ELASTICSEARCH_PORT`, `FLUENT_ELASTICSEARCH_SCHEME`,
  `FLUENT_ELASTICSEARCH_USER`, `FLUENT_ELASTICSEARCH_PASSWORD`.
- S3: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET_NAME`, `S3_BUCKET_REGION` (or an IRSA role).
- Kafka: `FLUENT_KAFKA_BROKERS`, plus the topic/format settings in `fluent.conf`. SASL PLAIN/SCRAM/OAUTHBEARER and
  GSSAPI/Kerberos are supported (for GSSAPI, mount your `krb5.conf` and keytab).

To disable the systemd or Prometheus inputs, set `FLUENTD_SYSTEMD_CONF=disable` or `FLUENTD_PROMETHEUS_CONF=disable`.
Add your own snippets by mounting files into `/etc/fluent/conf.d/`.

## Add plugins with the dev variant

The runtime image ships only the plugins for its flavor. To add another plugin, build on the `-dev` variant, which
includes the Ruby build toolchain needed for gems with native extensions:

```dockerfile
FROM dhi.io/fluentd-kubernetes-daemonset:1.19-elasticsearch8-dev
RUN gem install --no-document fluent-plugin-<name>
```

## Migration notes

- **Config and state paths.** Configuration lives under `/etc/fluent` (not upstream's `/fluentd/etc`); custom plugins go
  in `/etc/fluent/plugins` and config snippets in `/etc/fluent/conf.d`; `GEM_HOME` is `/usr/local/bundle`. State files
  (position files, journald cursors, disk buffers) are written to `/fluentd/log`, not `/var/log` — see
  [Running as the non-root user](#running-as-the-non-root-user). Environment-driven configuration (the `FLUENT_*`
  variables) is unchanged.
- **Plugin load errors.** `uninitialized constant` usually means the plugin isn't shipped in this flavor; add it on the
  `-dev` variant. The Elasticsearch/OpenSearch simple sniffer is registered automatically by the entrypoint.
- **Debugging on Kubernetes.** The runtime keeps bash only for the entrypoint; there is no package manager and most
  inspection tools are absent. Use
  `kubectl debug -it <pod> --image=dhi.io/fluentd-kubernetes-daemonset:1.19-<flavor>-dev` for an ephemeral debug
  container, or Docker Debug outside Kubernetes.
- **jemalloc.** jemalloc is built in but **not** preloaded by default, matching upstream's daemonset (the systemd input
  plugin + jemalloc combination has a known crash bug). Opt in by setting
  `LD_PRELOAD=/usr/lib/libjemalloc/libjemalloc.so.2`.
- **logentries.** Upstream comments its plugin out of the Gemfile; this image ships a working `logentries` flavor with
  `fluent-plugin-logentries`, but that plugin is unmaintained upstream (treat it as best-effort).
- **Parquet on S3.** The optional `columnify` helper (used only for `store_as parquet`) is not bundled; the default
  gzip/text/json store formats work out of the box. Add `columnify` on the dev variant if you need Parquet output.

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
