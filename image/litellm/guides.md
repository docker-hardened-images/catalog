## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s included in this LiteLLM image

This Docker Hardened LiteLLM image includes a universal LLM API gateway that provides OpenAI-compatible APIs for 100+
LLM providers in a single, security-hardened package:

- **LiteLLM proxy server**: Universal API gateway that simplifies LLM API calls with a unified OpenAI-compatible
  interface
- **100+ Provider support**: OpenAI, Anthropic, Azure, AWS Bedrock, Google Vertex AI, Cohere, Hugging Face, and many
  more
- **Load balancing and failover**: Built-in load balancing with automatic failover capabilities
- **Rate limiting and cost tracking**: Per-user and per-model rate limiting with comprehensive usage tracking and budget
  management
- **Caching and performance**: Response caching to reduce costs and improve performance
- **Authentication and monitoring**: API key management, user authentication, and comprehensive logging/metrics

## Start a litellm image

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -p 4000:4000 \
  -v ./config.yaml:/app/config.yaml \
  -e OPENAI_API_KEY=your-openai-key \
  -e ANTHROPIC_API_KEY=your-anthropic-key \
  dhi.io/litellm:<tag> --config /app/config.yaml
```

## Common litellm use cases

### Multi-provider LLM gateway

Use LiteLLM as a unified proxy to route requests across multiple LLM providers (OpenAI, Anthropic, Azure, Bedrock, etc.)
with automatic failover and load balancing.

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY
  - model_name: claude-3
    litellm_params:
      model: anthropic/claude-3-sonnet-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
```

### Cost optimization and tracking

Monitor usage and costs across different LLM providers, implement budget controls and rate limiting per user or API key.

```bash
docker run -p 4000:4000 \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -e DATABASE_URL=postgresql://user:password@hostname:5432/litellm \
  -e OPENAI_API_KEY=your-openai-key \
  dhi.io/litellm:<tag> --config /app/config.yaml
```

### OpenAI API compatibility

Make existing applications that use OpenAI's API compatible with other LLM providers without code changes.

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello, world!"}],
    "max_tokens": 100
  }'
```

### Development and testing

Easily switch between different LLM models and providers during development and testing phases. Configure common
environment variables:

- `OPENAI_API_KEY`: OpenAI API key
- `ANTHROPIC_API_KEY`: Anthropic API key
- `AZURE_API_KEY`: Azure OpenAI API key
- `VERTEX_PROJECT`: Google Cloud Project ID for Vertex AI
- `AWS_ACCESS_KEY_ID`: AWS access key for Bedrock
- `DATABASE_URL`: PostgreSQL database URL for tracking
- `LITELLM_LOG`: Log level (DEBUG, INFO, WARNING, ERROR)

### Enterprise LLM access control

Centralized authentication, authorization, and monitoring for LLM access across an organization.

Configure authentication and team management in your config.yaml:

```yaml
general_settings:
  master_key: sk-master-key-here
  database_url: postgresql://user:pass@host:5432/litellm

  authentication:
    enable: true
    api_key_header: "Authorization"

  max_budget: 1000
  budget_duration: 30d

model_list:
  - model_name: gpt-4-production
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY
    metadata:
      team: "engineering"
      max_requests_per_minute: 100
```

Create API keys for different teams:

```bash
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer sk-master-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "team_id": "engineering-team",
    "max_budget": 500,
    "models": ["gpt-4-production"],
    "duration": "30d"
  }'
```

### Load balancing and reliability

Distribute requests across multiple model deployments with automatic retry logic and failover capabilities.

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY
      rpm: 100

  - model_name: gpt-4
    litellm_params:
      model: azure/gpt-4-deployment
      api_base: https://myazure.openai.azure.com
      api_key: os.environ/AZURE_API_KEY
      rpm: 200

  - model_name: gpt-4-fallback
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  routing_strategy: "least-busy"
  num_retries: 3
  timeout: 30
  fallbacks:
    gpt-4: ["gpt-4-fallback"]
```

### Multi-provider strategy

Standardize LLM integration across development teams while easily switching between providers to optimize for cost,
performance, or availability.

```yaml
model_list:
  - model_name: chat-cheap
    litellm_params:
      model: anthropic/claude-3-haiku-20240307
      api_key: os.environ/ANTHROPIC_API_KEY
    metadata:
      cost_per_token: 0.00025
      use_case: "simple_queries"

  - model_name: chat-powerful
    litellm_params:
      model: openai/gpt-4-turbo
      api_key: os.environ/OPENAI_API_KEY
    metadata:
      cost_per_token: 0.01
      use_case: "complex_analysis"

  - model_name: chat-compliant
    litellm_params:
      model: azure/gpt-4-deployment
      api_base: https://private.openai.azure.com
      api_key: os.environ/AZURE_API_KEY
    metadata:
      data_residency: "us-east"
      compliance: "hipaa"
```

