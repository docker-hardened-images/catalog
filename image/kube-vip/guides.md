## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this kube-vip Docker Hardened Image

This Docker Hardened kube-vip image provides Kubernetes Virtual IP and Load Balancer for both control plane and
Kubernetes services. kube-vip enables high availability for Kubernetes clusters by managing virtual IP addresses and
providing load balancing capabilities. It supports both ARP and BGP modes for VIP advertisement, and can be deployed as
either a static pod for control plane HA or as a DaemonSet for service load balancing.

### Start a kube-vip image

> **Note:** The kube-vip image is designed to run inside a Kubernetes cluster. The standalone Docker command below
> displays the available configuration options.

```bash
docker run --rm -it dhi.io/kube-vip:<tag> --help
```

## Common use cases

### Deploy kube-vip for control plane HA

kube-vip can be deployed as a static pod to provide high availability for the Kubernetes control plane. Create a
manifest using the kube-vip container. Replace `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/), and replace `<tag>` with the desired image tag.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - name: kube-vip
    image: dhi.io/kube-vip:<tag>
    args:
    - manager
    env:
    - name: vip_arp
      value: "true"
    - name: vip_interface
      value: eth0
    - name: address
      value: 192.168.1.100
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kubeconfig
  hostNetwork: true
  volumes:
  - name: kubeconfig
    hostPath:
      path: /etc/kubernetes/admin.conf
  imagePullSecrets:
  - name: <your-registry-secret>
EOF
```

### Deploy kube-vip as a DaemonSet for service load balancing

For service load balancing, deploy kube-vip as a DaemonSet:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-vip
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: kube-vip
  template:
    metadata:
      labels:
        app: kube-vip
    spec:
      containers:
      - name: kube-vip
        image: dhi.io/kube-vip:<tag>
        args:
        - manager
        env:
        - name: vip_arp
          value: "true"
        - name: vip_interface
          value: eth0
        - name: svc_enable
          value: "true"
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532
          runAsGroup: 65532
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
      hostNetwork: true
      imagePullSecrets:
      - name: <your-registry-secret>
EOF
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened kube-vip          | Docker Hardened kube-vip                            |
| --------------- | ------------------------------ | --------------------------------------------------- |
| Security        | Standard base with utilities   | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available | No shell in runtime variants                        |
| Package manager | apt/apk available              | No package manager in runtime variants              |
| User            | Runs as root by default        | Runs as nonroot user (requires NET_ADMIN caps)      |
| Attack surface  | Larger due to utilities        | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging    | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/dhi-busybox,destination=/dbg,ro \
  dhi.io/kube-vip:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

### iptables variant

The `iptables` variant includes iptables binaries required for kube-vip's egress functionality. This variant includes:

- `/usr/sbin/iptables-legacy`
- `/usr/sbin/iptables-legacy-restore`
- `/usr/sbin/iptables-legacy-save`
- `/usr/sbin/iptables-nft`
- `/usr/sbin/iptables-nft-restore`
- `/usr/sbin/iptables-nft-save`

Use the `iptables` variant if you need egress support with kube-vip. For more information, see the
[kube-vip egress documentation](https://kube-vip.io/docs/usage/egress/).

## Migrate to a Docker Hardened Image

Switching to the hardened kube-vip image does not require any special changes. You can use it as a drop-in replacement
for the standard kube-vip (`ghcr.io/kube-vip/kube-vip`) image in your existing workflows and configurations. Note that
the entry point for the hardened image may differ from the standard image, so ensure that your commands and arguments
are compatible.

### Migration steps

1. Update your image reference.

   Replace the image reference in your Kubernetes manifests or Helm values, for example:

   - From: `ghcr.io/kube-vip/kube-vip:<tag>`
   - To: `dhi.io/kube-vip:<tag>`

1. Update security context for hardened image.

   The hardened image runs as nonroot user (65532) by default. Ensure your pod security context is configured:

   ```yaml
   securityContext:
     runAsNonRoot: true
     runAsUser: 65532
     runAsGroup: 65532
     capabilities:
       add:
       - NET_ADMIN
       - NET_RAW
   ```

1. All your existing command-line arguments, environment variables, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

For kube-vip specifically, the nonroot user requires NET_ADMIN and NET_RAW capabilities to manage virtual IPs and
network configuration.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
