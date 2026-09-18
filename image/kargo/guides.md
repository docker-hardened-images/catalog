## Migrate to the Docker Hardened Image

Use the following image replacement for Kargo 1.11.2.

| Upstream image | Docker Hardened Image |
| --- | --- |
| `ghcr.io/akuity/kargo:v1.11.2` | `dhi.io/kargo:1.11.2-debian13` |

The runtime image runs as UID and GID `65532`. The dev variant runs as `root` and has the tag `dhi.io/kargo:1.11.2-debian13-dev`.

## Use the upstream Helm chart

Set the Kargo image repository and tag in the upstream chart values.

```yaml
image:
  repository: dhi.io/kargo
  tag: 1.11.2-debian13
```

Use the registry authentication configuration that your cluster requires for `dhi.io`. The image provides `/sbin/tini` as a compatibility link to `/usr/bin/tini`. This link supports the Kargo 1.11.2 chart templates that use `/sbin/tini` directly.

The image does not declare OCI exposed ports. The chart configures ports for each role. The API server uses port `8080`. The external webhook server uses port `8080`. The Kubernetes webhook server uses port `9443`. Optional metrics services use port `9090` by default when you enable them.

## Verify the image

Run these checks after you pull or build the image.

```console
docker run --rm dhi.io/kargo:1.11.2-debian13 version
docker run --rm --entrypoint /usr/bin/helm dhi.io/kargo:1.11.2-debian13 version --short
docker run --rm --entrypoint /sbin/tini dhi.io/kargo:1.11.2-debian13 -- /usr/local/bin/kargo version
```

Inspect the OCI process configuration and confirm that the image has no exposed ports.

```console
docker image inspect dhi.io/kargo:1.11.2-debian13 \
  --format '{{json .Config.User}} {{json .Config.Entrypoint}} {{json .Config.Cmd}} {{json .Config.ExposedPorts}}'
```

The runtime values are `nonroot`, `["/usr/bin/tini","--"]`, and `["/usr/local/bin/kargo"]`. The exposed-port value is `null`.
