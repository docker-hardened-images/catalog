## About AWS Node Termination Handler

AWS Node Termination Handler gracefully handles EC2 instance lifecycle events within Kubernetes clusters. It monitors
for termination signals — including Spot Instance interruptions, scheduled maintenance windows, ASG scale-in events, and
EC2 instance rebalance recommendations — and cordons and drains the affected node before the instance is terminated,
ensuring that running workloads are safely evicted and rescheduled.

It operates in two modes: IMDS Processor, which runs as a DaemonSet and polls the EC2 instance metadata service directly
on each node, and Queue Processor, which runs as a Deployment and consumes termination events from an SQS queue
populated by Amazon EventBridge.

For more details, see the
[AWS Node Termination Handler GitHub repository](https://github.com/aws/aws-node-termination-handler).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, and the Powered by AWS logo are trademarks of Amazon.com, Inc. or its affiliates. All rights
in the mark are reserved to Amazon.com, Inc. or its affiliates. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
