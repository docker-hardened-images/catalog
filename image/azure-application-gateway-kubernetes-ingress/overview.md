## About Azure Application Gateway Ingress Controller (AGIC)

Azure Application Gateway Ingress Controller (AGIC) is a Kubernetes controller that lets Azure Kubernetes Service (AKS)
clusters use Azure Application Gateway as their layer 7 load balancer. It watches Ingress resources and the Services
they route to, and configures backend pools, listeners, routing rules, health probes and TLS certificates on an
Application Gateway v2 through Azure Resource Manager. The project is documented at
https://azure.github.io/application-gateway-kubernetes-ingress/ and
https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview, and the source is at
https://github.com/Azure/application-gateway-kubernetes-ingress.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Microsoft®, Azure®, and Azure Application Gateway are trademarks of the Microsoft group of companies. Kubernetes® is a
registered trademark of The Linux Foundation. All rights in those marks are reserved to their respective owners. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
