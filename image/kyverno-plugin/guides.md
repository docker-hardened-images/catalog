## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Kyverno Policy Reporter Plugin Hardened image

This image contains `kyverno-plugin`, a companion service for Policy Reporter that adds Kyverno-specific views to its
UI. It watches Kyverno Policies and ClusterPolicies via the Kubernetes API and exposes REST endpoints consumed by the
Policy Reporter UI.

## Start a kyverno-plugin instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `kyverno-plugin` is designed to run within a Kubernetes cluster alongside Policy Reporter and Kyverno. The
following standalone Docker command displays the available configuration options.

```bash
docker run -d --name kyverno-plugin -p 8080:8080 dhi.io/kyverno-plugin:<tag>
```

## Common kyverno-plugin use cases

### Install via the Policy Reporter Helm chart

You can enable the Kyverno plugin through the official Policy Reporter helm chart. Replace `<your-registry-secret>`
with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image
tag.

```bash
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update

helm upgrade --install policy-reporter policy-reporter/policy-reporter \
  --create-namespace -n policy-reporter \
  --set kyvernoPlugin.enabled=true \
  --set kyvernoPlugin.image.repository=dhi.io/kyverno-plugin \
  --set kyvernoPlugin.image.tag=<tag> \
  --set ui.enabled=true \
  --set ui.plugins.kyverno=true
```
