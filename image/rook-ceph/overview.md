## About Rook Ceph

Rook Ceph is the Kubernetes operator and helper image used to deploy, configure, and manage Ceph clusters in
cloud-native environments. It packages the upstream `rook` binary together with the Ceph command-line tools and helper
assets that Rook expects when managing Ceph services and storage workflows on Kubernetes.

This Docker Hardened Image builds on the hardened `dhi/ceph` runtime so the Rook operator image stays aligned with the
Ceph userland it orchestrates, while also carrying the upstream `s5cmd`, monitoring assets, and external-cluster helper
files from the matching Rook release.

For more information, visit https://rook.io/ and https://ceph.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide signed provenance, SBOM
metadata, VEX support, and a minimized runtime surface so teams can adopt upstream software with fewer supply-chain and
maintenance surprises.

## Trademarks

Ceph(R) is a registered trademark of Red Hat, Inc. Kubernetes(R) is a registered trademark of The Linux Foundation. Any
rights therein are reserved to their respective owners. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
