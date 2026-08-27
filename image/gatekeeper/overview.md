## About Gatekeeper

Gatekeeper is a policy controller for Kubernetes, built on top of the
[Open Policy Agent](https://www.openpolicyagent.org/) (OPA) Constraint Framework. Gatekeeper integrates with the
Kubernetes admission controller API to enforce policies that govern which resources can be created on a cluster, and it
can audit existing resources against those same policies.

Policies are expressed as `ConstraintTemplate` and `Constraint` custom resources written in
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/), OPA's declarative policy language. Common uses
include enforcing required labels, restricting container images to approved registries, blocking privileged workloads,
and ensuring resource quotas and security contexts.

Gatekeeper is an official sub-project of Open Policy Agent (OPA), which is a
[Cloud Native Computing Foundation](https://www.cncf.io/) graduated project.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

OPEN POLICY AGENT and GATEKEEPER are trademarks of The Linux Foundation. Use of these trademarks does not imply
endorsement by The Linux Foundation or the Open Policy Agent project.
