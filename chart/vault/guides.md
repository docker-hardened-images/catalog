## Installing the chart

### Prerequisites

- Kubernetes 1.29+
- Helm 3.6+

## Vault images this chart expects

> **IMPORTANT** The chart is wired to the **`-helm`** image line by default (`server.image` and the injector
> `agentImage` use the helm flavor for your distro). That image includes additional tools so the upstream templates
> (shell snippets, entrypoint script paths) work. **If you override `server.image`:** use the same **`-helm`** tag you
> would get from the defaults (for example `dhi.io/vault:1-helm`), not the minimal **runtime** tag (`dhi.io/vault:1`
> only).

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
helm install my-vault oci://dhi.io/vault-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

After installation is complete, all Kubernetes resources should be in a healthy state:

```console
NAME                                                       READY   STATUS    RESTARTS   AGE
pod/my-vault-vault-chart-0                                 1/1     Running   0          2m1s
pod/my-vault-vault-chart-agent-injector-84dc9bbdf6-srjg7   1/1     Running   0          2m1s

NAME                                              TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/kubernetes                                ClusterIP      10.96.0.1       <none>        443/TCP             7d23h
service/my-vault-vault-chart                      ClusterIP      10.96.145.176   <none>        8200/TCP,8201/TCP   2m1s
service/my-vault-vault-chart-agent-injector-svc   ClusterIP      10.96.65.38     <none>        443/TCP             2m1s
service/my-vault-vault-chart-internal             ClusterIP      None            <none>        8200/TCP,8201/TCP   2m1s
service/my-vault-vault-chart-ui                   LoadBalancer   10.96.64.248    172.18.0.8    8200:32149/TCP      2m1s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-vault-vault-chart-agent-injector   1/1     1            1           2m1s

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/my-vault-vault-chart-agent-injector-84dc9bbdf6   1         1         1       2m1s

NAME                                    READY   AGE
statefulset.apps/my-vault-vault-chart   1/1     2m1s
```
