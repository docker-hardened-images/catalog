## Installing the chart

### Prerequisites

- Kubernetes 1.34+
- Helm 3.0+

Calico 3.32+ uses native `projectcalico.org/v3` CRDs. Defaulting is handled by **MutatingAdmissionPolicy** (beta on
Kubernetes 1.34–1.35; GA on 1.36+). On 1.34 and 1.35, ensure the API server has the `MutatingAdmissionPolicy` feature
gate and `admissionregistration.k8s.io/v1beta1` runtime config enabled where your platform requires it.

The Tigera operator installs Calico as the cluster CNI unless you explicitly choose a co-existence mode (for example
`installation.cni.type: AmazonVPC` on EKS). You cannot run Calico as a second CNI on top of Flannel or another plugin
without a planned migration.

For full upstream reference, see
[Calico on EKS](https://docs.tigera.io/calico/latest/getting-started/kubernetes/managed-public-cloud/eks) and
[native v3 CRDs](https://docs.tigera.io/calico/latest/operations/native-v3-crds).

### When to enable apiServer

The chart value `apiServer.enabled` controls reconciliation of the Calico **APIServer** custom resource. The name is
historical: on Calico 3.32+ with native `projectcalico.org/v3` CRDs, the operator does **not** start the old aggregated
API server. Instead it deploys **`calico-webhooks`**, which reconciles **MutatingAdmissionPolicy** and
**ValidatingAdmissionPolicy** objects for v3 CRD defaulting and validation.

| `apiServer.enabled` | Deploys                                                                 | Use when                                                                                |
| ------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `true`              | `calico-webhooks` (+ legacy `calico-apiserver` only in API-server mode) | Native v3 CRDs applied; Calico NetworkPolicy / GlobalNetworkPolicy; tier RBAC on writes |
| `false`             | Neither webhooks nor apiserver pods                                     | Lean CNI-only install (pod networking, no Calico policy APIs)                           |

Examples below that apply `v3_projectcalico_org.yaml` set `apiServer.enabled: true`. For networking-only clusters, you
can omit it and disable optional components (`goldmane.enabled: false`, `whisker.enabled: false`).

All examples below use the public chart and images. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

### Operator-deployed Calico images (`installation.registry`)

When mirroring Calico component images to your own registry namespace (for example
`docker.io/myorg/calico-node:v3.32.1`), set `registry` and `imagePath` at install time:

```yaml
installation:
  registry: docker.io/
  imagePath: myorg
  imagePrefix: calico-
  imagePullSecrets:
    - name: helm-pull-secret
```

```console
helm install tigera-operator oci://dhi.io/tigera-operator-chart --version <version> \
  --namespace tigera-operator \
  --set "installation.registry=docker.io/" \
  --set "installation.imagePath=myorg" \
  --set "installation.imagePullSecrets[0].name=helm-pull-secret"
```

### Amazon EKS: Calico as the CNI (without AWS VPC CNI)

Use this path when Calico should provide **pod networking and IPAM**, not only network policy. The AWS VPC CNI
(`aws-node`) must be removed **before** worker nodes join the cluster.

#### Step 1: Create an EKS cluster without node groups

Create the control plane only. Any method (eksctl, Terraform, EKS console) works; this example uses `eksctl`:

```console
eksctl create cluster --name <cluster-name> --without-nodegroup
```

Use Kubernetes **1.34 or later** so native v3 CRDs and MutatingAdmissionPolicy are supported.

#### Step 2: Remove the AWS VPC CNI

```console
kubectl delete daemonset -n kube-system aws-node
```

Do not add worker nodes until Calico is installed. New nodes should join with Calico as the CNI.

#### Step 3: Install Calico v3 CRDs

Apply the native v3 CRD bundle **before** installing the chart (replace the version to match the chart app version you
install).

Use **server-side apply**. A plain `kubectl apply -f` adds a `last-applied-configuration` annotation that can exceed the
256 KiB metadata limit on large CRDs such as `installations.operator.tigera.io`:

```console
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v3_projectcalico_org.yaml
```

On a **first install** you can alternatively use `kubectl create -f` (same URL). For updates, prefer
`kubectl apply --server-side -f`.

#### Step 4: Create the tigera-operator namespace and pull secret

```console
kubectl create namespace tigera-operator

kubectl create secret docker-registry helm-pull-secret \
  --namespace tigera-operator \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

#### Step 5: Install the Helm chart with EKS values

Create `eks-calico-values.yaml`:

```yaml
installation:
  enabled: true
  imagePullSecrets:
    - name: helm-pull-secret
  kubernetesProvider: EKS
  cni:
    type: Calico
  calicoNetwork:
    bgp: Disabled
apiServer:
  enabled: true
```

Install the chart (replace `<version>` with the chart version, for example `3.32.1`):

```console
helm install tigera-operator oci://dhi.io/tigera-operator-chart --version <version> \
  --namespace tigera-operator \
  -f eks-calico-values.yaml
```

`kubernetesProvider: EKS` selects EKS-specific tuning. `cni.type: Calico` replaces the VPC CNI for pod networking. See
[When to enable apiServer](#when-to-enable-apiserver) above for why `apiServer.enabled: true` is included when using
native v3 CRDs.

#### Step 6: Add EKS node groups

After the operator reports healthy TigeraStatus objects, add workers:

```console
eksctl create nodegroup --cluster <cluster-name> --node-type t3.medium --max-pods-per-node 100
```

Without `--max-pods-per-node`, EKS may cap pod density per instance type.

#### Step 7: Verify

```console
kubectl get tigerastatuses.operator.tigera.io
kubectl -n calico-system get pods
kubectl get nodes -o wide
```

**EKS note:** Calico networking is not installed on EKS control plane nodes. Workloads that must receive connections
from the control plane (for example admission components) may need `hostNetwork: true`. See the
[Calico EKS documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/managed-public-cloud/eks).

### Add-on: Amazon EKS with AWS VPC CNI (policy only)

Use this path on an **existing** EKS cluster that already runs the **Amazon VPC CNI** (`aws-node`). Calico adds
**network policy** (Kubernetes NetworkPolicy and Calico policy APIs); **AWS VPC CNI keeps pod IPAM and routing**.

Do **not** enable
[network policy on the AWS VPC CNI](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html)—it
conflicts with Calico.

#### Step 1: Create or use an EKS cluster with the VPC CNI

```console
eksctl create cluster --name <cluster-name>
```

#### Step 2: Annotate pod IPs on the VPC CNI

Calico needs pod IPs to propagate quickly from `aws-node`:

```console
cat <<EOF > aws-node-patch-rbac.yaml
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF
kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) aws-node-patch-rbac.yaml)
kubectl set env -n kube-system daemonset/aws-node ANNOTATE_POD_IP=true
```

#### Step 3: Install Calico v3 CRDs

```console
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v3_projectcalico_org.yaml
```

#### Step 4: Create the tigera-operator namespace and pull secret

Same as the [Calico CNI EKS steps](#step-4-create-the-tigera-operator-namespace-and-pull-secret) above.

#### Step 5: Install the Helm chart with VPC CNI co-existence values

Create `eks-vpc-policy-values.yaml`:

```yaml
installation:
  enabled: true
  imagePullSecrets:
    - name: helm-pull-secret
  kubernetesProvider: EKS
  cni:
    type: AmazonVPC
  calicoNetwork:
    bgp: Disabled
