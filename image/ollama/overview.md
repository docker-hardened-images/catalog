## About Ollama

[Ollama](https://ollama.com) is an open-source tool for running large language models locally. It exposes an HTTP API
(`OLLAMA_HOST`, default `0.0.0.0:11434`) for pulling models from a registry and running inference, and spawns a separate
`llama-server` subprocess (built from `ggml-org/llama.cpp`) to perform the actual inference. The default tags run CPU
inference; the `-cuda` flavor adds the CUDA backend for NVIDIA GPUs and is compatible with the NVIDIA Container Toolkit
(`--gpus all`). ROCm, Vulkan, and Jetson backends are not included.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
