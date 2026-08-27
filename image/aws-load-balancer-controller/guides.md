## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-load-balancer-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-load-balancer-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Deploy the AWS Load Balancer Controller

The AWS Load Balancer Controller is a Kubernetes controller and is not run directly with `docker run`. It is deployed
inside a Kubernetes cluster, typically using the official Helm chart from the EKS charts repository. The DHI image
replaces the default upstream image in the Helm chart.

### Prerequisites

Before deploying the controller, you must configure IAM permissions so the controller can manage AWS Elastic Load
Balancers on your behalf. The recommended approach is to use IAM Roles for Service Accounts (IRSA).

#### Step 1: Create an IAM OIDC provider for your cluster

```bash
eksctl utils associate-iam-oidc-provider \
  --region <aws-region> \
  --cluster <cluster-name> \
  --approve
```

#### Step 2: Download the IAM policy

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.17.1/docs/install/iam_policy.json
```

For AWS GovCloud or China regions, download the appropriate policy variant from the
[upstream repository](https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/docs/install).

#### Step 3: Create the IAM policy

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Note the policy ARN returned — you will need it in the next step.

#### Step 4: Create the IAM role and Kubernetes service account

```bash
eksctl create iamserviceaccount \
  --cluster=<cluster-name> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region <aws-region> \
  --approve
```

### Deploy with Helm using the DHI image

Add the EKS Helm chart repository and install the controller, overriding the default image with the DHI image:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
```

Install the controller for the **v2.x** series:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.repository=dhi.io/aws-load-balancer-controller \
  --set image.tag=2
```

Install the controller for the **v3.x** series:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.repository=dhi.io/aws-load-balancer-controller \
  --set image.tag=3
```

Alternatively, use a `values.yaml` file to configure the image override alongside other chart settings:

```yaml
# values.yaml
clusterName: <cluster-name>

serviceAccount:
  create: false
  name: aws-load-balancer-controller

image:
  repository: dhi.io/aws-load-balancer-controller
  tag: "2"
```

Then install with:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f values.yaml
```

### Verify the deployment

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Expected output:

```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           60s
```

## Common AWS Load Balancer Controller use cases

### Provision an Application Load Balancer for an Ingress resource

The controller watches for Kubernetes Ingress resources annotated with `kubernetes.io/ingress.class: alb` (v2.x) or
using `IngressClass` with `spec.controller: ingress.k8s.aws/alb` (v2.x+) and provisions an ALB automatically.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Provision a Network Load Balancer for a Service resource

Annotate a `LoadBalancer`-type Service to provision an NLB:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nlb-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

### Use the Gateway API (v3.x)

Starting with v3.0.0, the AWS Load Balancer Controller provides production-ready support for the Kubernetes Gateway API.
Install the Gateway API CRDs and configure a `GatewayClass` to use the controller:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: eks.amazonaws.com/alb
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
```

### Deploy in isolated clusters (no internet access)

For clusters without internet access that rely on VPC endpoints, disable the Shield, WAF, and WAFv2 add-ons:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.repository=dhi.io/aws-load-balancer-controller \
  --set image.tag=2 \
  --set enableShield=false \
  --set enableWaf=false \
  --set enableWafv2=false \
  --set region=<aws-region> \
  --set vpcId=<vpc-id>
```

## Using the -dev image variant

The `-dev` variant of the image (`dhi.io/aws-load-balancer-controller:2-dev` or
`dhi.io/aws-load-balancer-controller:3-dev`) includes a shell and common utilities, making it useful for debugging and
troubleshooting. The dev image runs as root and includes `bash`, `ca-certificates`, `coreutils`, and `findutils`.

To inspect the controller binary or debug a running container, use Docker Debug with the runtime image:

```bash
docker debug <container-id>
```

To run the dev image locally and inspect its contents:

```bash
docker run --rm -it --entrypoint bash \
  dhi.io/aws-load-balancer-controller:2-dev
```

## Non-hardened images vs. Docker Hardened Images

| Feature         | Upstream (`public.ecr.aws/eks/aws-load-balancer-controller`) | Docker Hardened Image (`dhi.io/aws-load-balancer-controller`) |
| :-------------- | :----------------------------------------------------------- | :------------------------------------------------------------ |
| Base image      | Amazon Linux / minimal base                                  | Debian 13 (minimal, hardened)                                 |
| Run user        | Root or controller-specific user                             | `nonroot` (UID 65532)                                         |
| Shell           | May include shell utilities                                  | No shell in runtime image                                     |
| CVE posture     | Standard upstream patching                                   | Near-zero known CVEs, continuously patched                    |
| SBOM            | Not provided                                                 | Full SBOM and VEX metadata included                           |
| Provenance      | Not signed                                                   | Signed provenance attestation                                 |
| Package manager | Not available at runtime                                     | Not available at runtime (use `-dev` variant)                 |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
