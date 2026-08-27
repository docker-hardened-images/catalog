## About this Helm chart

This is a Tigera Operator Docker Hardened Helm chart built from the upstream Calico `tigera-operator` Helm chart and
using a hardened configuration with Docker Hardened Images.

### Images referenced in the Helm chart (digest-pinned at build)

These images are wired directly into chart templates and tracked in the chart build:

- `dhi/tigera-operator` — the Tigera operator that installs and reconciles Calico components
- `dhi/calico-ctl` — calicoctl init container on OpenShift installs (upstream chart template)

There are other images controlled by chart values (`whisker.enabled`, and so on)

### Images deployed by the operator (`installation.registry` / `installation.imagePrefix`)

The operator resolves Calico component images at runtime (default layout: `dhi.io/calico-<component>:v<version>`). Set
`installation.imagePath` when mirroring into a registry namespace (for example `dhi` on `docker.io`).

| DHI image                          | Role                                       | Typical trigger                                    |
| ---------------------------------- | ------------------------------------------ | -------------------------------------------------- |
| `dhi/calico-cni`                   | CNI plugin (`install-cni` init)            | Core install                                       |
| `dhi/calico-node`                  | Node agent (Felix, BIRD/eBPF, routing)     | Core install                                       |
| `dhi/calico-kube-controllers`      | Controllers (IPAM, policy sync, and so on) | Core install                                       |
| `dhi/calico-typha`                 | Control-plane fan-out proxy for Felix      | Autoscaler (often ≥1 replica)                      |
| `dhi/calico-apiserver`             | Legacy aggregation API (API-server mode)   | `apiServer.enabled: true` (legacy path)            |
| `dhi/calico-webhooks`              | Admission policies for native v3 CRDs      | `apiServer.enabled: true` (v3 CRD path)            |
| `dhi/calico-csi`                   | CSI driver for Felix policy-sync socket    | CSI enabled (`kubeletVolumePluginPath` not `None`) |
| `dhi/calico-node-driver-registrar` | CSI node-driver-registrar sidecar          | CSI enabled                                        |
| `dhi/calico-pod2daemon-flexvol`    | Legacy FlexVolume init                     | FlexVolume enabled (deprecated path)               |
| `dhi/calico-goldmane`              | Flow log aggregator                        | `goldmane.enabled: true`                           |
| `dhi/calico-whisker`               | Observability UI                           | `whisker.enabled: true`                            |
| `dhi/calico-whisker-backend`       | Observability backend API                  | `whisker.enabled: true`                            |

Lean networking installs enable only the core rows. Policy, observability, and CSI features enable additional rows via
chart values or the `Installation` CR.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/projectcalico/calico/tree/master/charts/tigera-operator](https://github.com/projectcalico/calico/tree/master/charts/tigera-operator)

## About Tigera Operator

The Tigera Operator is a Kubernetes operator that installs, configures, and manages Calico networking and policy
components. It reconciles custom resources such as `Installation` to deploy Calico as the cluster CNI and optional
policy engine.

For more details, visit https://docs.tigera.io/calico/latest/operations/installing-with-helm.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
