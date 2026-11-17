## About Miniconda3

Miniconda3 is Anaconda's minimal installer for [conda](https://docs.conda.io/), the cross-platform package and
environment manager from Anaconda, Inc. It bundles `conda`, Python, and their base environment into `/opt/conda/`,
giving you a working environment in which to install whatever else you need from the conda or conda-forge ecosystems.

This image is intended as a **build-time base layer**: use it as the `FROM` for a stage that runs `conda install …`,
then copy `/opt/conda` (or a subset of it) into a hardened runtime image of your choice. It ships only as a **dev
variant** — running as `root` with `bash`, `apt`, and the libraries Anaconda's upstream image declares — because that is
the only configuration in which Miniconda's interactive `conda install` workflow is useful.

For more details, visit [docs.conda.io/projects/miniconda](https://docs.conda.io/projects/miniconda/en/latest/).

### A note on FIPS

This image does **not** ship a FIPS variant. The Miniconda installer bundles its own OpenSSL into `/opt/conda/lib/`, and
Python in `/opt/conda/bin` links against that copy — not the system OpenSSL. Swapping the system OpenSSL to a
FIPS-validated provider therefore would not make conda's runtime crypto FIPS-validated; reaching real FIPS compliance
would require rebuilding the entire bundled stack (OpenSSL plus every crypto-touching conda package) from scratch.
Anaconda, Inc. ships a separate commercial "Anaconda for FIPS" product for that use case.

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
