## Installing the chart

### Prerequisites

- Kubernetes 1.19+

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
helm install my-external-secrets oci://dhi.io/external-secrets-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get pods -n external-secrets
NAME                                                              READY    STATUS    RESTARTS   AGE
my-external-secrets-external-secrets-chart-976db967f-d2kng         1/1     Running   0          15s
my-external-secrets-external-secrets-chart-cert-controller-lwqq6   1/1     Running   0          15s
my-external-secrets-external-secrets-chart-webhook-5f47ccdcxdr6t   1/1     Running   0          15s
```

The simplest way to test the operator is to create a secret using their internal test provider. First we create the
CRDs.

```console
$ cat > clustersecretstore-fake.yaml << 'EOF'
# clustersecretstore-fake.yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: fake
spec:
  provider:
    fake:
      data:
        - key: "/foo/bar"
          value: "HELLO1"
          version: "v1"
        - key: "/foo/baz"
          value: '{"john":"doe"}'
          version: "v1"
EOF
```

```console
$ cat > externalsecret-fake.yaml << 'EOF'
# externalsecret-fake.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: example
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: fake
    kind: ClusterSecretStore
  target:
    name: secret-to-be-created
  data:
    - secretKey: foo_bar
      remoteRef:
        key: /foo/bar
        version: v1
  dataFrom:
    - extract:
        key: /foo/baz
        version: v1
EOF
```

Send those to the cluster:

```console
$ kubectl apply -f clustersecretstore-fake.yaml -f externalsecret-fake.yaml

Warning: store fake isn't currently maintained. Plan and prepare accordingly.
clustersecretstore.external-secrets.io/fake created
externalsecret.external-secrets.io/example created
```

And after a few seconds we should have the Kubernetes Secret ready to be used.

```console
$ kubectl get Secret secret-to-be-created
NAME                   TYPE     DATA   AGE
secret-to-be-created   Opaque   2      58s

$ kubectl get Secret secret-to-be-created --template={{.data.foo_bar}} | base64 -d
HELLO1
```
