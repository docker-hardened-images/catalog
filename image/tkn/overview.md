## About Tekton CLI

The Tekton CLI (`tkn`) is the command line interface for Tekton, the Kubernetes-native framework for building CI/CD
systems. It manages Tekton Pipelines, Tasks, and Triggers resources against a cluster and packages Tekton resources as
OCI bundles.

### Key Features

- **Pipeline and Task Management**: Create, start, describe, list, and delete Pipelines, Tasks, PipelineRuns, TaskRuns,
  and CustomRuns
- **Log Streaming**: Follow logs from running or completed pipeline and task runs
- **Triggers Support**: Manage EventListeners, TriggerBindings, ClusterTriggerBindings, and TriggerTemplates
- **OCI Bundles**: Package Tekton resources into OCI images and list bundle contents with `tkn bundle`
- **Tekton Hub**: Search and install reusable Tasks and Pipelines from Tekton Hub
- **Shell Completion**: Generate completion scripts for bash, zsh, fish, and PowerShell

### Common Use Cases

- **Pipeline Operations**: Start pipelines and follow their logs from a terminal or CI job
- **In-Cluster Automation**: Run as the step image inside a Tekton `Task` to drive Tekton from a pipeline
- **Debugging**: Describe runs and inspect step status when a pipeline fails
- **Resource Distribution**: Publish and inspect Tekton resources as OCI bundles in any registry
- **GitOps Workflows**: Apply and inspect Tekton resources as part of a delivery pipeline

### Getting Started

The `tkn` CLI reads cluster credentials the same way `kubectl` does, from a kubeconfig file or an in-cluster
ServiceAccount. Common operations include:

- `tkn version` - Print the client version
- `tkn pipeline list` - List Pipelines in the current namespace
- `tkn pipeline start` - Start a Pipeline and optionally follow its logs
- `tkn pipelinerun logs -f` - Follow the logs of a PipelineRun
- `tkn task describe` - Show details for a Task
- `tkn bundle push` - Package Tekton resources into an OCI bundle
- `tkn bundle list` - List the resources inside an OCI bundle
- `tkn hub search` - Search Tekton Hub for reusable Tasks and Pipelines

This Docker Hardened Image provides a secure, minimal environment for running Tekton CLI operations in containerized
workflows, Tekton `Task` steps, and CI/CD pipelines.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. Tekton is a trademark of the Linux Foundation. All third-party product names, logos,
and trademarks are the property of their respective owners and are used solely for identification. Docker claims no
interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
