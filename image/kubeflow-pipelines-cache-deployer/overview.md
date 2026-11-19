## About Kubeflow Pipelines - Cache Deployer

The Kubeflow Pipelines cache deployer installs the mutating admission webhook for the
[Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/) cache server. On start, it requests a TLS
certificate for the cache server through the Kubernetes CertificateSigningRequest API and stores it in a Secret. Then it
registers the webhook with the cluster CA bundle and stays idle. It is upstream's cache deployer from the
[Kubeflow Pipelines project](https://github.com/kubeflow/pipelines/tree/2.18.0/backend/src/cache/deployer), and it
replaces `ghcr.io/kubeflow/kfp-cache-deployer` in the Kubeflow Pipelines manifests.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeFlow® is a registered trademark of The Linux Foundation in the United States and/or other countries. Docker's use is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
