## About this Helm chart

This is an Apache Spark Kubernetes Operator Docker Helm chart built from the upstream Apache Spark Kubernetes Operator
Helm chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/spark-kubernetes-operator`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://apache.github.io/spark-kubernetes-operator/](https://apache.github.io/spark-kubernetes-operator/)

### About Apache Spark Kubernetes Operator

The Apache Spark Kubernetes Operator manages Apache Spark applications and clusters on Kubernetes. It watches
`SparkApplication` and `SparkCluster` custom resources and reconciles the desired state for Spark driver and executor
workloads.

For more information and documentation see https://spark.apache.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache Spark, Spark, and the Spark logo are trademarks of the Apache Software Foundation. This listing is prepared by
Docker. All third-party product names, logos, and trademarks are the property of their respective owners and are used
solely for identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is
implied.
