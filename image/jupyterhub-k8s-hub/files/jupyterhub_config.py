# SPDX-License-Identifier: BSD-3-Clause
# Default JupyterHub configuration for the Docker Hardened Image.
# Zero to JupyterHub on Kubernetes mounts a generated configuration over this path.
from traitlets.config import get_config

c = get_config()
