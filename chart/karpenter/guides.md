## Installing the chart

### Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- AWS account with appropriate IAM permissions (IRSA or EKS Pod Identities)

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

**Note**: The chart's default `imagePullSecrets` value is an empty array `[]`. You need to override it with your pull
secret name.

```console
helm install my-karpenter oci://dhi.io/karpenter-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set "settings.clusterName=<your-cluster-name>" \
  --set "settings.interruptionQueue=<your-interruption-queue>" \
  --namespace kube-system \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --set "controller.env[0].name=AWS_REGION" \
  --set "controller.env[0].value=us-east-1" \
  --set "serviceAccount.name=karpenter" \
  --set replicas=1
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

Check that the Karpenter controller is running:

```console
kubectl get all -n kube-system
NAME                                             READY   STATUS    RESTARTS   AGE
pod/aws-node-kf5bd                               2/2     Running   0          3d13h
pod/coredns-6d58b7d47c-2c7s8                     1/1     Running   0          3d13h
pod/coredns-6d58b7d47c-mg4k5                     1/1     Running   0          3d13h
pod/eks-pod-identity-agent-zdnlt                 1/1     Running   0          3d13h
pod/karpenter-karpenter-chart-696c6d566d-pjxd8   1/1     Running   0          3d1h
pod/kube-proxy-4t7jr                             1/1     Running   0          3d13h

NAME                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
service/eks-extension-metrics-api   ClusterIP   172.20.63.115   <none>        443/TCP                  3d23h
service/karpenter-karpenter-chart   ClusterIP   172.20.169.56   <none>        8080/TCP                 3d1h
service/kube-dns                    ClusterIP   172.20.0.10     <none>        53/UDP,53/TCP,9153/TCP   3d23h

NAME                                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/aws-node                 1         1         1       1            1           <none>          3d23h
daemonset.apps/eks-pod-identity-agent   1         1         1       1            1           <none>          3d23h
daemonset.apps/kube-proxy               1         1         1       1            1           <none>          3d23h

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coredns                     2/2     2            2           3d23h
deployment.apps/karpenter-karpenter-chart   1/1     1            1           3d1h

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coredns-6d58b7d47c                     2         2         2       3d23h
replicaset.apps/karpenter-karpenter-chart-696c6d566d   1         1         1       3d1h
```

You should see the Karpenter controller pod in a Running state.

#### Step 5: Install Karpenter CRDs

> A simple way to deploy the necessary IAM roles and permissions is through the
> [Karpenter Terraform](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter)
> module:

Before Karpenter can provision nodes, you need to:

1. **Set up IAM roles and policies** as described in the
   [Karpenter documentation](https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/).

1. **Create an EC2NodeClass** to define the AWS-specific configuration for nodes:

```yaml
 apiVersion: karpenter.k8s.aws/v1beta1
 kind: EC2NodeClass
 metadata:
   name: default
   namespace: kube-system
 spec:
   amiFamily: AL2
   role: "KarpenterNodeRole-<your-cluster-name>"
   subnetSelectorTerms:
     - tags:
         karpenter.sh/discovery: "<your-cluster-name>"
   securityGroupSelectorTerms:
     - tags:
         karpenter.sh/discovery: "<your-cluster-name>"
```

1. **Create a NodePool** to define the provisioning constraints:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  namespace: kube-system
spec:
  template:
    metadata:
      labels:
        intent: demo
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "c"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
  limits:
    cpu: "16"
```

1. Make a test deployment to trigger Karpenter Node allocation

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 3
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.9
          resources:
            requests:
              cpu: "1"
```

For complete setup instructions, including IAM configuration and advanced NodePool settings, refer to the official
Karpenter documentation at https://karpenter.sh/docs/.
