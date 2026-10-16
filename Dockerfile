FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG DEV_UID=1000
ARG DEV_GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        curl \
        gdb \
        git \
        libeigen3-dev \
        ninja-build \
        passwd \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${DEV_GID}" bazel \
    && useradd \
        --uid "${DEV_UID}" \
        --gid "${DEV_GID}" \
        --create-home \
        --shell /bin/bash \
        bazel

# Keep the release URL and architecture-specific checksums in sync when upgrading.
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) sha256=5a408715e932c0250d28bd84555f12edbf70117de42f9181691c736eacc4a992 ;; \
        arm64) sha256=e20e8b0f4f240091b7a55bf17b9398bd4f40ee70ae0208dff95dd4c445fb4010 ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl --fail --show-error --location --retry 3 \
        "https://github.com/bazelbuild/bazelisk/releases/download/v1.29.0/bazelisk-linux-${arch}" \
        --output /usr/local/bin/bazelisk; \
    echo "$sha256  /usr/local/bin/bazelisk" | sha256sum --check -; \
    chmod 0755 /usr/local/bin/bazelisk; \
    ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

WORKDIR /workspace

COPY .bazelversion .bazelversion

# Also pin invocations outside a Bazel module; keep this aligned with .bazelversion.
ENV USE_BAZEL_FALLBACK_VERSION=8.8.1
ENV BAZELISK_HOME=/opt/bazelisk
ENV USER=bazel
# Compose can run with any host UID/GID; allow it to reuse and update the cache.
RUN test "$(cat .bazelversion)" = "$USE_BAZEL_FALLBACK_VERSION" \
    && bazel --version \
    && chmod -R a+rwX "$BAZELISK_HOME"

CMD ["bash"]
