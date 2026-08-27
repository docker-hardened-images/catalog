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
helm install test oci://dhi.io/promtail-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get all
NAME                            READY   STATUS    RESTARTS   AGE
pod/test-promtail-chart-nsfcg   2/2     Running   0          16s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/kubernetes        ClusterIP   10.43.0.1       <none>        443/TCP             93s

NAME                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/test-promtail-chart   1         1         1       1            1           <none>          16s
```

### Full Example with Loki

Promtail is used typically to send logs to a Loki server. This Helm chart is configured to run as nonroot and does
require some customization either by mounting volumes on directories that the nonroot user can read , or perhaps running
the Helm chart as root user but with most capabilities capped leaving just enough room to read the host logs.

To run a quick validation example, here we are launching an init container that shares a folder with promtail so that
both the logs writer and promtail can read it.

First we need to install Loki. We will use some very constrained values so that we limit the configuration that needs to
be set.

Create the config file.

```bash
cat > loki-values.json << EOF
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  useTestSchema: true
singleBinary:
  replicas: 1
  resources:
    limits:
      memory: 512Mi
    requests:
      memory: 256Mi
write:
  replicas: 0
read:
  replicas: 0
backend:
  replicas: 0
# Disable gateway (adds nginx reverse proxy)
gateway:
  enabled: false
# Disable test/monitoring components
test:
  enabled: false
monitoring:
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false
  lokiCanary:
    enabled: false
# Disable caching layers
chunksCache:
  enabled: false
resultsCache:
  enabled: false
EOF
```

Install Loki with this values.

```bash
helm install loki grafana/loki -f loki-values.yaml
```

And after a moment, you should see all the resources ready.

```console
kubectl get all
NAME                    READY   STATUS    RESTARTS   AGE
pod/loki-0              2/2     Running   0          89s
pod/loki-canary-mwhzt   1/1     Running   0          89s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/kubernetes        ClusterIP   10.96.0.1       <none>        443/TCP             12d
service/loki              ClusterIP   10.111.80.71    <none>        3100/TCP,9095/TCP   89s
service/loki-canary       ClusterIP   10.96.185.190   <none>        3500/TCP            89s
service/loki-headless     ClusterIP   None            <none>        3100/TCP            89s
service/loki-memberlist   ClusterIP   None            <none>        7946/TCP            89s

NAME                         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/loki-canary   1         1         1       1            1           <none>          89s

NAME                    READY   AGE
statefulset.apps/loki   1/1     89s
```

Next, before installing the DHI Promtail Helm chart, you will need some configuration:

```bash
cat > promtail-values.yaml << EOF
imagePullSecrets:
  - name: dhi-pull-secret

# Override defaultVolumes to remove hostPath mounts (non-root cannot access them)
defaultVolumes:
  - name: run
    emptyDir: {}

defaultVolumeMounts:
  - name: run
    mountPath: /run/promtail

# E2E testing: shared volume for test log files
extraVolumes:
  - name: e2e-logs
    emptyDir: {}

extraVolumeMounts:
  - name: e2e-logs
    mountPath: /var/log/e2e

# E2E testing: sidecar container that continuously writes test logs
extraContainers:
  e2e-writer:
    image: busybox:1.36
    command:
      - /bin/sh
      - -c
    args:
      - 'i=0; while true; do i=$((i+1)); echo "$(date -Iseconds) level=info msg=e2e-line n=$i" >> /var/log/e2e/app.log; sleep 1; done'
    volumeMounts:
      - name: e2e-logs
        mountPath: /var/log/e2e
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL

# Configure Promtail to scrape from e2e-logs instead of host paths
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
  snippets:
    scrapeConfigs: |
      - job_name: e2e-file
        static_configs:
          - targets: [localhost]
            labels:
              job: e2e
              app: promtail-chart
              __path__: /var/log/e2e/app.log
EOF
```

Note how the first line in the above file defines a pull secret for being able to pull the container images from dhi.io.
Make sure that you have that pull secret created as defined earlier in this guide.

Finally, install promtail:

```bash
helm install test oci://dhi.io/promtail-chart --version <version> -f promtail-values.yaml
```

And you should see the Promtail deployment going into healthy state:

```console
kubectl get all
NAME                            READY   STATUS    RESTARTS   AGE
pod/loki-0                      2/2     Running   0          12m
pod/loki-canary-mwhzt           1/1     Running   0          12m
pod/test-promtail-chart-tjs6k   2/2     Running   0          4m12s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/kubernetes        ClusterIP   10.96.0.1       <none>        443/TCP             12d
service/loki              ClusterIP   10.111.80.71    <none>        3100/TCP,9095/TCP   12m
service/loki-canary       ClusterIP   10.96.185.190   <none>        3500/TCP            12m
service/loki-headless     ClusterIP   None            <none>        3100/TCP            12m
service/loki-memberlist   ClusterIP   None            <none>        7946/TCP            12m

NAME                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/loki-canary           1         1         1       1            1           <none>          12m
daemonset.apps/test-promtail-chart   1         1         1       1            1           <none>          4m12s

NAME                    READY   AGE
statefulset.apps/loki   1/1     12m
```

To check the metrics, start a port forwarding session:

```bash
kubectl --namespace default port-forward daemonset/test-promtail-chart 3101
```

And from another session you should be able to query Promtail metrics:

```console
curl http://127.0.0.1:3101/metrics
# HELP deprecated_flags_inuse_total The number of deprecated flags currently set.
# TYPE deprecated_flags_inuse_total counter
deprecated_flags_inuse_total 0
# HELP go_gc_duration_seconds A summary of the wall-time pause (stop-the-world) duration in garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 9.6292e-05
go_gc_duration_seconds{quantile="0.25"} 0.000171125
go_gc_duration_seconds{quantile="0.5"} 0.000285083
go_gc_duration_seconds{quantile="0.75"} 0.000506875
...
```

Also you can port forward Loki:

```bash
kubectl --namespace default port-forward service/loki 3100
```

And then query for logs:

```console
curl "http://localhost:3100/loki/api/v1/query_range?query=%7Bjob%3D%22e2e%22%7D&limit=20"

{"status":"success","data":{"resultType":"streams","result":[{"stream":{"app":"promtail-chart","detected_level":"info","filename":"/var/log/e2e/app.log","job":"e2e","service_name":"promtail-chart"},"values":[["1770217100309524132","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217099300529339","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217098294367756","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217097292486589","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217096287939546","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217095282501504","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217094272345504","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217093266520003","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217092263416419","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217091260494877","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217090507375002","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217089499455293","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217088493605126","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217087487546917","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217086481334458","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217085477318041","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217084475645097","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217083472453846","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217082465624679","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="],["1770217081459566845","2026-02-04T15:30:39+01:00 level=info msg=e2e-line n="]]}],"stats":{"summary":{"bytesProcessedPerSecond":7333989,"linesProcessedPerSecond":122233,"totalBytesProcessed":29820,"totalLinesProcessed":497,"execTime":0.004066,"queueTime":0.000383,"subqueries":0,"totalEntriesReturned":20,"splits":1,"shards":1,"totalPostFilterLines":49
....
```
