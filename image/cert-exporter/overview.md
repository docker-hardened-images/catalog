## About Cert Exporter

cert-exporter is a Prometheus exporter that publishes certificate expiration information. It parses x509 certificates
stored on disk (PEM and PKCS#12), embedded in kubeconfig files, and stored in Kubernetes secrets, configmaps, admission
webhooks, and cert-manager `CertificateRequest` resources, then exposes their expiration as Prometheus metrics.

For more information consult the upstream documentation at: https://github.com/joe-elliott/cert-exporter

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
