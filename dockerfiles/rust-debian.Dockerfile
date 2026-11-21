# syntax=docker/dockerfile:1.29


# debian:trixie-slim
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS base

ARG TARGETARCH
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates=20250419* && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

ENV USERNAME=app \
    UID=1001 \
    GID=1001

RUN groupadd --gid "$GID" "$USERNAME" && \
    useradd --uid "$UID" --gid "$GID" --create-home "$USERNAME" && \
    # Chown may duplicate files if called in another layer \
    mkdir -p /opt/app /data && \
    chown -R "$USERNAME" /opt/app /data

USER $USERNAME

FROM base AS dev

# base ends as the app user; installing needs root, the end of this stage
# switches back
USER root

# uv and crane come from their official images, pinned by digest
COPY --link --from=ghcr.io/astral-sh/uv:0.13.9@sha256:d3b601f0c7b118bc1753febf7c41cc80981df678445e0254284eecf84db79a7d /uv /uvx /usr/local/bin/
# crane: static, daemon-less registry client, for pulling/exporting images in
# CI without a docker daemon
COPY --link --from=gcr.io/go-containerregistry/crane:v0.22.1@sha256:1f968817b95790bed063f71175aa6b8ff879fa17064020415f3e18bb6e6a36e1 /ko-app/crane /usr/local/bin/crane

ARG TARGETARCH
# rustup-init and cargo-binstall are downloaded, then checked against these
# sha256 sums before they run. Renovate bumps the versions; the sums must be
# updated in the same PR (build fails until they are):
#   rustup:  https://static.rust-lang.org/rustup/archive/<v>/<triple>/rustup-init.sha256
#   binstall: sha256sum of cargo-binstall-<arch>-unknown-linux-musl.tgz
ARG RUSTUP_VERSION=1.29.3 \
    RUSTUP_SHA256_AMD64=b1c8cb14e30889e7e2999e6b69e62d9e9b9ffc0f4df8180564d306d9680e6c55 \
    RUSTUP_SHA256_ARM64=9f608c142e0e38a78957d0661ba1dfaf0b6fb37184cfaa4b9a0aa57af6184282 \
    BINSTALL_VERSION=1.27.0 \
    BINSTALL_SHA256_AMD64=b2e4b70fcddc5bd6fd90c5cf8dc17b4cf0ea54a3db16c65ee0307f42c9bd3187 \
    BINSTALL_SHA256_ARM64=84f2afefd325e52c92702a1f2a396902301ccdafd7614270cbbf46b9cff3accf
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    GITHUB_WORKDIR=/__w \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.100.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=secret,id=git-credentials,env=GITHUB_TOKEN \
    # APT
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential=12.* clang=1:19.* make=4.* pkg-config=1.* \
    git=1:2.* git-lfs=3.* curl=8.* gnupg2=2.* \
    python3-dev=3.13.* python3-pip=25.* python3-venv=3.13.* gh=2.* && \
    case "$TARGETARCH" in \
      amd64) arch=x86_64; rustup_sha="$RUSTUP_SHA256_AMD64"; binstall_sha="$BINSTALL_SHA256_AMD64" ;; \
      arm64) arch=aarch64; rustup_sha="$RUSTUP_SHA256_ARM64"; binstall_sha="$BINSTALL_SHA256_ARM64" ;; \
      *) echo "Unsupported TARGETARCH ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    # Rust toolchain
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/rustup-init \
      "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${arch}-unknown-linux-gnu/rustup-init" && \
    echo "${rustup_sha}  /tmp/rustup-init" | sha256sum -c - && \
    chmod +x /tmp/rustup-init && \
    /tmp/rustup-init -y --default-toolchain "$RUST_VERSION" --no-modify-path --profile minimal && \
    rustup component add llvm-tools-preview && \
    # Rust packages
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/cargo-binstall.tgz \
      "https://github.com/cargo-bins/cargo-binstall/releases/download/v${BINSTALL_VERSION}/cargo-binstall-${arch}-unknown-linux-musl.tgz" && \
    echo "${binstall_sha}  /tmp/cargo-binstall.tgz" | sha256sum -c - && \
    tar -xzf /tmp/cargo-binstall.tgz -C "$CARGO_HOME/bin" cargo-binstall && \
    cargo binstall cargo-llvm-cov@0.9.2 cargo-nextest@0.9.152 cargo-sweep@0.8.0 maturin@1.16.0 --no-confirm --locked && \
    # Clean
    apt-get remove -y curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* && \
    # Create directories needed for github actions
    mkdir "$GITHUB_WORKDIR" && \
    # Chown may duplicate files if called in another layer
    chown -R "$USERNAME" "$RUSTUP_HOME" "$CARGO_HOME" "$GITHUB_WORKDIR"

USER $USERNAME
