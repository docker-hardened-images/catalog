# GitLab CNG helper scripts

These files are copied from `gitlab-org/build/CNG` tag `v19.1.6` to match the
GitLab 19.1 application used by chart 10.1.6:

https://gitlab.com/gitlab-org/build/CNG/-/tree/v19.1.6/gitlab-rails/scripts

They are distributed under the included MIT license. Two path-only adaptations
allow the scripts to run from the chart-mounted `/opt/gitlab/cng-scripts`
directory without replacing scripts already supplied by Docker Hardened Images:

- `wait-for-deps` invokes `/opt/gitlab/cng-scripts/rails-dependencies`.
- `db-migrate` invokes `/opt/gitlab/cng-scripts/custom-instance-setup`.

All other helper source is unchanged from CNG v19.1.6.
