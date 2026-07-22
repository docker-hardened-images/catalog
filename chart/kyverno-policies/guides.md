## Installing the chart

### Prerequisites

- Kubernetes 1.25+ (recommended 1.30+)

- Helm 3.6+ (recommended 3.7+)

- [Kyverno](https://kyverno.io) installed and running in the cluster. This chart only creates `ClusterPolicy` / `Policy`
  (or CEL-based `ValidatingPolicy`) custom resources; it does not install Kyverno or its CRDs. If Kyverno isn't already
  installed, install it first, for example with the DHI Kyverno Helm chart:

  ```console
  helm install my-kyverno oci://dhi.io/kyverno-chart --version <version> \
    --set "global.imagePullSecrets[0].name=helm-pull-secret"
  ```

### Installation steps

All examples in this guide use the public chart. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart, see the [documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart to your own registry

To optionally mirror the chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/).

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

This chart renders only Kyverno policy custom resources and does not reference any container images, so no image pull
secret is needed to install it.

#### Step 2: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `docker login dhi.io` to authenticate before pulling the
chart. Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
docker login dhi.io
helm install my-kyverno-policies oci://dhi.io/kyverno-policies-chart --version <version>
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace.

#### Step 3: Verify the installation

```console
$ kubectl get clusterpolicies
NAME                                  BACKGROUND   VALIDATE ACTION   READY
disallow-capabilities                 true         Audit             true
disallow-host-namespaces              true         Audit             true
disallow-host-path                    true         Audit             true
disallow-host-ports                   true         Audit             true
disallow-privileged-containers        true         Audit             true
...

$ kubectl get validatingpolicies
```

`kubectl get validatingpolicies` only returns results when `policyType` is set to `ValidatingPolicy`. By default, the
chart creates `ClusterPolicy` resources.

## Common use cases

### Enforce the baseline Pod Security Standard

Install with the default `baseline` profile and switch it from `Audit` to `Enforce` so violating workloads are rejected
instead of only logged:

```console
helm install my-kyverno-policies oci://dhi.io/kyverno-policies-chart --version <version> \
  --set podSecurityStandard=baseline \
  --set validationFailureAction=Enforce
```

### Apply the restricted Pod Security Standard

Use the stricter `restricted` profile, which additionally requires non-root users, drops all capabilities, and disallows
privilege escalation:

```console
helm install my-kyverno-policies oci://dhi.io/kyverno-policies-chart --version <version> \
  --set podSecurityStandard=restricted \
  --set validationFailureAction=Enforce
```

### Audit specific namespaces while enforcing everywhere else

Keep `Enforce` as the global action but override it to `Audit` for namespaces that aren't ready to be blocked yet, such
as a system namespace running third-party workloads:

```console
helm install my-kyverno-policies oci://dhi.io/kyverno-policies-chart --version <version> \
  --set validationFailureAction=Enforce \
  --set "validationFailureActionOverrides.all[0].action=Audit" \
  --set "validationFailureActionOverrides.all[0].namespaces[0]=ingress-nginx"
```

### Use CEL-based ValidatingPolicy resources

On Kyverno 1.17+, switch from the legacy `ClusterPolicy` engine to CEL-based `ValidatingPolicy` resources:

```console
helm install my-kyverno-policies oci://dhi.io/kyverno-policies-chart --version <version> \
  --set policyType=ValidatingPolicy
```

For custom policy sets, per-policy severity overrides, and other advanced configuration, see the
[upstream Pod Security Standards documentation](https://kyverno.io/policies/pod-security).
