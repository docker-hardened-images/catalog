## Installing the chart

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

**Note**: Homepage requires `config.allowedHosts` to be set to allow access to the dashboard. The chart's default
`image.pullSecrets` value is an empty array `[]`. You need to override it with your pull secret name.

```console
helm install my-homepage oci://dhi.io/homepage-chart --version 1.0.0 \
  --set "image.pullSecrets[0].name=helm-pull-secret" \
  --set "config.allowedHosts=*"
```

Replace `1.0.0` with the desired version. If the chart is in your own registry or repository, replace `dhi.io` with your
own registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

For production use, set `config.allowedHosts` to your specific domain or IP address instead of `*`.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get all
NAME                                      READY   STATUS    RESTARTS   AGE
pod/my-homepage-chart-xxxxxxxxxx-xxxxx    1/1     Running   0          30s

NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/my-homepage-chart   ClusterIP   10.96.xxx.xxx   <none>        3000/TCP   30s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-homepage-chart   1/1     1            1           30s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/my-homepage-chart-xxxxxxxxxx   1         1         1       30s
```

To access the Homepage dashboard, you can port-forward to the service:

```bash
$ kubectl port-forward service/my-homepage-chart 3000:3000
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000
```

Then open your browser to http://localhost:3000

#### Step 5: Configure Homepage

You can customize bookmarks, services, and widgets through the `config.bookmarks`, `config.services`, and
`config.widgets` values. See the [Homepage documentation](https://gethomepage.dev/configs/) for detailed configuration
options.

**Example: Adding custom bookmarks**

Create a `custom-values.yaml` file:

```yaml
config:
  allowedHosts: "*"
  bookmarks:
    - Developer:
        - GitHub:
            - abbr: GH
              href: https://github.com/
        - Docker Hub:
            - abbr: DH
              href: https://hub.docker.com/
```

Then upgrade your installation:

```console
helm upgrade my-homepage oci://dhi.io/homepage-chart --version 1.0.0 \
  --set "image.pullSecrets[0].name=helm-pull-secret" \
  -f custom-values.yaml
```

### Uninstall

```console
helm uninstall my-homepage
```
