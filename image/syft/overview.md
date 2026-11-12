## About Syft

Syft is a powerful CLI tool and Go library for generating Software Bill of Materials (SBOM) from container images and
filesystems. Developed by Anchore, it provides exceptional visibility into the packages and dependencies in your
software, helping organizations manage vulnerabilities, license compliance, and software supply chain security.

Syft excels at SBOM generation for:

- **Container images**: Deep analysis of Docker, OCI, and Singularity image formats
- **Filesystems**: Direct scanning of directories and file trees
- **Archives**: Support for tar, zip, and other compressed formats
- **Git repositories**: Analysis of source code repositories
- **Package managers**: Native support for 30+ package ecosystems
- **Binary analysis**: Extraction of package information from compiled binaries

Key features include:

- **Comprehensive ecosystem support**: Alpine (apk), Debian (dpkg), Red Hat (rpm), Java (jar/war/ear), JavaScript
  (npm/yarn), Python (pip/poetry), Go modules, .NET, Rust Cargo, PHP Composer, and many more
- **Multiple SBOM formats**: CycloneDX (XML/JSON), SPDX (tag-value/JSON), GitHub dependency format, and Syft's own JSON
  format
- **Attestation support**: Generate signed SBOM attestations using the in-toto specification with cosign integration
- **Format conversion**: Convert between different SBOM formats seamlessly
- **Template system**: Custom output formatting using Go templates
- **Linux distribution identification**: Automatic detection of base OS distributions
- **Cataloger selection**: Fine-grained control over package discovery methods

Advanced capabilities:

- **Layered analysis**: Option to include packages from all image layers or just the final squashed image
- **Source attribution**: Track packages back to their original source locations
- **Metadata preservation**: Rich metadata including licenses, versions, locations, and dependencies
- **Integration ready**: Works seamlessly with Grype for vulnerability scanning
- **Performance optimized**: Efficient scanning with parallel processing support
- **Extensible architecture**: Plugin system for custom catalogers and formatters

For more details, visit https://github.com/anchore/syft.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Anchore Syft is a trademark of Anchore, Inc. All rights in the mark are reserved to Anchore, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
