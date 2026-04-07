## About this Helm chart

This is an Elastic Cloud on Kubernetes (ECK) Operator Docker Hardened Helm chart built from the upstream ECK Operator
Helm chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/eck-operator`
- `dhi/kibana`
- `dhi/elasticsearch`
- `dhi/logstash`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s)

## About Elastic Cloud on Kubernetes (ECK)

Elastic Cloud on Kubernetes (ECK) automates the deployment, provisioning, management, and orchestration of
Elasticsearch, Kibana, APM Server, Enterprise Search, Beats, Elastic Agent, Elastic Maps Server, Logstash, and Elastic
Package Registry on Kubernetes based on the operator pattern.

ECK brings the power of Elastic Enterprise Search, Observability, and Security to Kubernetes, making it easy to deploy
and manage the Elastic Stack on Kubernetes clusters.

Official documentation: https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Elasticsearch® and Elastic® are trademarks of Elasticsearch B.V., registered in the U.S. and in other countries. All
rights in the marks are reserved to Elasticsearch B.V. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
