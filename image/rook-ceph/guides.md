## How to use this image

All examples in this guide use the public image. If you've mirrored the image into your own registry, replace the image
reference accordingly.

- Public image: `dhi.io/rook-ceph:<tag>`
- Mirrored image: `<your-namespace>/dhi-rook-ceph:<tag>`

Authenticate first with `docker login dhi.io` before pulling the image.

## What's included in this image

This image packages the main components that upstream Rook expects in the Ceph operator image:

- `rook` as the primary entrypoint and CLI
- Ceph client tools such as `ceph`, `rados`, and `rbd`
- `s5cmd` for object storage workflows used by upstream Rook
- The upstream `toolbox.sh` and `set-ceph-debug-level` helper scripts
- The `ceph-monitoring` and `rook-external` support assets copied from the upstream release

## Start the image

To print the packaged Rook version with the default entrypoint:

```bash
docker run --rm dhi.io/rook-ceph:<tag> version
```

To inspect the packaged Ceph CLI from the same image:

```bash
docker run --rm --entrypoint /usr/local/bin/ceph dhi.io/rook-ceph:<tag> --version
```

For interactive troubleshooting or packaging work, use the dev variant:

```bash
docker run --rm -it --entrypoint /bin/bash dhi.io/rook-ceph:<tag>-dev
```

If you need a FIPS-validated runtime, use the `-fips` tag suffix:

```bash
docker run --rm dhi.io/rook-ceph:<tag>-fips version
```

## Deploy in Kubernetes

Rook Ceph is primarily consumed through the upstream operator manifests and Helm chart rather than by running this image
directly. Prefer the upstream deployment documentation for end-to-end cluster setup:

- [Rook quickstart](https://rook.github.io/docs/rook/latest-release/Getting-Started/quickstart/)
- [Rook Ceph operator Helm chart](https://rook.io/docs/rook/latest-release/Helm-Charts/operator-chart/)

When migrating those manifests to Docker Hardened Images, replace upstream references such as `quay.io/rook/ceph:<tag>`
with `dhi.io/rook-ceph:<tag>`.

## Image variants

Docker Hardened Images are published in multiple variants:

- Runtime variants are intended for production deployment and default to the non-root `rook` user.
- Dev variants add a shell, package manager, and locales for troubleshooting, image extension, or build-stage use.
- FIPS variants add FIPS-enabled cryptographic modules and are available in both runtime and dev forms.

## Migrate to a Docker Hardened Image

Compared with the upstream `quay.io/rook/ceph` image, the main migration considerations are:

| Item              | Migration note                                                                                                                                                 |
| :---------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image reference   | Replace `quay.io/rook/ceph:<tag>` with `dhi.io/rook-ceph:<tag>`.                                                                                               |
| Default user      | Runtime variants run as the non-root `rook` user. Jobs or init containers that must change ownership or bootstrap directories may still need to run as `root`. |
| Debugging         | Runtime variants are minimal. Use Docker Debug or a `-dev` variant for interactive troubleshooting.                                                            |
| Entry point       | The runtime entrypoint remains `/usr/local/bin/rook`, so the basic upstream invocation pattern is preserved.                                                   |
| Ceph helper tools | Ceph CLIs remain available in the same image and can be invoked with `--entrypoint` overrides when needed.                                                     |

## Troubleshooting migration

Common migration considerations for this image:

- Runtime variants do not include a shell or package manager. Use Docker Debug or a `-dev` tag when you need interactive
  access.
- The default working directory is `/`, so scripts should use absolute paths rather than assuming a project-specific
  work dir.
- The helper assets copied from upstream are available at `/usr/local/bin/toolbox.sh`,
  `/usr/local/bin/set-ceph-debug-level`, `/etc/ceph-monitoring`, and `/etc/rook-external`.
- If you need to inspect or debug FIPS behavior interactively, prefer a `-fips-dev` tag so you keep both the FIPS
  configuration and the debugging tools.
