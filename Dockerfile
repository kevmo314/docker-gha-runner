ARG VERSION=latest
FROM ghcr.io/actions/actions-runner:${VERSION}

USER root

# The official runner image includes Docker and Buildx, but not the Compose plugin
# or a C compiler. GitHub-hosted runners ship gcc, so cgo builds assume it exists.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg wget && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    . /etc/os-release && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-compose-plugin build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/runner

COPY --chown=runner:runner --chmod=0755 ./start.sh ./start.sh

USER runner

CMD ["./start.sh"]
