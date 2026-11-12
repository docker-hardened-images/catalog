## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Netdata Hardened image

Netdata is a real-time, distributed monitoring and troubleshooting platform. It collects thousands of metrics per second
from systems, containers, and applications, and exposes them through a built-in dashboard and HTTP API on port 19999.

This Docker Hardened Netdata image includes:

- `netdata` (the main daemon binary at `/usr/sbin/netdata`)
- The full set of bundled collector plugins under `/usr/libexec/netdata/plugins.d/`, including `apps.plugin`
  (per-process metrics), `go.d.plugin` (modern Go-based collectors), `python.d.plugin`, `perf.plugin`,
  `systemd-journal.plugin`, `systemd-units.plugin`, `debugfs.plugin`, `network-viewer.plugin`, `local-listeners`, and
  several shell-script helpers
- Python 3.13 runtime at `/opt/python/` for the `python.d` collectors
- `bash` and `/bin/sh` (required by Netdata's shell-script collector helpers)
- The default Netdata configuration tree at `/etc/netdata/`, with subdirs for `go.d`, `python.d`, `charts.d`,
  `health.d`, `ssl`, and `statsd.d`

The image's ENTRYPOINT is `/usr/sbin/netdata` and the default CMD is `-D`, which runs the daemon in the foreground. The
image declares `19999/tcp` as the exposed port (dashboard + API).

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Start a Netdata container

To start a single Netdata container with the dashboard exposed on port 19999:

```bash
$ docker run -d --name netdata \
    -p 19999:19999 \
    --cap-add SYS_PTRACE \
    --security-opt apparmor=unconfined \
    dhi.io/netdata:<tag>
```

After a few seconds, open the dashboard in a browser at `http://localhost:19999/` or query the JSON API:

```bash
$ curl http://localhost:19999/api/v1/info
```

This basic command produces container-scoped metrics (CPU, memory, disk, network as the container sees them). To monitor
the host system instead, see [Monitor the host system](#monitor-the-host-system) below.

Two flags in the command above warrant explanation:

- `--cap-add SYS_PTRACE` — Netdata's `apps.plugin` reads `/proc/<pid>/stat` and friends for processes owned by other
  users, which requires `PTRACE_MODE_READ` privileges. Without it, `apps.plugin` cannot collect per-process metrics.
- `--security-opt apparmor=unconfined` — required on Linux hosts where AppArmor profiles restrict the read patterns
  `apps.plugin` and other Netdata collectors use. The flag is a no-op on systems without AppArmor (such as Docker
  Desktop for Mac), but harmless to include.

### Common Netdata use cases

#### Monitor the host system

To gather metrics about the host (not just the container), mount the host's `/proc`, `/sys`, and Docker socket into the
container:

```bash
$ docker run -d --name netdata \
    -p 19999:19999 \
    --cap-add SYS_PTRACE \
    --security-opt apparmor=unconfined \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    dhi.io/netdata:<tag>
```

#### Persist data across container restarts

Netdata stores its registry (instance UID, alert state, claim info) in `/var/lib/netdata`, its cache in
`/var/cache/netdata`, and its configuration in `/etc/netdata`. To persist these across container restarts:

```bash
$ docker run -d --name netdata \
    -p 19999:19999 \
    --cap-add SYS_PTRACE \
    --security-opt apparmor=unconfined \
    -v netdata-config:/etc/netdata \
    -v netdata-lib:/var/lib/netdata \
    -v netdata-cache:/var/cache/netdata \
    dhi.io/netdata:<tag>
```

The first-run startup logs include several `errno=2, No such file or directory` notices for files like
`cloud.d/cloud.conf`, `netdata.public.unique.id`, and `health.silencers.json` — these are normal and Netdata creates
them on first run. After a container restart, the same instance UID is preserved.

#### Run with Docker Compose

```yaml
services:
  netdata:
    image: dhi.io/netdata:<tag>
    container_name: netdata
    ports:
      - "19999:19999"
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor=unconfined
    volumes:
      - netdata-config:/etc/netdata
      - netdata-lib:/var/lib/netdata
      - netdata-cache:/var/cache/netdata
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped

volumes:
  netdata-config:
  netdata-lib:
  netdata-cache:
```

Start with `docker compose up -d`. The same Docker Desktop caveat applies to the `/proc` and `/sys` mounts.

#### Deploy as a Kubernetes DaemonSet

For Kubernetes, Netdata is typically deployed as a `DaemonSet` so one pod runs per node. The `imagePullSecrets` field
references a pull secret you must create first for `dhi.io` — see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: netdata
  labels:
    app: netdata
spec:
  selector:
    matchLabels:
      app: netdata
  template:
    metadata:
      labels:
        app: netdata
    spec:
      hostPID: true
      imagePullSecrets:
        - name: helm-pull-secret
      containers:
        - name: netdata
          image: dhi.io/netdata:<tag>
          ports:
            - name: dashboard
              containerPort: 19999
              hostPort: 19999
          securityContext:
            capabilities:
              add:
                - SYS_PTRACE
          volumeMounts:
            - name: proc
              mountPath: /host/proc
              readOnly: true
            - name: sys
              mountPath: /host/sys
              readOnly: true
            - name: docker-sock
              mountPath: /var/run/docker.sock
              readOnly: true
      volumes:
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: docker-sock
          hostPath:
            path: /var/run/docker.sock
```

Each pod exposes the dashboard on `hostPort: 19999`. To collect metrics from all nodes centrally, configure Netdata
Cloud or set up Netdata's parent/child streaming via the `stream.conf` configuration file.

### Non-hardened images vs Docker Hardened Images

#### Key differences

| Feature         | Docker Official Netdata          | Docker Hardened Netdata                                   |
| --------------- | -------------------------------- | --------------------------------------------------------- |
| Security        | Standard Debian base             | Minimal, hardened Debian 13 base                          |
| Shell access    | Full shell available             | Bash and `/bin/sh` included (required by Netdata helpers) |
| Package manager | `apt`, `apt-get`, `dpkg` present | No package manager                                        |
| User            | Runs as root (`USER` unset)      | Runs as `netdata` user (UID 999)                          |
| Image size      | ~1.1 GB                          | ~655 MB                                                   |
| Attack surface  | Larger due to apt toolchain      | Reduced — no package manager, runs as nonroot             |
| Debugging       | Traditional shell debugging      | Use Docker Debug or Image Mount for troubleshooting       |
| Compliance      | None                             | CIS                                                       |
| Attestations    | None                             | SBOM, provenance, VEX metadata                            |

These are not generic claims — they reflect direct inspection of the upstream `netdata/netdata:latest` image and
`dhi.io/netdata:2-debian13`. The DHI variant runs as a nonroot user, ships without `apt`/`apt-get`/`dpkg`, and is
approximately 40% smaller.

#### Why bash is present

Unlike most Docker Hardened Images, the Netdata image includes bash and `/bin/sh`. This is a functional requirement:
Netdata ships several shell-script helpers (`alarm-notify.sh`, `cgroup-name.sh`, `system-info.sh`, `tc-qos-helper.sh`,
`get-kubernetes-labels.sh`) that the daemon invokes for specific collectors and notification integrations. Removing the
shell would break these collectors.

The image still removes other typical attack-surface tooling — there is no package manager (`apt`, `apk`, `dpkg`), no
`nc` (netcat), no `curl`, and no editors. For interactive debugging, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/):

```bash
$ docker debug netdata
```

For operational visibility, the Netdata dashboard itself and `/api/v1/info` already report most of what you need.

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the `netdata` user (UID 999)
- Do not include a package manager
- Contain only Netdata, its plugins, the Python 3 runtime, and the minimal set of libraries needed to run

Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell (`bash`) and a package manager (`apt`)
- Are used to build or compile applications, or to install additional Python or Go collectors alongside Netdata

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

### Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or runtime configuration. At
minimum, you must update the base image to a Docker Hardened Image. This and a few other common changes are listed in
the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                    |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/netdata:<tag>`.                                                                                                                                                              |
| Package management | The runtime image doesn't contain a package manager. To install additional Python collectors or other Netdata plugins, build your own image `FROM dhi.io/netdata:<tag>-dev` and use `apt-get` in the build stage. |
| Non-root user      | The image runs as UID 999 (`netdata`), not the typical DHI UID 65532. Ensure that any mounted config, data, or cache directories are writable by UID 999. With named Docker volumes this works automatically.     |
| Capabilities       | Netdata's `apps.plugin` requires `SYS_PTRACE` to collect per-process metrics. Pass `--cap-add SYS_PTRACE` (docker run) or `securityContext.capabilities.add: [SYS_PTRACE]` (Kubernetes).                          |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                |
| Ports              | The image listens on port 19999 (dashboard + API). The default is above 1024 and unaffected by the privileged-port restriction.                                                                                   |
| Entry point        | The entrypoint is `/usr/sbin/netdata` with default CMD `-D` (foreground). To pass additional Netdata flags, append them to the docker run command after the image reference.                                      |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in `imagePullSecrets`.                                                                                                             |

### Troubleshoot migration

The following are common issues that you may encounter during migration.

#### General debugging

The hardened image includes bash and `/bin/sh` (required for Netdata's helper scripts) but does not include the typical
Linux debugging toolchain (no `nc`, `curl`, `tcpdump`, `ps`, etc.). For deeper inspection, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/):

```bash
$ docker debug netdata
```

Most operational debugging for Netdata is done through the dashboard itself, the `/api/v1/info` endpoint, and the
container's stdout logs. Plugin-level warnings such as "exited with error code 1 and haven't collected any data.
Disabling it" usually indicate a missing host mount or capability rather than a hardening issue.

#### Permissions

The image runs as UID 999 (`netdata`). Volumes mounted to `/etc/netdata`, `/var/lib/netdata`, and `/var/cache/netdata`
must be writable by this UID. When using named Docker volumes, this works automatically. When using bind mounts on the
host, ensure the host directory is owned by UID 999 (or world-writable for testing).

#### Privileged ports

The image runs as nonroot, so the daemon cannot bind to ports below 1024. The default port 19999 is unaffected. If you
override the dashboard port in `netdata.conf`, use a value above 1024.

#### Entry point

The image's default ENTRYPOINT is `/usr/sbin/netdata` and CMD is `-D` (foreground). To run other commands (such as
`--help`), override the entrypoint or append flags:

```bash
$ docker run --rm dhi.io/netdata:<tag> -V
$ docker run --rm dhi.io/netdata:<tag> -h
```

Use `docker inspect` to view the entrypoint and default CMD for a specific tag.
