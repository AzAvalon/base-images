# syntax=docker/dockerfile:1.29


# python:3.14-slim-trixie
FROM python:3.14-slim-trixie@sha256:9aaa474097d094040649f2162a627c0049b408f52138d980916788d80f04802f AS base

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
COPY --link --from=ghcr.io/astral-sh/uv:0.13.8@sha256:5cc1805e2426484abca4ad46ea783bab281fdb225fd82d8ce6d66a81254bac85 /uv /uvx /usr/local/bin/
# crane: static, daemon-less registry client, for pulling/exporting images in
# CI without a docker daemon
COPY --link --from=gcr.io/go-containerregistry/crane:v0.22.1@sha256:1f968817b95790bed063f71175aa6b8ff879fa17064020415f3e18bb6e6a36e1 /ko-app/crane /usr/local/bin/crane

ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/github/home/.local/bin:/home/$USERNAME/.local/bin:$PATH

ARG PIP_INDEX_URL
ARG PIP_TRUSTED_HOST

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,mode=0755,target=/root/.cache/uv \
    --mount=type=secret,id=git-credentials,env=GITHUB_TOKEN \
    # APT
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential=12.* libc6-dev=2.41-* pkg-config=1.8.* \
    git=1:2.* git-lfs=3.* git-man=1:2.* gettext=0.23.* \
    jq=1.* libjq1=1.* curl=8.* unzip=6.0-* && \
    # Python packages, from wheels only: no setup script runs at build time
    uv pip install --system --break-system-packages --no-build awscli==1.46.3 && \
    # Clean
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

USER $USERNAME
