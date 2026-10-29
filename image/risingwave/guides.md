## How to use this image

Authenticate with `docker login dhi.io` before you pull the public image. If you mirror the repository, replace `dhi.io/risingwave:<tag>` with your mirrored image.

### Start a single-node instance

Use single-node mode for local evaluation and development:

```console
docker run --rm --name risingwave \
  -p 4566:4566 \
  -p 5691:5691 \
  dhi.io/risingwave:3.1.0-debian13
```

Connect with a PostgreSQL client:

```console
psql -h 127.0.0.1 -p 4566 -d dev -U root
```

Open the dashboard at `http://localhost:5691`.

### Use a configuration file

Mount a reviewed RisingWave configuration file and pass its path to the selected mode:

```console
docker run --rm --name risingwave \
  -p 4566:4566 \
  -p 5691:5691 \
  -v "$(pwd)/risingwave.toml:/etc/risingwave/risingwave.toml:ro" \
  dhi.io/risingwave:3.1.0-debian13 \
  single_node --config-path /etc/risingwave/risingwave.toml
```

See the [RisingWave configuration documentation](https://docs.risingwave.com/deploy/configure-risingwave) for supported settings.

### Run distributed components

The same executable supports `frontend`, `compute-node`, `meta-node`, `compactor`, and `standalone` modes. Set explicit listen and advertise addresses for each component. Use durable PostgreSQL-compatible metadata storage and supported object storage for production deployments. See the [RisingWave deployment documentation](https://docs.risingwave.com/deploy/risingwave-kubernetes) before you configure a distributed cluster.

### Ports

The image declares the common upstream ports:

| Port | Purpose |
| --- | --- |
| `4566` | PostgreSQL-compatible SQL endpoint |
| `5690` | Meta service |
| `5691` | Dashboard |
| `1250` | Prometheus metrics in the upstream Compose example |

A distributed deployment can use more component ports. Configure the network policy for only the selected component and its required peers.

### Writable data

The runtime image starts as UID and GID `65532`. The `/home/nonroot/.risingwave` directory is writable by this account and stores the default single-node state. The `/risingwave` application payload is root-owned. For production, configure external metadata and state storage instead of relying on the container filesystem.

### Telemetry

RisingWave enables telemetry by default when `ENABLE_TELEMETRY` is not set. Set the following value if your policy does not permit telemetry:

```console
docker run --rm -e ENABLE_TELEMETRY=false dhi.io/risingwave:3.1.0-debian13
```

## Image variants

Runtime tags run as the `nonroot` account. They contain the RisingWave executable, Java 21 runtime, connector libraries, Python 3.12 runtime library, TLS certificates, and ADBC Snowflake driver. They do not contain a shell or package manager.

Development tags end in `-dev`. They run as `root` and add a shell, package manager, and common diagnostic tools. Use a development tag only for controlled diagnosis or as a build stage.

## Migrate from the upstream image

Replace `risingwavelabs/risingwave:v3.1.0` with `dhi.io/risingwave:3.1.0-debian13`.

The hardened image keeps these upstream contracts:

- The entry point is `/risingwave/bin/risingwave`.
- The default command is `single_node`.
- `PLAYGROUND_PROFILE` is `docker-playground`.
- `CONNECTOR_LIBS_PATH` is `/risingwave/bin/connector-node/libs`.
- `ADBC_DRIVER_PATH` is `/risingwave/lib/adbc`.
- `IN_CONTAINER` is `1`.

The runtime image starts as a non-root user. Update mounted-file permissions and Kubernetes security contexts for UID and GID `65532`. The runtime image has no Bash shell, so replace shell-based health checks with an external TCP or HTTP probe. Use Docker Debug or the development variant for diagnosis.

## Verify the image

```console
docker run --rm dhi.io/risingwave:3.1.0-debian13 --version
docker image inspect dhi.io/risingwave:3.1.0-debian13 \
  --format '{{json .Config.User}} {{json .Config.Entrypoint}} {{json .Config.Cmd}}'
```

The runtime inspection values are `nonroot`, `["/risingwave/bin/risingwave"]`, and `["single_node"]`.