Use the same client code to work with any configured model:

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "chat-cheap",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature                | Standard LiteLLM Image              | Docker Hardened LiteLLM                                                    |
| ---------------------- | ----------------------------------- | -------------------------------------------------------------------------- |
| Security               | Standard base with common utilities | Minimal, hardened base with security patches                               |
| Shell access           | Full shell (bash/sh) available      | No shell in runtime variants                                               |
| Package manager        | apt/apk available                   | No package manager in runtime variants (pip available for Python packages) |
| User                   | Runs as root by default             | Runs as nonroot user                                                       |
| Attack surface         | Larger due to additional utilities  | Minimal, only essential components                                         |
| Debugging              | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting                        |
| Provenance             | Standard image metadata             | Signed provenance attestations and complete SBOM                           |
| Vulnerability tracking | Standard CVE reporting              | VEX documents explaining remaining CVEs                                    |
| Upstream compatibility | N/A                                 | Based on official litellm/litellm, maintains full API compatibility        |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-litellm \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/litellm:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager (except pip for Python packages)
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

**Note**: No FIPS-compliant or -dev images are currently available in the catalog for LiteLLM.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace litellm/litellm or other base images (ghcr.io/berriai/litellm, etc.) with the Docker Hardened LiteLLM image.                                                                                                                                                                                                                             |
| Package management | Non-dev images don't contain Debian package managers. Python's pip is included as part of the Python installation in a virtual environment at `/opt/litellm`, allowing you to extend with custom callbacks and packages. Note that adding packages can potentially introduce new CVEs or break previously remediated CVEs if not done carefully. |
|                    | Non-root user                                                                                                                                                                                                                                                                                                                                    |
| Multi-stage build  | For custom extensions, use a multi-stage build approach. Build stages can use dev variants (when available) for compilation, then copy artifacts to the runtime stage.                                                                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                               |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure LiteLLM to listen on port 4000 or another unprivileged port.                                                 |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. The DHI LiteLLM image uses `/app/docker/prod_entrypoint.sh` as the entry point.                                                                                                                                                                                     |
| No shell           | By default, non-dev images don't contain a shell. Use Docker Debug for troubleshooting or mount debugging tools when needed.                                                                                                                                                                                                                     |

The following steps outline the general migration process.

1. **Find hardened images for your app.** Check the available Docker Hardened LiteLLM image tags in your namespace to
   find the variant that meets your needs.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image. For example:

   ```dockerfile
   FROM dhi.io/litellm:<version-tag>

   # Switch to UID 0 for file operations and package installations
   USER 0

   # Copy your custom callbacks and configuration
   COPY custom_callbacks.py /app/custom_callbacks.py
   COPY litellm-config.yaml /app/config.yaml

   # Install additional Python packages if needed
   COPY requirements.txt /app/requirements.txt
   RUN pip install -r /app/requirements.txt

   # Ensure files have correct permissions for nonroot user
   RUN chown nonroot:nonroot /app/custom_callbacks.py /app/config.yaml /app/requirements.txt
   RUN chmod 644 /app/custom_callbacks.py /app/config.yaml /app/requirements.txt

   # Set working directory
   WORKDIR /app

   # Switch back to nonroot user for runtime security
   USER nonroot

   # Use the standard DHI entrypoint
   ENTRYPOINT ["/app/docker/prod_entrypoint.sh"]
   ```

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build when adding system-level dependencies.

1. **Install additional packages** The LiteLLM software is installed in a virtualenv at `/opt/litellm`. The `litellm`
   executable and `pip` are both symlinked to that location, keeping them out of a system-level Python environment. Use
   pip to install any additional Python packages your callbacks or custom code requires.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain common shell tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Python environment

The LiteLLM software is installed in a virtualenv at `/opt/litellm`. The `litellm` executable and `pip` are both
symlinked to that location, keeping them out of a system-level Python environment. When installing additional packages,
they will be installed directly into this virtual environment.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
LiteLLM port 4000 works without issues.

### Entry point

Docker Hardened Images may have different entry points than upstream images. The DHI LiteLLM image uses
`/app/docker/prod_entrypoint.sh` instead of `/docker/prod_entrypoint.sh` as the entry point . Use `docker inspect` to
verify the entry point and update your Dockerfile if necessary.
