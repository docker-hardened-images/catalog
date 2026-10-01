## Installing the chart

### Prerequisites

- Kubernetes 1.21+
- Helm 3+
- A GitLab instance and a runner authentication token (created under your GitLab project, group, or instance runner
  settings)

### Installation steps

All examples in this guide use the public chart and images. If you've mirrored the repository for your own use (for
example, to your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

The same `regctl` tool that is used for mirroring container images can also be used for mirroring Helm charts, as Helm
charts are OCI artifacts.

```console
 regctl image copy \
     "${SRC_CHART_REPO}:${TAG}" \
     "${DEST_REG}/${DEST_CHART_REPO}:${TAG}" \
     --referrers \
     --referrers-src "${SRC_ATT_REPO}" \
     --referrers-tgt "${DEST_REG}/${DEST_CHART_REPO}" \
     --force-recursive
```

#### Step 2: Create a Kubernetes secret for pulling images

The Docker Hardened Images that the chart uses require authentication. To allow your Kubernetes cluster to pull those
images, you need to create a Kubernetes secret with your Docker Hub credentials or with the credentials for your own
registry.

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

The runner launches a pod for each CI/CD job, and those pods pull the hardened helper and job images with the same
secret. Reference it in the runner configuration through `image_pull_secrets` (see "Configure the runner").

#### Step 3: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.

```console
helm install my-gitlab-runner oci://dhi.io/gitlab-runner-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set gitlabUrl=https://gitlab.example.com \
  --set runnerToken=<runner authentication token> \
  --set rbac.create=true
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier. Replace
`gitlabUrl` and `runnerToken` with the URL of your GitLab instance and the authentication token of the runner you
created there. `rbac.create=true` lets the chart create the role the runner needs to start job pods with the Kubernetes
executor.

#### Step 4: Verify the installation

The runner Deployment should be created in the release namespace and become ready once the runner has registered against
your GitLab instance:

```console
$ kubectl get deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
my-gitlab-runner   1/1     1            1           60s

$ kubectl logs deployment/my-gitlab-runner | grep "Starting multi-runner"
Starting multi-runner from /home/gitlab-runner/.gitlab-runner/config.toml...
```

The runner also appears as an online runner in your GitLab instance under the project, group, or instance runner
settings, and picks up CI/CD jobs from there.

### Configure the runner

Runner configuration is passed through the `runners.config` value, a `config.toml` template the runner registers with.
The chart's default configuration pins the hardened helper image and the default job image:

```yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{ default .Release.Namespace .Values.runners.jobNamespace }}"
        image = "<default job image>"
        helper_image = "<dhi.io gitlab-runner-helper reference>"
        image_pull_secrets = ["helm-pull-secret"]
```

When you provide your own `runners.config`, keep the `helper_image` setting (or set your own mirrored reference).
Without it the runner falls back to pulling its helper from `registry.gitlab.com`. Add `image_pull_secrets` with the
secret you created in step 2 so job pods can pull the hardened helper and job images. The `image` setting is only the
default for jobs that do not declare an `image:` in their `.gitlab-ci.yml`; jobs that declare one use their own image as
usual.

### Use FIPS variants

The `dhi/gitlab-runner` and `dhi/gitlab-runner-helper` images ship FIPS variants. To run the runner and its helper on
them, override the runner tag and the helper reference:

```console
helm install my-gitlab-runner oci://dhi.io/gitlab-runner-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set gitlabUrl=https://gitlab.example.com \
  --set runnerToken=<runner authentication token> \
  --set rbac.create=true \
  --set image.tag=<version>-debian13-fips
```

and set `helper_image = "dhi.io/gitlab-runner-helper:<version>-debian13-fips"` in your `runners.config`.

### Differences from the upstream chart

- The runner pod runs the hardened `dhi/gitlab-runner` image as user 65532 and starts the `gitlab-runner` binary
  directly. The upstream image's `dumb-init` supervisor and `/entrypoint` wrapper script are not used.
- Job pods default to the hardened `dhi/gitlab-runner-helper` helper image and to `dhi/busybox` as the default job
  image, instead of `registry.gitlab.com` and Docker Hub images.
- The session server (`sessionServer.enabled`) is not supported: its address-discovery scripts need `curl` and `sed`,
  which the hardened runtime image does not ship.
- `useTini` is not supported, because the hardened image does not ship `tini`.
