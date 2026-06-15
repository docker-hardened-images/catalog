## About this Helm chart

This is an MLflow Helm chart built from the upstream community MLflow Helm chart and using a hardened configuration with
Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/mlflow`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/mlflow/mlflow/tree/master/charts](https://github.com/mlflow/mlflow/tree/master/charts)

## About MLflow

MLflow is an open source platform for managing the end-to-end machine learning lifecycle. It provides experiment
tracking, a model registry, and tools for packaging and deploying models. MLflow integrates with popular ML frameworks
and can be used to track parameters, metrics, and artifacts across runs.

For more details, visit https://mlflow.org.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

MLflow™ is a trademark of the LF Projects, LLC. All rights in the mark are reserved to the LF Projects, LLC. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
