#!/bin/bash

if [[ "$REPOSITORY" != *"/"* ]]; then
  REPO_TYPE="orgs"
else
  REPO_TYPE="repos"
fi

REG_TOKEN=$(curl -fsS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/${REPO_TYPE}/${REPOSITORY}/actions/runners/registration-token | jq .token --raw-output)

echo "Using registration token $REG_TOKEN"

./config.sh --url https://github.com/${REPOSITORY} --token $REG_TOKEN --ephemeral --unattended

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token $REG_TOKEN
    rm -rf ./_work/*
    if [ -n ${DOCKER_SYSBOX_RUNTIME} ]; then
        sudo pkill --pidfile /home/github/dockerd.pid
    fi
    echo "Exiting..."
    exit 1
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap 'cleanup' HUP QUIT ABRT EXIT

unset ACCESS_TOKEN
unset REPOSITORY

if [ -n ${DOCKER_SYSBOX_RUNTIME} ]; then
    sudo rm -f /home/github/dockerd.pid
    sudo nohup /usr/bin/dockerd --pidfile /home/github/dockerd.pid >/dev/null 2>&1 < /dev/null &
fi

./run.sh & wait $!