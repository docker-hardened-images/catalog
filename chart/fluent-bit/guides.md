## Installing the chart

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
    repository: <your-namespace>/dhi-fluent-bit
  testFramework:
    image:
      repository: <your-namespace>/dhi-busybox
  hotReload:
    image:
      repository: <your-namespace>/dhi-configmap-reload
  ```

  Replace `<your-namespace>` with your Docker Hub namespace or with your own namespace in your own registry.

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
  helm install my-fluent-bit oci://registry-1.docker.io/<your-namespace>/dhi-fluent-bit-chart --version <version> \
    --set "imagePullSecrets[0].name=helm-pull-secret" \
    -f dhi-images.yaml
  ```

  Replace `<your-namespace>` and `<version>` accordingly. If the chart is in your own registry, replace
  `registry-1.docker.io/<your-namespace>` with your own registry and namespace. Replace `helm-pull-secret` with the name
  of the image pull secret you created earlier.

- Post-rendering:

  ```console
  helm install my-fluent-bit oci://registry-1.docker.io/<your-namespace>/dhi-fluent-bit-chart --version <version> \
    --set "imagePullSecrets[0].name=helm-pull-secret" \
    --post-renderer ./post-renderer.sh --post-renderer-args "<your-registry-and-repository>"
  ```

  Replace `<your-namespace>` and `<version>` accordingly. If the chart is in your own registry, replace
  `registry-1.docker.io/<your-namespace>` with your own registry and namespace. Replace `<your-registry-and-repository>`
  with the registry and repository prefix you want to use for the images, for example, `gcr.io/my-project/dhi-`, or
  `your-namespace/` if you are using Docker Hub. Replace `helm-pull-secret` with the name of the image pull secret you
  created earlier.

#### Step 5: Verify the installation

The deployment's pod should show up and running almost immediately:

```console
$ kubectl get all
NAME                              READY   STATUS    RESTARTS   AGE
pod/my-fluent-bit-chart-m4l6l   1/1     Running   0          28s

NAME                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/kubernetes              ClusterIP   10.43.0.1      <none>        443/TCP    44s
service/my-fluent-bit-chart   ClusterIP   10.43.96.255   <none>        2020/TCP   28s

NAME                                   DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/my-fluent-bit-chart   1         1         1       1            1           <none>          28s
```

To test that all works, get the fluent-bit pod name:

```console
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=fluent-bit-chart,app.kubernetes.io/instance=my-fluent-bit" -o jsonpath="{.items[0].metadata.name}")
```

Open a port-forwarding rule:

```console
kubectl --namespace default port-forward $POD_NAME 2020:2020
```

And from another session you can query the fluent-bit API at port 2020:

```console
curl http://127.0.0.1:2020
{"fluent-bit":{"version":"4.2.0","edition":"Community","flags":["FLB_HAVE_SYS_WAIT_H","FLB_HAVE_SIMD","FLB_HAVE_IN_STORAGE_BACKLOG","FLB_HAVE_CHUNK_TRACE","FLB_HAVE_PARSER","FLB_HAVE_RECORD_ACCESSOR","FLB_HAVE_STREAM_PROCESSOR","FLB_HAVE_UNICODE_ENCODER","FLB_EVENT_LOOP_AUTO_DISCOVERY","FLB_HAVE_TLS","FLB_HAVE_OPENSSL","FLB_HAVE_METRICS","FLB_HAVE_PROFILES","FLB_HAVE_WASM","FLB_HAVE_AWS","FLB_HAVE_AWS_CREDENTIAL_PROCESS","FLB_HAVE_SIGNV4","FLB_HAVE_SQLDB","FLB_LOG_NO_CONTROL_CHARS","FLB_HAVE_METRICS","FLB_HAVE_HTTP_SERVER","FLB_HAVE_SYSTEMD","FLB_HAVE_SYSTEMD_SDBUS","FLB_HAVE_FORK","FLB_HAVE_GMTOFF","FLB_HAVE_TIME_ZONE","FLB_HAVE_UNIX_SOCKET","FLB_HAVE_LITTLE_ENDIAN_SYSTEM","FLB_HAVE_LIBYAML","FLB_HAVE_ATTRIBUTE_ALLOC_SIZE","FLB_HAVE_PROXY_GO","FLB_HAVE_JEMALLOC","FLB_HAVE_LIBBACKTRACE","FLB_HAVE_REGEX","FLB_HAVE_UTF8_ENCODER","FLB_HAVE_LUAJIT","FLB_HAVE_ACCEPT4","FLB_HAVE_INOTIFY","FLB_HAVE_GETENTROPY","FLB_HAVE_GETENTROPY_SYS_RANDOM"]}}
```
