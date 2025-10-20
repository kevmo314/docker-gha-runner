# docker-gha-runner

A dead-simple way to add GitHub Actions Runners to your account.

## Motivation

I kept getting annoyed by how the GitHub Actions runner script is sort of stateful and has access to the surrounding environment.
What I really want is the exact same as the GitHub Actions default runner but self-host it. This is in that direction. The actions
container is torn down and restarted when the action ends, therefore it's stateless like the default runner.

Additionally, if you have a powerful machine available to you and want to use that as a runner so you don't have to pay for a third-
party service to use what resources you already have available.

## Features

* Stateless execution
* Container isolation
* Self-host it wherever you want
* Architecture emulation via QEMU

## Limitations

* There's no dispatching layer so you'll pay more than something like [runs-on](https://runs-on.com/) if that's your jam.

## Usage with Docker

Bring up the container, setting `ACCESS_TOKEN` and `REPOSITORY`.

`REPOSITORY` is the organization and repository name only, for example `-e REPOSITORY=kevmo314/docker-gha-runner`.

```sh
docker run -e REPOSITORY=... -e ACCESS_TOKEN=... -d --rm --restart always ghcr.io/kevmo314/docker-gha-runner:main
```

Once it's running, check out your runners page:

![image](https://github.com/user-attachments/assets/1f2ee5a3-03e3-4bcb-9905-09a5cb2b1024)

You can then update your GitHub Actions workflows:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux]
```

## Usage with Docker Compose

Using `docker compose` allows some additional cool features such as adding replicas.

Create a `docker-compose.yml`

```yaml
services:
  runner:
    image: ghcr.io/kevmo314/docker-gha-runner:main
    restart: always
    deploy:
      mode: replicated
      replicas: 4
    environment:
      REPOSITORY: <the repository you wish to link to>
      ACCESS_TOKEN: <github access token>
```

Then

```sh
docker compose up -d
```

## Platform Emulation

If you want to emulate a different platform (such as an arm64 machine on an x86-64 machine), first make sure
you've configured qemu

```sh
docker run --rm --privileged multiarch/qemu-user-static --reset --persistent yes --credential yes
```

Then, set `platform` in your compose file:

```yaml
services:
  runner_amd64:
    image: ghcr.io/kevmo314/docker-gha-runner:main
    platform: linux/amd64
    restart: always
    deploy:
      mode: replicated
      replicas: 4
    environment:
      REPOSITORY: <the repository you wish to link to>
      ACCESS_TOKEN: <github access token>
  runner_arm64:
    image: ghcr.io/kevmo314/docker-gha-runner:main
    platform: linux/arm64
    restart: always
    deploy:
      mode: replicated
      replicas: 4
    environment:
      REPOSITORY: <the repository you wish to link to>
      ACCESS_TOKEN: <github access token>
```

And you should now have four x86-64 runners and four arm64 runners. Neat!

## Docker-in-Docker

Some example compose files are available to demonstrate how to use this Docker-based GitHub Actions runner
with Docker-based GitHub Actions (ex. `docker/build-push-action`), a form of Docker-in-Docker.

### [`DinD with Sysbox`](docker-compose.sysbox-dind.yml)

This version is more secure but has some limitations, notably it does not support platform emulation due to
binfmt_misc support in Sysbox. It also requires [Sysbox](https://github.com/nestybox/sysbox) to be
installed on the host running the Actions runners, which has certain [Linux distro limitations](https://github.com/nestybox/sysbox/blob/master/docs/distro-compat.md).

To use this version, make sure your host meets the requirements and install Sysbox on the host. Use the example
compose file, or specify the `sysbox-runc` runtime and set the environment variable `DOCKER_SYSBOX_RUNTIME` to
a non-empty string (ex. `1` or `true`) in your own compose file.

### [`DinD with a sidecar`](docker-compose.sidecar-dind.yml)

**This version is insecure. Docker containers can access the host. TLS is enabled on the Docker daemon to
minimize network exposure to rogue clients. Make sure you trust the Actions jobs that can be executed on
these runners, including pull requests!**

This version is more flexible than the Sysbox-based DinD solution and supports platform emulation. It works
by spawning Docker as a separate service (a sidecar) and setting the appropriate environment variables to enable
communication from the runners. This version requires no extra configuration and should work "out of the box."

```sh
docker exec -t gha-runner-gha-runner-arm64-1 docker run --rm -t arm64v8/ubuntu uname -m
aarch64
```

### [`DinD with a sidecar (no PE)`](docker-compose.sidecar-dind-nope.yml)

This version is the same as [`DinD with a sidecar`](#dind-with-a-sidecar) except it has platform
emulation support removed. **This does not make it any more secure.** But, you can use this version if you do not
need platform emulation support and your host lacks support for [Sysbox](https://github.com/nestybox/sysbox),
or you don't want to install it.

### [`DinD with host Docker`](docker-compose.host-docker.yml)

**This version is insecure. Containers have direct access to the host Docker daemon and filesystem.**

This version directly mounts the host's Docker socket into the runner container. It's the simplest approach
but provides no isolation. Use only in trusted environments where you control all Actions that will run.

To use this version, ensure the `DOCKER_GID` environment variable matches your host's Docker group ID:
```sh
export DOCKER_GID=$(getent group docker | cut -d: -f3)
docker compose -f docker-compose.host-docker.yml up -d
```

## Testing Docker-in-Docker

A comprehensive test suite is provided to validate DinD functionality:

```sh
# Test the sidecar approach (recommended)
./test-dind.sh sidecar

# Test the simpler sidecar approach (no platform emulation)
./test-dind.sh sidecar-nope

# Test the Sysbox approach
./test-dind.sh sysbox

# Test the host Docker approach
./test-dind.sh host
```

The test script validates:
- Basic Docker commands (`version`, `info`, `run`)
- Docker build functionality
- Platform emulation (where supported)
- Container cleanup

You can also use the provided GitHub Actions workflow example (`.github-workflows-test-dind.yml`) to test
DinD functionality within actual GitHub Actions.
