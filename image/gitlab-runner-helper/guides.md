## How to use this image

GitLab Runner Helper is not intended to be run directly. It is used internally by GitLab Runner during CI/CD job
execution to handle git cloning, artifact management, and cache operations.

To use this image, configure your GitLab Runner to use it as the helper image. In your runner's `config.toml`:

```toml
[runners.docker]
  helper_image = "dhi.io/gitlab-runner-helper:<tag>"
```

Or at registration time:

```bash
$ docker run --rm -v /etc/gitlab-runner:/etc/gitlab-runner \
  dhi.io/gitlab-runner:<tag> register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --token "<registration-token>" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-helper-image "dhi.io/gitlab-runner-helper:<tag>" \
  --config=/etc/gitlab-runner/config.toml
```

The helper image version should match the runner version.

## Non-hardened images vs. Docker Hardened Images

The upstream `gitlab/gitlab-runner-helper` image uses `dumb-init` as a process supervisor and includes an entrypoint
shell script that handles CA certificate updates (same mechanism as the runner image). The Docker Hardened Image runs
the `gitlab-runner-helper` binary directly, so that automatic CA update no longer runs. Both images include `git`,
`git-lfs`, `bash`, and standard CA certificates.

If your GitLab instance uses a custom CA certificate, inject it into the helper container via your runner's
`config.toml`:

```toml
[runners.docker]
  environment = ["SSL_CERT_FILE=/certs/ca.crt"]
  volumes = ["/path/to/your-ca.crt:/certs/ca.crt:ro"]
```

The upstream image runs as root. The Docker Hardened Image also runs as root because the helper needs to manage file
permissions and write to arbitrary working directories during job execution.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants contain the helper binary and its required tools (git, bash). These are what you configure as the
  helper image in your runner's `config.toml`.

- FIPS variants include `fips` in the tag name and use cryptographic modules that have been validated under FIPS 140, a
  U.S. government standard for secure cryptographic operations.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.
