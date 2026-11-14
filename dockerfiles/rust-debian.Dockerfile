# syntax=docker/dockerfile:1.29


# debian:trixie-slim
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS base

ARG TARGETARCH
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates=20250419 && \
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

# base ends as the app user; installing needs root, line 77 switches back
USER root

ARG TARGETARCH
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    UV_INSTALL_DIR=/usr/local/cargo \
    GITHUB_WORKDIR=/__w \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.100.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,mode=0755,target=/root/.cache/uv \
    --mount=type=secret,id=git-credentials,env=GITHUB_TOKEN \
    # APT
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential=12.* clang=1:19.* make=4.* pkg-config=1.* \
    git=1:2.* git-lfs=3.* curl=8.* gnupg2=2.* \
    python3-dev=3.13.* python3-pip=25.* python3-venv=3.13.* gh=2.* && \
    # Install uv \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    # Rust Toolchain
    curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain "$RUST_VERSION" --no-modify-path --profile minimal && \
    # Rust packages
    rustup component add llvm-tools-preview && \
    curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/v1.27.0/install-from-binstall-release.sh | bash && \
    cargo binstall cargo-llvm-cov@0.9.1 cargo-nextest@0.9.152 cargo-sweep@0.8.0 maturin@1.16.0 --no-confirm --locked && \
    # Install crane (static, daemon-less registry client, for pulling/exporting
    # images in CI without a docker daemon)
    CRANE_ARCH="$(case "$TARGETARCH" in amd64) echo x86_64 ;; arm64) echo arm64 ;; esac)" && \
    curl -sL "https://github.com/google/go-containerregistry/releases/download/v0.22.1/go-containerregistry_Linux_${CRANE_ARCH}.tar.gz" | tar -xz -C "$CARGO_HOME/bin" crane && \
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
