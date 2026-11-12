## About Alpine Base

Alpine Base is a secure, minimal foundation image built on the Alpine Linux operating system. This image provides
essential system utilities and a lightweight base for building containerized applications.

Alpine Linux is known for its security, simplicity, and resource efficiency, featuring a small footprint with musl libc
and busybox. The Alpine Base image includes core utilities through busybox, along with essential security components
like ca-certificates and the apk package manager.

Key features of this Alpine Base image:

- **Ultra-minimal footprint**: One of the smallest Linux distributions available, significantly reducing attack surface
  and resource usage
- **Security-focused**: Built with security best practices and includes ca-certificates bundle
- **Package management**: Includes apk package manager for installing additional software
- **musl libc**: Uses musl C library for better security and smaller size compared to glibc
- **Busybox utilities**: Provides essential Unix utilities in a single compact executable
- **Resource efficient**: Minimal memory and storage requirements make it ideal for containerized environments

The image is based on Alpine Linux 3.22, providing a stable and secure foundation with long-term support. Alpine's
design philosophy emphasizes security, simplicity, and resource efficiency, making it an excellent choice for
container-based applications.

For more details about Alpine Linux, visit https://www.alpinelinux.org/.

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
