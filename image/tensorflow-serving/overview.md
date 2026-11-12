## About TensorFlow Serving

TensorFlow Serving is a flexible, high-performance serving system for machine learning models designed for production
environments. It is part of the TensorFlow Extended (TFX) platform and provides a robust infrastructure for deploying
machine learning models at scale.

This Docker Hardened Image provides the CPU variant of TensorFlow Serving, optimized for inference workloads on
CPU-based infrastructure.

TensorFlow Serving supports model versioning, allowing you to deploy new model versions without taking down the service.
It automatically manages model lifecycle, loading new versions and unloading old ones based on configurable policies.
The system is optimized for low latency and high throughput, making it suitable for production workloads.

TensorFlow Serving provides both REST and gRPC APIs for making predictions. The REST API is convenient for development
and testing, while the gRPC API offers better performance for production deployments. The system supports batching
multiple requests together to improve CPU utilization and overall throughput.

TensorFlow Serving is widely used in production systems for serving recommendations, image classification, natural
language processing, and other machine learning applications at scale.

For more details, visit https://www.tensorflow.org/tfx/guide/serving.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

TensorFlow, the TensorFlow logo and any related marks are trademarks of Google Inc. All rights in the marks are reserved
to Google Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
