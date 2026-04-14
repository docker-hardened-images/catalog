## About Grype

Grype is a fast and accurate vulnerability scanner for container images and filesystems. Developed by Anchore, it
provides comprehensive security analysis by detecting vulnerabilities across multiple package ecosystems and languages,
helping organizations secure their software supply chain.

Grype excels at identifying vulnerabilities in:

- **Container images**: Deep scanning of Docker, OCI, and Singularity image formats
- **Filesystems**: Direct analysis of directories and file trees
- **Package ecosystems**: Support for Java (JAR, EAR, WAR), JavaScript (NPM, Yarn), Python (Pip, Poetry), .NET, Go
  modules, PHP Composer, Rust Cargo, and more
- **SBOM analysis**: Scanning Software Bills of Materials for vulnerability assessment
- **Attestation verification**: Integration with cosign for verifying attestations with SBOM content

Key features include:

- **Fast scanning**: Optimized for speed without sacrificing accuracy
- **Comprehensive coverage**: Supports 30+ package ecosystems and language environments
- **Multiple output formats**: Table, JSON, CycloneDX (XML/JSON), SARIF, and custom template support
- **VEX support**: Integration with OpenVEX for filtering false positives and augmenting results
- **Flexible filtering**: Sort by severity, EPSS score, risk score, or KEV status
- **CI/CD integration**: Built-in exit codes and reporting formats for automation
- **External data sources**: Enhanced vulnerability matching with Maven repository integration

Advanced capabilities:

- **Risk scoring**: Comprehensive risk assessment beyond basic severity ratings
- **EPSS integration**: Exploit Prediction Scoring System for threat-based prioritization
- **KEV awareness**: Known Exploited Vulnerabilities catalog integration
- **Ignore rules**: Sophisticated filtering to reduce false positives
- **Fix state tracking**: Identification of fixed vs. unfixed vulnerabilities
- **Template system**: Custom output formatting using Go templates

For more details, visit https://github.com/anchore/grype.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Anchore Grype is a trademark of Anchore, Inc. All rights in the mark are reserved to Anchore, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
