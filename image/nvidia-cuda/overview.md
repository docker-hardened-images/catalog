## About NVIDIA CUDA

NVIDIA CUDA is a parallel computing platform and programming model for general-purpose computing on NVIDIA GPUs. This
image provides the CUDA runtime libraries needed to execute GPU-accelerated workloads, and in the dev variant the nvcc
compiler and development headers for building CUDA applications. The image is intended as a base for downstream ML, HPC,
and scientific computing images.

The image follows NVIDIA's standard container conventions and is compatible with the NVIDIA Container Toolkit
(`--gpus all`). For full documentation, see [docs.nvidia.com/cuda](https://docs.nvidia.com/cuda/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA, CUDA, and cuDNN are trademarks of NVIDIA Corporation. All rights in these marks are reserved to NVIDIA
Corporation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

This image distributes the NVIDIA CUDA Toolkit under the NVIDIA CUDA Toolkit End User License Agreement
(https://docs.nvidia.com/cuda/eula/). The cudnn variants additionally distribute NVIDIA cuDNN under the cuDNN Supplement
to the NVIDIA Software License Agreement (https://docs.nvidia.com/deeplearning/cudnn/sla/). By using this image you
accept the terms of the applicable license.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
