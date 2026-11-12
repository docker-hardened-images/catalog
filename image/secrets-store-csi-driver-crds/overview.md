## About Secrets Store CSI Driver CRDs

Secrets Store CSI Driver CRDs packages the CustomResourceDefinitions that the Secrets Store CSI Driver needs, together
with kubectl to apply them. The two definitions it ships are `SecretProviderClass`, which describes how to reach an
external secrets store, and `SecretProviderClassPodStatus`, which tracks the secrets bound to a running pod.

Installing the CRDs from a separate image lets operators register them before the driver rolls out, which is what the
upstream Helm chart does with a pre-install hook. It also means the definitions can be upgraded on their own schedule,
without touching the driver DaemonSet.

For more details, visit https://secrets-store-csi-driver.sigs.k8s.io.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
