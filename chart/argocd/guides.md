## Installing the chart

### Prerequisites

- Kubernetes 1.25+
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
helm install my-argocd oci://dhi.io/argocd-chart --version <version> \
  --set "global.imagePullSecrets[0].name=helm-pull-secret" \
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

If you turn on Redis HA (`redis-ha.enabled`) and HAProxy (`haproxy.enabled`), this chart uses the `dhi/redis-chart`
subchart as `redis-ha` and a separate `dhi/haproxy-chart` as HAProxy.

With the defaults, the redis-secret-init hook creates a Secret named `argocd-redis` with the password under the key
`auth`. Argo CD’s own tooling uses that name and key; the chart sets `redis-ha.auth.existingSecretPasswordKey` to `auth`
so the Redis chart reads the same field. If you turn off `redisSecretInit` and supply your own Secret, use the `auth`
key or set `existingSecretPasswordKey` to whatever key you chose. The HAProxy pod loads the check password from
`haproxy.extraEnvs`; point that at the same Secret name and key as `redis-ha.auth`. By default that is still
`argocd-redis` / `auth`, which matches redis-secret-init and **does not** depend on the Helm release name. If you change
the Secret or the key, update both the Redis auth settings and HAProxy’s `extraEnvs` so they stay in sync.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get pods
NAME                                                        READY   STATUS      RESTARTS   AGE
pod/my-argocd-application-controller-0                      1/1     Running     0          26s
pod/my-argocd-applicationset-controller-877f88767-hkbk7     1/1     Running     0          26s
pod/my-argocd-dex-server-7478b58b56-t9lq4                   1/1     Running     0          26s
pod/my-argocd-notifications-controller-86996485f7-nw9q2     1/1     Running     0          26s
pod/my-argocd-redis-8f964c5cc-l2gmp                         2/2     Running     0          26s
pod/my-argocd-redis-secret-init-4cgx9                       0/1     Completed   0          30s
pod/my-argocd-repo-server-75d689bb78-cpwpz                  1/1     Running     0          26s
pod/my-argocd-server-6458db9b99-bm9mz                       1/1     Running     0          26s
```
