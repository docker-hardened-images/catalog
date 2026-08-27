## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

git-sync runs as a nonroot user and writes into its sync root (`/git` by default). Mount a writable volume there, or set
`--root` to another writable mount.

### Sync a public repository one time

The following command syncs a repository once into a local directory and exits. Replace `<tag>` with the image variant
you want to run.

```
$ docker run --rm -v $(pwd)/data:/git dhi.io/git-sync:<tag> \
    --one-time \
    --repo=https://github.com/kubernetes/git-sync \
    --ref=master \
    --root=/git \
    --link=current
```

The synced worktree is published at `/git/current`.

### Sync continuously

Omit `--one-time` and set a period to keep the directory synchronized:

```
$ docker run --rm -v $(pwd)/data:/git dhi.io/git-sync:<tag> \
    --repo=https://github.com/kubernetes/git-sync \
    --ref=master \
    --root=/git \
    --link=current \
    --period=30s
```

### Sync over SSH

Provide an SSH key and a known_hosts file, and use an SSH-style repository URL:

```
$ docker run --rm \
    -v $(pwd)/data:/git \
    -v $HOME/.ssh/id_ed25519:/etc/git-secret/ssh:ro \
    -v $HOME/.ssh/known_hosts:/etc/git-secret/known_hosts:ro \
    dhi.io/git-sync:<tag> \
    --repo=git@github.com:kubernetes/git-sync.git \
    --ref=master \
    --root=/git \
    --link=current \
    --ssh-known-hosts=true
```

### Run as a Kubernetes sidecar

git-sync is most often deployed as a sidecar sharing an `emptyDir` volume with the main container. Set the pod's
`securityContext.fsGroup` so the nonroot user can write to the shared volume, and point your application at the `--link`
path (for example `/git/current`).

Under a hardened pod (`readOnlyRootFilesystem: true`), mount a writable `emptyDir` at both the sync root (`/git`) and at
`/tmp`. git-sync writes temporary state at startup and, for authenticated (private) repositories, caches credentials
under `$HOME` (which defaults to `/tmp` in this image) - so a writable `/tmp` is required for git-sync to start and for
authenticated syncs to work.

This image runs as uid/gid `65532` (the upstream git-sync image runs as `65533`). If you are migrating from the upstream
image, set the pod's `securityContext.fsGroup` to `65532` and ensure any pre-provisioned volume is writable by uid/gid
`65532`, so git-sync can write into the sync root.

### Exec and webhook hooks

git-sync can notify on each successful sync via a webhook (sent over HTTP by git-sync itself, needing nothing extra) or
an exec hook (a command you supply with `--exechook-command`). This is a minimal runtime image: it ships `git`, `ssh`,
`bash`, `ca-certificates` and the coreutils git itself needs, but not the wider tool set (`curl`, `socat`, `tar`,
`gzip`) an exec-hook script might call. If your exec hook needs additional tools, run that logic from a separate sidecar
or extend the image; the webhook path requires no additions.

### Display help information

```
$ docker run --rm dhi.io/git-sync:<tag> --man
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

For git-sync, the FIPS variant builds the git-sync binary with the FIPS-validated Go cryptographic module (which covers
git-sync's own crypto, such as GitHub App token signing) and ships the OpenSSL FIPS provider used by the bundled `git`
for HTTPS/TLS transport. To run the FIPS variant, select a `fips` tag:

```
$ docker run --rm -v $(pwd)/data:/git dhi.io/git-sync:<tag>-fips \
    --one-time \
    --repo=https://github.com/kubernetes/git-sync \
    --ref=master \
    --root=/git \
    --link=current
```

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.
