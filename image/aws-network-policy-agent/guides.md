## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-network-policy-agent:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-network-policy-agent:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About the AWS Network Policy Agent

The AWS Network Policy Agent runs as a DaemonSet on each Amazon EKS node and enforces Kubernetes NetworkPolicy resources
using eBPF programs. It requires privileged access to the host network namespace and the ability to load eBPF programs
into the kernel.

The agent is typically deployed automatically by the Amazon VPC CNI plugin when network policy support is enabled on
your EKS cluster. Manual deployment is not recommended for production use.

## Deployment in Kubernetes (EKS)

### Enable Network Policy Support on EKS

The AWS Network Policy Agent is deployed as part of the Amazon VPC CNI plugin when network policy support is enabled. To
enable it on an existing EKS cluster:

```bash
# Enable network policy support via the EKS add-on
aws eks update-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --configuration-values '{"enableNetworkPolicy": "true"}'
```

### Override the Image with the Hardened Version

To use the Docker Hardened Image instead of the default image, patch the DaemonSet after enabling network policy
support:

```bash
kubectl set image daemonset/aws-node \
  aws-network-policy-agent=dhi.io/aws-network-policy-agent:<tag> \
  -n kube-system
```

Or configure the image override in the VPC CNI add-on configuration:

```yaml
{
  "enableNetworkPolicy": "true",
  "nodeAgent": {
    "image": "dhi.io/aws-network-policy-agent:<tag>"
  }
}
```

### Verify the Agent is Running

```bash
# Check the DaemonSet status
kubectl get daemonset aws-node -n kube-system

# Check the network policy agent container logs
kubectl logs -n kube-system -l k8s-app=aws-node -c aws-network-policy-agent
```

## CLI Tools

The image also includes two CLI tools for debugging and inspection:

- `/aws-eks-na-cli` — CLI for inspecting IPv4 network policy state (eBPF maps, policies, endpoints)
- `/aws-eks-na-cli-v6` — CLI for inspecting IPv6 network policy state

These tools are intended for use on EKS nodes where the agent is running and eBPF programs are loaded.

## Image variants

The AWS Network Policy Agent image is available in the following variants:

| Variant                                              | Description                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- |
| `dhi.io/aws-network-policy-agent:<version>`          | Minimal runtime image with the controller binary and pre-compiled eBPF programs |
| `dhi.io/aws-network-policy-agent:<version>-dev`      | Build-time variant with shell and package manager for multi-stage builds        |
| `dhi.io/aws-network-policy-agent:<version>-fips`     | FIPS-compliant runtime variant                                                  |
| `dhi.io/aws-network-policy-agent:<version>-fips-dev` | FIPS-compliant build-time variant                                               |

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

## Security Considerations

The AWS Network Policy Agent requires elevated privileges to:

- Load eBPF programs into the Linux kernel
- Attach TC (Traffic Control) programs to network interfaces
- Access the host network namespace

The container runs as root (`uid=0`) and requires `CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, and `CAP_NET_RAW` capabilities.
These are standard requirements for eBPF-based network agents and are configured automatically by the EKS DaemonSet
manifest.
