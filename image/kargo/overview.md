## About Kargo

[Kargo](https://kargo.io/) is a continuous promotion platform for Kubernetes. One Kargo image runs the API server, controller, management controller, external webhook server, Kubernetes webhook server, and garbage collector through Kargo subcommands.

The image contains the embedded Kargo web interface. It also contains the Kargo credential helper and Helm 3. Git, GnuPG, and OpenSSH support Git and OCI workflows. BusyBox supplies the shell that Kargo currently requires. Tini runs as the container init process.

The runtime image runs as the `nonroot` user with UID and GID `65532`. The dev image keeps this account but runs as `root`. The dev image adds Debian package management and common diagnostic tools. It does not include the Go or Node.js build toolchains.

## About Docker Hardened Images

Docker Hardened Images are minimal images with secure defaults. They include vulnerability remediation, an SBOM, and build provenance. The Kargo runtime image keeps only the operating system packages that are required for compatibility with the upstream Kargo image.

## Trademarks

Kargo is a project of Akuity. This image is not affiliated with or endorsed by Akuity.
