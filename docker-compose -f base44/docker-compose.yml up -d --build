<img alt="dhi-banner" src="https://github.com/user-attachments/assets/fc0ca203-3f25-4ae5-aa8e-e3918bbcc31f" />

# Docker Hardened Images

This repository is the home of the [**Docker Hardened Images**](https://dhi.io) definition files. 
It contains declarative specifications for building secure, minimal, and production-ready container images and Helm charts.

## 🎯 Overview

Docker Hardened Images provides a curated collection of container images built with security and minimalism as core principles. Each image is:

- **Security-focused**: Built with minimal attack surface and hardened configurations
- **Continuously updated**: Regularly maintained with the latest security patches
- **Production-ready**: Configured with best practices for enterprise deployments
- **Transparent**: Fully open-source definitions enable auditability and customization

## 📁 Repository Structure

```
catalog/
├── image/              # Container image definitions
├── chart/              # Helm chart definitions
├── package/            # Reusable package definitions
├── LICENSE.txt         # Apache 2.0 license
├── CONTRIBUTING.md     # Contribution guidelines
└── CODE_OF_CONDUCT.md  # Code of Conduct
```

### 📦 Image Definitions (`image/`)

Contains definitions for **hardened container images** across various categories:

- **Base images**: `alpine-base`, `debian-base`, `busybox`
- **Language runtimes**: `python`, `node`, `golang`, `rust`, `java` (OpenJDK, Eclipse Temurin, Amazon Corretto, Azul)
- **Databases**: `postgres`, `mysql`, `mongodb`, `redis`, `valkey`, `clickhouse`, `elasticsearch`, `opensearch`
- **Infrastructure**: `nginx`, `haproxy`, `traefik`, `envoy`
- **Observability**: `prometheus`, `grafana`, `loki`, `tempo`, `alloy`, `fluent-bit`
- **Kubernetes tools**: `kubectl`, `helm`, `kustomize`, `argocd`, `istio`, `cilium`, `kyverno`
- **Security tools**: `vault`, `cert-manager`, `cosign`, `trivy`, `grype`
- **Development tools**: `maven`, `gradle`, `git`, `jenkins`

#### Image Directory Structure

Each image follows this structure:

```
image/<image-name>/
├── <variant>/               # OS variant (e.g., debian, alpine, debian-12)
│   ├── <config>.yaml        # Image definition files
│   └── ...
└── logo.svg                 # (Optional) Image logo
```

**Example**: `image/nginx/`
```
nginx/
├── alpine/
│   ├── mainline.yaml
│   └── stable.yaml
├── debian/
│   ├── mainline.yaml
│   ├── mainline-dev.yaml
│   ├── stable.yaml
│   └── ...
└── debian-12/
    └── ...
```

#### Image Definition Files

Each `.yaml` file is a declarative specification containing:

- **Metadata**: Image name, tags, supported platforms
- **Contents**: Base OS, packages, repositories, dependencies
- **Build pipeline**: Multi-stage build steps and configurations
- **Security**: User/group configurations, file permissions
- **Runtime**: Entrypoint, command, environment variables, exposed ports
- **Tests**: Automated validation and compliance checks

**Variants** represent different configurations:
- **runtime**: Minimal runtime image
- **`-dev`**: Development image with build tools, shell and package managers
- **`-compat`**: Helm-chart compatibility images

### 📊 Chart Definitions (`chart/`)

Contains definitions for **Helm charts** that deploy applications using hardened images:

**Examples**: `alertmanager`, `cert-manager`, `grafana-agent`, `vault`, `traefik`, `minio`

#### Chart Directory Structure

```
chart/<chart-name>/
├── info.yaml          # Chart metadata and display information
├── overview.md        # Chart overview and description
├── guides.md          # Deployment guides and examples
├── logo.svg           # Chart logo
└── helm/              # Helm chart files
    └── ...
```

**`info.yaml`** contains:
- Display name and description
- Categories (e.g., `integration-and-delivery`, `observability`)
- Documentation URLs

### 🔧 Package Definitions (`package/`)

Contains **package definitions** for common components:

- `binutils`, `expat`, `git-lfs`, `go-yq`, `golang`, `gosu`, `gradle`
- `node`, `python`, `datawire-envoy`

Packages are shared components that can be referenced by multiple image definitions, promoting consistency and reducing duplication.

## 🚀 Getting Started

### Using Hardened Images

Pre-built images are available from Docker's registry:

```bash
docker pull dhi.io/nginx:1.29.3-debian13
docker pull dhi.io/python:3.12-debian13
docker pull dhi.io/postgres:17-debian13
```

## 📖 Documentation

- **[Contributing Guide](CONTRIBUTING.md)**: How to contribute to this project
- **[Code of Conduct](CODE_OF_CONDUCT.md)**: Community guidelines and standards
- **[License](LICENSE.txt)**: Apache 2.0 license terms

For specific image or chart documentation, refer to the `overview.md` and `guides.md` files in their respective directories.

## 🤝 Contributing

We welcome contributions! Whether you're:

- Adding new image definitions
- Improving existing configurations
- Updating documentation
- Reporting issues
- Sharing best practices

Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

### Ways to Contribute

- **Image Requests**: Open an issue to request a new hardened image
- **Bug Reports**: Report issues with existing images or definitions
- **Enhancements**: Suggest improvements to build processes or configurations
- **Documentation**: Help improve guides and examples
- **Testing**: Validate images in different environments

## 🔒 Security

Security is our top priority. All images are:

- Built from minimal base images
- Configured with least-privilege principles
- Scanned for vulnerabilities
- Updated regularly with security patches
- Run as non-root users by default

To report security vulnerabilities, please follow responsible disclosure practices as outlined in our security policy.

## 📄 License

This project is licensed under the Apache License 2.0. See [LICENSE.txt](LICENSE.txt) for details.

## 🔗 Links

- **Docker Hardened Images Catalog**: [Catalog](https://dhi.io)
- **Docker Hardened Images**: [docker.com/products/hardened-images](https://docker.com/products/hardened-images/)
- **Commercial Support**: [docker.com/support](https://docker.com/support/)
- **Issue Tracker**: [GitHub Issues](https://github.com/docker-hardened-images/catalog/issues)
- **Discussions**: [GitHub Discussions](https://github.com/orgs/docker-hardened-images/discussions)

---

**Docker Hardened Images** - Building secure containers, together.
