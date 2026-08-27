## Installing the chart

### Prerequisites

- Kubernetes 1.16+
- Helm 3.x

### Installation steps

All examples in this guide use the public chart and images. If you've mirrored the repository for your own use (for
example, to your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, you can follow the instructions in
[How to mirror an image ](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

The same `regctl` tool that is used for mirroring container images can also be used for mirroring Helm charts, as Helm
charts are OCI artifacts.

For example:

```console
 regctl image copy \
     "${SRC_CHART_REPO}:${TAG}" \
     "${DEST_REG}/${DEST_CHART_REPO}:${TAG}" \
     --referrers \
     --referrers-src "${SRC_ATT_REPO}" \
     --referrers-tgt "${DEST_REG}/${DEST_CHART_REPO}" \
     --force-recursive
```

#### Step 2: Create a Kubernetes secret for pulling images

The Docker Hardened Images that the chart uses require authentication. To allow your Kubernetes cluster to pull those
images, you need to create a Kubernetes secret with your Docker Hub credentials or with the credentials for your own
registry.

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

For example:

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

#### Step 3: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install my-zot oci://dhi.io/zot-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get pods
NAME                            READY   STATUS    RESTARTS   AGE
my-zot-xxxxxxxxxx-xxxxx         1/1     Running   0          20s
```

The Zot registry listens on port `5000`. To access it locally, port-forward the service:

```bash
$ kubectl port-forward service/my-zot 5000:5000
```

Then push and pull images at `http://localhost:5000`.

## Mirroring Docker Hardened Images through Zot

Zot's [sync extension](https://zotregistry.dev/v2.1.6/articles/mirroring/) can pull Docker Hardened Images from
`docker.io/dhi` on demand and cache them in your cluster. The first pull from a workload fetches the image from
`docker.io/dhi`; subsequent pulls are served from Zot.

#### Step 1: Create a secret with your Docker Hub credentials

Zot reads upstream registry credentials from a JSON file. Create one locally:

```bash
$ cat > creds.json <<'EOF'
{
  "docker.io": {
    "username": "<Docker username>",
    "password": "<Docker token>"
  }
}
EOF
```

Then create the Kubernetes secret. The chart will mount it into the Zot container:

```bash
$ kubectl create secret generic zot-sync-creds \
    --from-file=creds.json=./creds.json
```

#### Step 2: Configure the chart with a sync-enabled `config.json`

Create a `values.yaml` that enables the sync extension, mounts the chart-managed ConfigMap at `/etc/zot`, and mounts the
credentials secret at `/etc/zot/sync`:

```yaml
mountConfig: true
configFiles:
  config.json: |-
    {
      "distSpecVersion": "1.1.1",
      "storage": { "rootDirectory": "/var/lib/registry" },
      "http": { "address": "0.0.0.0", "port": "5000", "compat": ["docker2s2"] },
      "log": { "level": "info" },
      "extensions": {
        "sync": {
          "enable": true,
          "credentialsFile": "/etc/zot/sync/creds.json",
          "registries": [
            {
              "urls": ["https://docker.io/dhi"],
              "onDemand": true,
              "tlsVerify": true,
              "maxRetries": 6,
              "retryDelay": "5m"
            }
          ]
        }
      }
    }

externalSecrets:
  - secretName: zot-sync-creds
    mountPath: /etc/zot/sync
```

`docker2s2` enables the Docker manifest schema 2 compatibility so the mirrored images can be pulled by Docker clients
that don't speak the OCI media types natively. `onDemand: true` defers the pull until a client asks for the image; flip
it to `false` if you want Zot to mirror eagerly on startup.

#### Step 3: Install the chart with the sync configuration

```console
helm install my-zot oci://dhi.io/zot-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  -f values.yaml
```

#### Step 4: Pull a hardened image through the mirror

Once the pod is up, port-forward the service and pull through Zot:

```bash
$ kubectl port-forward service/my-zot 5000:5000
$ docker pull localhost:5000/dhi/<image>:<tag>
```

Zot fetches the image from `docker.io/dhi` on the first pull and caches it locally for subsequent ones.