apiServer:
  enabled: true
goldmane:
  enabled: false
whisker:
  enabled: false
```

```console
helm install tigera-operator oci://dhi.io/tigera-operator-chart --version <version> \
  --namespace tigera-operator \
  -f eks-vpc-policy-values.yaml
```

`cni.type: AmazonVPC` is the documented co-existence mode: **do not** delete `aws-node`. Policy features require
`apiServer.enabled: true` when using native v3 CRDs.

#### Step 6: Verify

```console
kubectl get tigerastatuses.operator.tigera.io
kubectl -n calico-system get pods
```

### Installation on other clusters (k3s, k3d, bare metal)

Prepare a cluster **without an existing CNI**. On k3s, disable Flannel and the built-in network policy controller at
cluster creation, for example:

```console
k3d cluster create calico \
  --image rancher/k3s:v1.35.5-k3s1 \
  --k3s-arg "--flannel-backend=none@server:0" \
  --k3s-arg "--disable-network-policy@server:0" \
  --k3s-arg "--kube-apiserver-arg=feature-gates=MutatingAdmissionPolicy=true@server:0" \
  --k3s-arg "--kube-apiserver-arg=runtime-config=admissionregistration.k8s.io/v1beta1=true@server:0"
```

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

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

#### Step 2: Install Calico v3 CRDs

Use server-side apply (see [Step 3 in the EKS Calico CNI section](#step-3-install-calico-v3-crds) for why plain
`kubectl apply -f` fails on large CRDs):

```console
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v3_projectcalico_org.yaml
```

#### Step 3: Create the tigera-operator namespace

The chart expects to be installed in the `tigera-operator` namespace. Create it before installing.

```console
kubectl create namespace tigera-operator
```

#### Step 4: Create a Kubernetes secret for pulling images

The Docker Hardened Images that the chart uses require authentication. To allow your Kubernetes cluster to pull those
images, you need to create a Kubernetes secret with your Docker Hub credentials or with the credentials for your own
registry.

The secret must live in the `tigera-operator` namespace so that the operator's ServiceAccount can use it.

For example:

```console
kubectl create secret docker-registry helm-pull-secret \
  --namespace tigera-operator \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

#### Step 5: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install tigera-operator oci://dhi.io/tigera-operator-chart --version <version> \
  --namespace tigera-operator \
  --set "installation.enabled=true" \
  --set "installation.imagePullSecrets[0].name=helm-pull-secret" \
  --set "apiServer.enabled=true"
```

Replace `<version>` with the chart version you want to install (for example `3.32.1`).

Set `apiServer.enabled=false` and disable `goldmane` / `whisker` for a lean CNI-only install; see
[When to enable apiServer](#when-to-enable-apiserver) above.

## Uninstalling the chart

```console
helm uninstall tigera-operator --namespace tigera-operator
```
