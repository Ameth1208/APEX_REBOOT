# syntax=docker/dockerfile:1
# Official Debian image index; Compose selects its linux/amd64 variant.
ARG APEX_BASE_IMAGE=debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587
FROM ${APEX_BASE_IMAGE} AS download
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*
COPY tools/docker/install-godot.sh tools/docker/godot.lock /tmp/apex-toolchain/
RUN --mount=type=cache,id=apex-godot-4.6.3,sharing=locked,target=/downloads \
    bash /tmp/apex-toolchain/install-godot.sh /opt/godot /downloads

FROM ${APEX_BASE_IMAGE} AS builder
COPY --from=download /opt/godot /opt/godot
COPY licenses/LICENSE.txt licenses/COPYRIGHT.txt /opt/godot/licenses/
RUN groupadd --gid 1000 apex \
    && useradd --uid 1000 --gid 1000 --create-home apex \
    && mkdir -p /cache /workspace \
    && chmod 1777 /cache \
    && ln -s /opt/godot/bin/godot /usr/local/bin/godot
ENV LANG=C.UTF-8
WORKDIR /workspace
USER 1000:1000
RUN godot --headless --version
ENTRYPOINT ["bash", "/workspace/tools/docker/export.sh"]
CMD ["all"]
