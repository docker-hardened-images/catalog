## Installing the chart

### Prerequisites

Before installing the Piraeus HA Controller chart, ensure the following requirements are met:

1. **DRBD kernel module**: The DRBD kernel module must be loaded on all nodes where the controller will run.

   ```bash
   # Check if DRBD module is loaded
   lsmod | grep drbd

   # Load DRBD module if not present
   sudo modprobe drbd

   # Make it persistent across reboots
   echo "drbd" | sudo tee -a /etc/modules-load.d/drbd.conf
   ```

1. **Piraeus/LINSTOR storage**: Piraeus or LINSTOR must be deployed and operational in your cluster with DRBD resources
   configured and in use.

1. **Kubernetes 1.19+**: The chart requires Kubernetes version 1.19 or later.

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
helm install my-piraeus-ha oci://dhi.io/piraeus-ha-controller-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

NOTE: This Docker Hardened Helm chart comes configured with a non root security context. Depending on your setup this
might prevent the Helm chart from working. Should you need it, you can relax the security environment as per the
upstream defaults by replacing the security context with the following values:

```yaml
securityContext:
  privileged: true
  readOnlyRootFilesystem: true
```

#### Step 4: Verify the installation

The DaemonSet should be created and pods should be running on nodes with DRBD resources:

```bash
$ kubectl get daemonset

NAME                                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
my-piraeus-ha-piraeus-ha-controller 3         3         3       3            3           <none>          45s
```

Check the pods:

```bash
$ kubectl get pods -l app.kubernetes.io/name=piraeus-ha-controller-chart

NAME                                      READY   STATUS    RESTARTS   AGE
my-piraeus-ha-piraeus-ha-controller-abc   1/1     Running   0          45s
my-piraeus-ha-piraeus-ha-controller-def   1/1     Running   0          45s
my-piraeus-ha-controller-ghi              1/1     Running   0          45s
```

#### Step 5: Verify controller functionality

Check the controller logs to confirm it's monitoring DRBD resources:

```bash
$ kubectl logs -l app.kubernetes.io/name=piraeus-ha-controller-chart

time="2024-01-15T10:30:45Z" level=info msg="Starting Piraeus HA Controller" version=v1.3.2
time="2024-01-15T10:30:45Z" level=info msg="Watching for DRBD resources"
time="2024-01-15T10:30:46Z" level=info msg="Found 5 DRBD resources on node worker-1"
```

You can also verify that the controller is watching your pods by checking for DRBD-backed volumes:

```console
$ kubectl get volumeattachments

NAME                                                                   ATTACHER              PV                                         NODE     ATTACHED   AGE
csi-abc123...                                                          linstor.csi.linbit.com   pvc-xyz789...                              node01   true       5m
```
