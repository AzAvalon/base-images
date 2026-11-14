# base-images

Base images for Rust projects, built for `linux/amd64` and `linux/arm64`
and pushed to Docker Hub as `docker.io/hichamaz/base`.

| Dockerfile                           | Image tags                                           |
| ------------------------------------ | ---------------------------------------------------- |
| `dockerfiles/rust-debian.Dockerfile` | `<version>-rust-debian`, `<version>-rust-debian-dev` |

It starts from `debian:trixie-slim`.

- The plain tag (`base` stage) is the runtime image: CA certificates and
  an `app` user (uid 1001).
- The `-dev` tag (`dev` stage) is the build image: the Rust toolchain,
  clang, cargo-llvm-cov, cargo-nextest, cargo-sweep, uv, gh and crane.
  It runs as `app`.

## How it is built

`docker-bake.hcl` defines the `base` and `dev` targets. The workflows
come from [AzAvalon/workflows](https://github.com/AzAvalon/workflows):

- `build-push.yml` builds the Dockerfile on every pull request (images
  tagged `pr-<number>-<sha>-<file>`) and on every release.
- `release.yml` runs semantic-release on `main`; the GitHub release it
  creates triggers the build of the release images.
- `ci.yml` runs the pre-commit hooks and SonarCloud.

Renovate updates the base image digests, the Rust version, the cargo
tools, crane, the actions and the workflow refs.

## Repository settings

- Variable `CI_APP_CLIENT_ID` and secret `CI_APP_PRIVATE_KEY`: the
  GitHub App used by all workflows (see AzAvalon/workflows).
- Variable `DOCKERHUB_USERNAME` and secret `DOCKERHUB_TOKEN`: push to
  Docker Hub.
- Secret `SONAR_TOKEN`: SonarCloud.

All of them are set once at AzAvalon organization level.
