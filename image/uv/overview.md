## About uv

uv is an extremely fast Python package and project manager, written in Rust. It serves as a drop-in replacement for pip,
pip-tools, pipx, poetry, pyenv, and virtualenv, all in a single tool. uv is 10-100x faster than pip and pip-tools
without requiring Rust or even Python to be pre-installed.

uv provides a unified interface for managing Python projects, dependencies, and environments. It supports installing and
managing Python versions, creating and managing virtual environments, resolving dependencies with a lightning-fast
resolver, and running Python scripts and tools.

Key features include:

- Drop-in replacement for pip, pip-tools, and virtualenv
- 10-100x faster than pip
- Disk-space efficient with a global cache
- Reproducible builds with lockfiles
- Cross-platform support (Windows, macOS, Linux)
- Python version management
- Script execution without installation

For more details, visit https://github.com/astral-sh/uv.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

uv is a project by Astral. All rights are reserved to Astral. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
