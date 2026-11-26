# Read by the docker-openrc /etc/init.d/docker. The two settings the
# docker-openrc default sets, with the Docker-in-Docker data root on the
# /docker-graph volume, as upstream's images/kubekins-e2e-v2/Dockerfile does.
DOCKER_OPTS="--data-root=/docker-graph"
LOGPROXY_CHMOD=0644
