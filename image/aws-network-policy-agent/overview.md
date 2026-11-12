## About AWS Network Policy Agent

The AWS Network Policy Agent is a Kubernetes node agent that enforces network policies on Amazon EKS clusters. It
implements fine-grained pod-level network security using eBPF (extended Berkeley Packet Filter) programs that are loaded
into the Linux kernel to control ingress and egress traffic at the network interface level.

The agent compiles and loads eBPF TC (Traffic Control) programs that intercept and filter packets based on Kubernetes
NetworkPolicy resources. It supports both IPv4 and IPv6 policies and uses CO-RE (Compile Once – Run Everywhere)
technology to ensure the eBPF programs work across different kernel versions without recompilation.

The agent runs as a DaemonSet on each EKS node alongside the AWS VPC CNI plugin. It watches for NetworkPolicy objects
via the Kubernetes API and translates them into eBPF maps and programs that enforce the desired connectivity rules
between pods.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Amazon Web Services, AWS, and the AWS logo are trademarks
of Amazon.com, Inc. or its affiliates. All rights in these marks are reserved to their respective owners. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
