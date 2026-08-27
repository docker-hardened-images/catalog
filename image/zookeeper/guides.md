## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Zookeeper Hardened image

Apache ZooKeeper is a centralized service for maintaining configuration information, naming, distributed
synchronization, and group services. It is widely used as the coordination backbone for distributed systems such as
Apache Kafka, Apache Hadoop, and Apache Solr.

This Docker Hardened ZooKeeper image includes:

- `zkServer.sh`, `zkCli.sh`, and the rest of the standard ZooKeeper distribution under `/opt/zookeeper`
- A bundled OpenJDK 23 JRE (Eclipse Temurin) at `/opt/java/openjdk/23-jre`
- `entrypoint.sh` wrapper script at `/opt/zookeeper/bin/entrypoint.sh` that translates `ZOO_*` environment variables
  into the ZooKeeper config file
- `bash` and `/bin/sh` (required to run the ZooKeeper distribution's shell-script wrappers)

The image's ENTRYPOINT is `entrypoint.sh` (on PATH) and the default CMD is `zkServer.sh start-foreground`, so
`docker run dhi.io/zookeeper:<tag>` starts a standalone server with no additional configuration.

The image does not declare any ports via `EXPOSE`, but ZooKeeper itself listens on:

- `2181` — client port
- `8080` — AdminServer HTTP endpoint (enabled by default via `ZOO_ADMINSERVER_ENABLED=true`)
- `2888`, `3888` — peer follower and leader-election ports (only in ensemble mode)

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Start a ZooKeeper instance

To start a single-node ZooKeeper instance in standalone mode, run:

```bash
$ docker run -d --name zookeeper -p 2181:2181 dhi.io/zookeeper:<tag>
```

By default, the image starts the server in foreground mode (`zkServer.sh start-foreground`) with standalone mode
enabled. Data is stored under `/var/zookeeper/data` inside the container. To persist data across container restarts,
mount a volume:

```bash
$ docker run -d --name zookeeper -p 2181:2181 \
    -v zk-data:/var/zookeeper/data \
    -v zk-datalog:/var/zookeeper/datalog \
    dhi.io/zookeeper:<tag>
```

To check the server status from within the container:

```bash
$ docker exec zookeeper /opt/zookeeper/bin/zkServer.sh status
```

In standalone mode, this reports `Mode: standalone`.

To connect a client to the server, use the bundled `zkCli.sh`:

```bash
$ docker exec -it zookeeper /opt/zookeeper/bin/zkCli.sh -server localhost:2181
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper]
[zk: localhost:2181(CONNECTED) 1] quit
```

### Common ZooKeeper use cases

#### Run a 3-node ensemble with Docker Compose

For production-style deployments, ZooKeeper is run as an ensemble of 3 or 5 nodes. The following `docker-compose.yml`
starts a 3-node ensemble:

```yaml
services:
  zk1:
    image: dhi.io/zookeeper:<tag>
    container_name: zk1
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: "server.1=zk1:2888:3888;2181 server.2=zk2:2888:3888;2181 server.3=zk3:2888:3888;2181"
      ZOO_STANDALONE_ENABLED: "false"
      ZOO_INIT_LIMIT: 10
      ZOO_SYNC_LIMIT: 5
    networks:
      - zk-net

  zk2:
    image: dhi.io/zookeeper:<tag>
    container_name: zk2
    environment:
      ZOO_MY_ID: 2
      ZOO_SERVERS: "server.1=zk1:2888:3888;2181 server.2=zk2:2888:3888;2181 server.3=zk3:2888:3888;2181"
      ZOO_STANDALONE_ENABLED: "false"
      ZOO_INIT_LIMIT: 10
      ZOO_SYNC_LIMIT: 5
    networks:
      - zk-net

  zk3:
    image: dhi.io/zookeeper:<tag>
    container_name: zk3
    environment:
      ZOO_MY_ID: 3
      ZOO_SERVERS: "server.1=zk1:2888:3888;2181 server.2=zk2:2888:3888;2181 server.3=zk3:2888:3888;2181"
      ZOO_STANDALONE_ENABLED: "false"
      ZOO_INIT_LIMIT: 10
      ZOO_SYNC_LIMIT: 5
    networks:
      - zk-net

networks:
  zk-net:
```

Start the ensemble:

```bash
$ docker compose up -d
```

After approximately 10 seconds, leader election completes and the cluster is ready. Verify each node's role:

```bash
$ for i in 1 2 3; do
    printf "zk%s: " "$i"
    docker exec zk$i /opt/zookeeper/bin/zkServer.sh status | grep Mode
  done
```

You should see one `Mode: leader` and two `Mode: follower` entries.

To test that data writes are replicated across the ensemble, create a znode on one node and read it back from another:

```bash
$ docker exec zk1 /opt/zookeeper/bin/zkCli.sh -server localhost:2181 create /test "hello"
$ docker exec zk3 /opt/zookeeper/bin/zkCli.sh -server localhost:2181 get /test
hello
```

#### Deploy a 3-node ensemble on Kubernetes

For Kubernetes, ZooKeeper is typically deployed as a `StatefulSet` with a headless `Service` so each pod gets a stable
DNS name. The following manifest deploys a 3-node ensemble that derives `ZOO_MY_ID` from the pod ordinal:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zk-hs
spec:
  clusterIP: None
  selector:
    app: zk
  ports:
    - name: client
      port: 2181
    - name: peer
      port: 2888
    - name: leader-election
      port: 3888
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zk
spec:
  serviceName: zk-hs
  replicas: 3
  selector:
    matchLabels:
      app: zk
  template:
    metadata:
      labels:
        app: zk
    spec:
      imagePullSecrets:
        - name: helm-pull-secret
      containers:
        - name: zookeeper
          image: dhi.io/zookeeper:<tag>
          ports:
            - name: client
              containerPort: 2181
            - name: peer
              containerPort: 2888
            - name: leader-election
              containerPort: 3888
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: ZOO_STANDALONE_ENABLED
              value: "false"
            - name: ZOO_INIT_LIMIT
              value: "10"
            - name: ZOO_SYNC_LIMIT
              value: "5"
            - name: ZOO_SERVERS
              value: "server.1=zk-0.zk-hs.default.svc.cluster.local:2888:3888;2181 server.2=zk-1.zk-hs.default.svc.cluster.local:2888:3888;2181 server.3=zk-2.zk-hs.default.svc.cluster.local:2888:3888;2181"
          command:
            - sh
            - -c
            - "export ZOO_MY_ID=$((${POD_NAME##*-}+1)); exec /opt/zookeeper/bin/entrypoint.sh zkServer.sh start-foreground"
```

The `imagePullSecrets` entry references a pull secret you must create first for `dhi.io`. See
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

**Important:** when you override the container `command`, use the absolute path `/opt/zookeeper/bin/entrypoint.sh`
rather than the bare name `entrypoint.sh`. The image's default ENTRYPOINT relies on `PATH` (which includes
`/opt/zookeeper/bin`), but a fresh `sh -c` invocation under `command:` does not inherit the same lookup behavior.

After applying the manifest:

```bash
$ kubectl apply -f zk-statefulset.yaml
$ kubectl get pods -l app=zk
NAME   READY   STATUS    RESTARTS   AGE
zk-0   1/1     Running   0          15s
zk-1   1/1     Running   0          15s
zk-2   1/1     Running   0          14s
```

Verify roles and test replication the same way as in the Compose example, using `kubectl exec` instead of `docker exec`.

#### Configure with environment variables

The `entrypoint.sh` wrapper translates a set of `ZOO_*` environment variables into the on-disk `zoo.cfg` configuration
file. Common ones (defaults shown):

| Variable                        | Default                              | Purpose                                                       |
| ------------------------------- | ------------------------------------ | ------------------------------------------------------------- |
| `ZOO_MY_ID`                     | (unset, defaults to 1 in standalone) | Unique server ID in an ensemble                               |
| `ZOO_SERVERS`                   | (unset)                              | Comma- or space-separated server list for ensemble membership |
| `ZOO_STANDALONE_ENABLED`        | `true`                               | Allow standalone-mode startup                                 |
| `ZOO_TICK_TIME`                 | `2000`                               | ZooKeeper tick time in milliseconds                           |
| `ZOO_INIT_LIMIT`                | `5`                                  | Time (in ticks) to allow followers to connect to the leader   |
| `ZOO_SYNC_LIMIT`                | `2`                                  | Time (in ticks) to allow followers to sync with the leader    |
| `ZOO_MAX_CLIENT_CNXNS`          | `60`                                 | Maximum concurrent client connections per IP                  |
| `ZOO_ADMINSERVER_ENABLED`       | `true`                               | Enable the AdminServer HTTP endpoint on port 8080             |
| `ZOO_AUTOPURGE_PURGEINTERVAL`   | `0` (disabled)                       | Hours between data autopurge runs                             |
| `ZOO_AUTOPURGE_SNAPRETAINCOUNT` | `3`                                  | Number of snapshots to keep when purging                      |
| `ZOO_DATA_DIR`                  | `/var/zookeeper/data`                | On-disk path for snapshots                                    |
| `ZOO_DATA_LOG_DIR`              | `/var/zookeeper/datalog`             | On-disk path for the transaction log                          |

For the full list of ZooKeeper configuration options, see https://zookeeper.apache.org/doc/current/zookeeperAdmin.html.

### Non-hardened images vs Docker Hardened Images

#### Key differences

| Feature         | Docker Official ZooKeeper           | Docker Hardened ZooKeeper                               |
| --------------- | ----------------------------------- | ------------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened Debian 13 base                        |
| Shell access    | Full shell available                | Bash and `/bin/sh` included (required by `zkServer.sh`) |
| Package manager | `apk` / `apt` available             | No package manager in runtime variants                  |
| User            | Runs as a low-numbered nonroot UID  | Runs as nonroot user (UID 65532)                        |
| Attack surface  | Larger due to additional utilities  | Minimal — JRE + ZooKeeper distribution + shell only     |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting     |
| Compliance      | None                                | CIS                                                     |
| Attestations    | None                                | SBOM, provenance, VEX metadata                          |

#### Why bash is present

Unlike most Docker Hardened Images, the ZooKeeper image **does include a shell** (bash and `/bin/sh`). This is a
functional requirement: the ZooKeeper distribution ships its server as a set of bash scripts (`zkServer.sh`, `zkCli.sh`,
`zkCleanup.sh`) that wrap the JVM invocation. Removing the shell would break the upstream distribution.

The image still removes other typical attack-surface tooling — there is no package manager (`apt`, `apk`, `dpkg`), no
`nc` (netcat), no `curl`, and no editors. For debugging, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/):

```bash
$ docker debug zookeeper
```

#### Health checks without netcat

The classic ZooKeeper health-check pattern uses the `ruok` four-letter word over `nc`:

```bash
$ echo ruok | nc localhost 2181
```

This image does not include `nc`. Use one of the following alternatives:

- **HTTP via AdminServer** (port 8080): `curl http://localhost:8080/commands/ruok` — note that `curl` is also not
  present in the runtime image, so this is typically called from outside the container or from an orchestration probe.
- **`zkServer.sh status`**: works inside the container with no extra tools.
- **`zkCli.sh`** for application-level liveness: connect and run `ls /`.

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

The ZooKeeper image is published as runtime variants only. Tags use a JRE-version suffix (`-jre23`) to indicate the
bundled Java runtime, distinguishing this image from other DHI images that use plain version tags. No `dev`, `fips`, or
`fips-dev` variants are published for this image.

| Variant                     | Tag pattern                                               | User            | Compliance | Availability |
| --------------------------- | --------------------------------------------------------- | --------------- | ---------- | ------------ |
| Runtime (3.9.x with JRE 23) | `3-jre23`, `3.9-jre23`, `3.9.5-jre23`, `3-jre23-debian13` | nonroot (65532) | CIS        | Public       |
| Runtime (3.8.x)             | `3.8`, `3.8.5`, `3.8-debian13`                            | nonroot (65532) | CIS        | Public       |

Tags include rolling aliases — `3-jre23` always points to the latest 3.9.x release with JRE 23, and `3.9-jre23` to the
latest 3.9.x patch.

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

### Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or runtime configuration. At
minimum, you must update the base image to a Docker Hardened Image. This and a few other common changes are listed in
the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                            |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/zookeeper:<tag>`. Note that tags use a JRE-version suffix (`-jre23`) rather than a plain version number.                                                                                             |
| Package management | The runtime image doesn't contain a package manager. To install additional packages, build your own image `FROM dhi.io/zookeeper:<tag>` in a separate environment that has access to package management.                                  |
| Non-root user      | The image runs as the nonroot user (UID 65532). Ensure that any mounted data, datalog, or configuration directories are writable by UID 65532.                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                        |
| Ports              | ZooKeeper listens on 2181 (client), 8080 (AdminServer), 2888 (follower), and 3888 (leader election). All are above 1024 and unaffected by the privileged-port restriction for nonroot containers.                                         |
| Entry point        | The image ENTRYPOINT is `entrypoint.sh` (relying on PATH `/opt/zookeeper/bin`) and the default CMD is `zkServer.sh start-foreground`. When overriding `command:` in Kubernetes, use the absolute path `/opt/zookeeper/bin/entrypoint.sh`. |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in `imagePullSecrets`.                                                                                                                                     |
| netcat absence     | The image does not bundle `nc`. Replace \`echo ruok                                                                                                                                                                                       |

### Troubleshoot migration

The following are common issues that you may encounter during migration.

#### General debugging

The hardened image includes bash and `/bin/sh` (required for the ZooKeeper distribution's shell scripts) but does not
include the typical Linux debugging toolchain (no `nc`, `curl`, `tcpdump`, `ps`, etc.). For deeper inspection, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/):

```bash
$ docker debug zookeeper
```

For operational visibility without a debugger, the AdminServer at `http://<host>:8080/commands` exposes built-in
commands like `ruok`, `srvr`, `stat`, `conf`, and `mntr` that report server health and configuration. The `mntr` command
in particular is the canonical source of metrics for monitoring tools.

#### Permissions

The image runs as UID 65532. Volumes mounted to `/var/zookeeper/data` and `/var/zookeeper/datalog` must be writable by
this UID. When using named Docker volumes, this works automatically. When using bind mounts on the host, ensure the host
directory is owned by UID 65532 (or world-writable for testing).

#### Privileged ports

The image runs as nonroot, so the server cannot bind to ports below 1024. ZooKeeper's default ports (2181, 8080, 2888,
3888\) are all above 1024 and unaffected.

#### Entry point

The image's default ENTRYPOINT is `entrypoint.sh` and CMD is `zkServer.sh start-foreground`. The `entrypoint.sh` script
lives at `/opt/zookeeper/bin/entrypoint.sh`, and is found via `PATH` for the default invocation. When you override
`command:` in Kubernetes or pass `--entrypoint` to `docker run`, you must reference it by its absolute path:

```bash
$ docker run --rm --entrypoint /opt/zookeeper/bin/entrypoint.sh \
    dhi.io/zookeeper:<tag> zkServer.sh start-foreground
```

To view the ENTRYPOINT and CMD for a specific tag, use `docker inspect`.
