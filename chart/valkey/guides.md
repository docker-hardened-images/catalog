## Installing the chart

### Prerequisites

- Kubernetes 1.20+
- Helm 3.5+

### Installation steps

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

By default, when you mirror a chart or image from the Docker Hardened Images catalog, the chart or image is mirrored to
your namespace in Docker Hub. If you want to then mirror to your own third-party registry, you can follow the
instructions in [How to mirror an image ](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image,
or both.

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

The Docker Hardened Images that the chart uses must be stored in a private repository, in either Docker Hub, or in your
own registry. To allow your Kubernetes cluster to pull those images, you need to create a Kubernetes secret with your
Docker Hub credentials or with the credentials for your own registry.

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

For example:

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<DHI username> \
  --docker-password=<DHI token> \
  --docker-email=<DHI email>
```

#### Step 3: Update the image references in the Helm chart

DHI charts reference images stored in private repositories. While many standard Helm charts use default image locations
that are accessible to everyone, DHI images must first be mirrored to your own Docker Hub namespace or private registry.
Since each organization will have their own unique repository location, the Helm chart must be updated to point to the
correct image locations specific to your organization's Docker Hub namespace or registry.

To do this, you can either use pre-rendering or post-rendering. Pre-rendering uses a values override file to set the
image references, while post-rendering uses a script to rewrite the image references after Helm has rendered the
templates. The following first shows how to use pre-rendering. If you want to use post-rendering instead, skip to the
post-rendering section.

- To use pre-rendering:

  Create a file named `dhi-images.yaml` file with the following:

  ```yaml
   image:
     repository: <your-namespace>/dhi-valkey
  ```

  Replace `docker.io` with your own registry if you are using one. Replace `<your-namespace>` with your Docker Hub
  namespace or with your own namespace in your own registry.

- To use post-rendering, instead of pre-rendering:

  Create a script named `post-renderer.sh` using the following command:

  ```bash
  cat > post-renderer.sh << 'EOF'
  #!/usr/bin/env bash
  set -euo pipefail

  if [ $# -lt 1 ]; then
    echo "Usage: $0 <new-prefix>" >&2
    exit 1
  fi

  # Replaces dhi/ or docker.io/dhi with the specified PREFIX
  PREFIX="$1"
  sed -E "s|(image: )\"?(docker\.io/)?dhi/|\1$PREFIX|g"
  EOF
  chmod +x post-renderer.sh
  ```

  This script will replace all references to `dhi/` or `docker.io/dhi/` with the prefix you provide when running
  `helm install`.

#### Step 4: Install the Helm chart

To install the chart, use `helm install`. The command differs slightly depending on whether you are using post-rendering
or pre-rendering. Also, if the chart is in a private repository, make sure you use `helm login` to log in before running
`helm install`. Optionally, you can also use the `--dry-run` flag to test the installation without actually installing
anything.

- Pre-rendering:

  ```console
  helm install my-valkey oci://registry-1.docker.io/<your-namespace>/dhi-valkey-chart --version <version> \
    --set "imagePullSecrets[0].name=helm-pull-secret" \
    -f dhi-images.yaml
  ```

  Replace `<your-namespace>` and `<version>` accordingly. If the chart is in your own registry, replace
  `registry-1.docker.io/<your-namespace>` with your own registry and namespace. Replace `helm-pull-secret` with the name
  of the image pull secret you created earlier.

- Post-rendering:

  ```console
  helm install my-valkey oci://registry-1.docker.io/<your-namespace>/dhi-valkey-chart --version <version> \
    --set "imagePullSecrets[0].name=helm-pull-secret" \
    --post-renderer ./post-renderer.sh --post-renderer-args "<your-registry-and-repository>"
  ```

  Replace `<your-namespace>` and `<version>` accordingly. If the chart is in your own registry, replace
  `registry-1.docker.io/<your-namespace>` with your own registry and namespace. Replace `<your-registry-and-repository>`
  with the registry and repository prefix you want to use for the images, for example, `gcr.io/my-project/dhi-`, or
  `your-namespace/` if you are using Docker Hub. Replace `helm-pull-secret` with the name of the image pull secret you
  created earlier.

#### Step 5: Verify the installation

After a few seconds all the Valkey pod should be up and running.

```console
$ kubectl get pods
NAME                                      READY   STATUS    RESTARTS   AGE
my-valkey-valkey-chart-7f9f965496-qdwmp   1/1     Running   0          13s
```

Then you should be able to interact with the Valkey service from inside the cluster. A simple way to test if the Helm
Chart is functional is to enable a port-forward rule and use the redis-cli like below:

```bash
$kubectl port-forward service/my-valkey-valkey-chart 6379:6379
Forwarding from 127.0.0.1:6379 -> 6379
Forwarding from [::1]:6379 -> 6379
```

```bash
$redis-cli set "foo" "bar"
OK

$redis-cli get "foo"
"bar"
```
