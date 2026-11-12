## About Sorry Cypress Director

[Sorry Cypress](https://github.com/sorry-cypress/sorry-cypress) is an open source alternative to Cypress Cloud for
running Cypress tests in parallel. The director is the service Cypress records to, and it creates the run, hands each
spec file to the next free machine, collects the results and reports status to hooks such as GitHub, Slack or a webhook.

The director keeps runs in memory by default and stores them in MongoDB when the MongoDB execution driver is set, with
screenshots and videos going to S3, MinIO, Azure Blob Storage or Google Cloud Storage through a screenshots driver. This
image runs the director under Node.js and replaces `agoldis/sorry-cypress-director`.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Sorry Cypress is distributed under the MIT License and claims no trademark of its own. This listing is prepared by
Docker. All third-party product names, logos, and trademarks are the property of their respective owners and are used
solely for identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is
implied.
