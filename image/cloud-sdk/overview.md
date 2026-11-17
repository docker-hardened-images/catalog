## About Google Cloud CLI

The Google Cloud CLI (`gcloud`) is Google's command-line tool for authenticating, configuring, and managing Google Cloud
Platform (GCP) resources; this image also bundles the `bq` and `gsutil` command-line tools for BigQuery and Cloud
Storage. It's commonly used in CI/CD pipelines and automation to deploy workloads, manage infrastructure, and move data
in and out of Google Cloud.

The `-emulators` flavor additionally packages Google's local service emulators for Cloud Datastore, Cloud Firestore,
Pub/Sub, Cloud Bigtable, and Cloud Spanner, so applications can be developed and tested against these APIs entirely
offline — no live GCP project, billing account, or network access required.

This image redistributes Google's official `gcloud` binary under the Apache License 2.0. Using `gcloud` to authenticate
against and manage real Google Cloud Platform resources is additionally governed by the
[Google Cloud Platform Terms of Service](https://cloud.google.com/terms); the bundled emulators run entirely locally and
don't require a GCP account. See the
[Google Cloud SDK documentation](https://cloud.google.com/sdk/docs/downloads-docker) for complete details.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Google Cloud™ and Google Cloud Platform™ are trademarks of Google LLC. All rights in the marks are reserved to Google
LLC. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
