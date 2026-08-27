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

```console
helm install my-strimzi-kafka-operator oci://dhi.io/strimzi-kafka-operator-chart --version <version> \
  --namespace kafka --set "image.imagePullSecrets[0].name=helm-pull-secret" \
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```console
$ kubectl get all -n kafka
NAME                                            READY   STATUS    RESTARTS   AGE
pod/strimzi-cluster-operator-75475d89cf-lfqlt   1/1     Running   0          90s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   99d

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/strimzi-cluster-operator   1/1     1            1           90s

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/strimzi-cluster-operator-75475d89cf   1         1         1       90s
```

Follow the deployment of the Strimzi cluster operator:

```console
kubectl get pod -n kafka --watch
```

You can also follow the operator’s log:

````console
kubectl logs deployment/strimzi-cluster-operator -n kafka -f
```console

Create a new Kafka custom resource to get a single node Apache Kafka cluster:

```console
# Apply the `Kafka` Cluster CR file
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n kafka
````

Wait while Kubernetes starts the required pods, services, and so on:

```console
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka
```

The above command might timeout if you’re downloading images over a slow connection. If that happens you can always run
it again.

If the above command passes your cluster will be ready to be used.

```console
NAME                                              READY   STATUS    RESTARTS   AGE
pod/my-cluster-dual-role-0                        1/1     Running   0          64m
pod/my-cluster-entity-operator-68b769956b-ktv9l   2/2     Running   0          64m
pod/strimzi-cluster-operator-586c8878f6-txn4l     1/1     Running   0          96m

NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                        AGE
service/kubernetes                   ClusterIP   10.96.0.1       <none>        443/TCP                                        99d
service/my-cluster-kafka-bootstrap   ClusterIP   10.99.139.187   <none>        9091/TCP,9092/TCP,9093/TCP                     64m
service/my-cluster-kafka-brokers     ClusterIP   None            <none>        9090/TCP,9091/TCP,8443/TCP,9092/TCP,9093/TCP   64m

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-cluster-entity-operator   1/1     1            1           64m
deployment.apps/strimzi-cluster-operator     1/1     1            1           96m
```
