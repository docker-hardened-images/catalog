## Installing the chart

### Prerequisites

- Kubernetes 1.21+ (recommended 1.30+)
- Helm 3.6+ (recommended 3.7+)

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
helm install k6-operator oci://dhi.io/k6-operator-chart --version <version> \
  --set "global.image.pullSecrets[0]=helm-pull-secret" \
```

Note: As you might have noticed, upstream sets image pull secret slightly different to most charts.

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pods should show up and running almost immediately:

```bash
$ kubectl get -n test-system all
NAME                                                       READY   STATUS    RESTARTS   AGE
pod/test-k6-operator-controller-manager-6d467b9d65-82bnj   1/1     Running   0          94s

NAME                                                          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/test-k6-operator-controller-manager-metrics-service   ClusterIP   10.43.227.28   <none>        8443/TCP   94s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/test-k6-operator-controller-manager   1/1     1            1           94s

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/test-k6-operator-controller-manager-6d467b9d65   1         1         1       94s
```

Then you should be able to verify the installation by installing a new Grafana K6 instance.

```bash
cat > k6.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-stress-test
data:
  test.js: |
    import { check } from 'k6';
    import { Counter } from 'k6/metrics';

    export let options = {
      vus: 1,
      duration: '2s',
    };

    let myCounter = new Counter('my_counter');

    export default function () {
      myCounter.add(1);
      check(1, {
        'basic math works': () => 1 + 1 === 2,
        'counter incremented': () => true,
      });
    }
---
apiVersion: k6.io/v1alpha1
kind: TestRun
metadata:
  name: k6-run
spec:
  parallelism: 2
  script:
    configMap:
      name: my-stress-test
      file: test.js
  runner:
    image: dhi.io/k6:<version>-compat
    imagePullSecrets:
      - name: helm-pull-secret
EOF
```

Apply the manifest to create the Grafana K6 instance:

```bash
kubectl apply -f k6.yaml
```

And you will see a new Grafana K6 instance up after a few seconds:

```bash
kubectl get all
NAME                           READY   STATUS      RESTARTS   AGE
pod/k6-run-initializer-9x8hc   0/1     Completed   0          17s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   34d

NAME                           STATUS     COMPLETIONS   DURATION   AGE
job.batch/k6-run-initializer   Complete   1/1           10s        17s
```
