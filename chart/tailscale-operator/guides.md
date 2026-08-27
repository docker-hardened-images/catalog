## Installing the chart

### Installation steps

All examples in this guide use the public chart and images. If you've mirrored the repository for your own use (for
example, to your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Create a Tailscale OAuth client

The operator authenticates with Tailscale using an OAuth client. Create one in the
[Tailscale admin console](https://login.tailscale.com/admin/settings/oauth) with the `Devices` write scope and note the
client ID and secret.

#### Step 2: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

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

#### Step 3: Create a Kubernetes secret for pulling images

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

#### Step 4: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install tailscale-operator oci://dhi.io/tailscale-operator-chart --version <version> \
  --set oauth.clientId=<client-id> \
  --set oauth.clientSecret=<client-secret> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` with the desired chart version, and `<client-id>`/`<client-secret>` with your Tailscale OAuth
credentials. If the chart is in your own registry, replace `dhi.io` with your own registry and namespace.

#### Step 5: Verify the installation

The operator pod should start within seconds:

```bash
$ kubectl get all
NAME                            READY   STATUS    RESTARTS   AGE
pod/operator-6b79d44cd4-vdv9h   1/1     Running   0          30s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/operator   1/1     1            1           30s
```

Once the operator is running, you can expose a Kubernetes Service on your tailnet by annotating it:

```console
kubectl annotate service <service-name> tailscale.com/expose=true
```

## Exposing a Service via Tailscale Ingress

To expose a Service using the Tailscale ingress class, create an `Ingress` resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service-ingress
spec:
  ingressClassName: tailscale
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
  tls:
    - hosts:
        - my-service
```

The operator will provision a Tailscale node named `my-service` that is reachable from any device on your tailnet at
`https://my-service.<tailnet-name>.ts.net`.

## Enabling the Kubernetes API server proxy

To allow kubectl access via Tailscale without exposing the API server publicly, set `apiServerProxyConfig.mode`:

```console
helm upgrade tailscale-operator oci://dhi.io/tailscale-operator-chart --version <version> \
  --reuse-values \
  --set apiServerProxyConfig.mode=true
```

For full configuration reference, see the
[upstream Helm chart documentation](https://github.com/tailscale/tailscale/tree/main/cmd/k8s-operator/deploy/chart).
