FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
    curl unzip xz-utils git ca-certificates postgresql-client libpq-dev \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_ROOT=/opt/flutter
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_ROOT}" \
    && chown -R vscode:vscode "${FLUTTER_ROOT}"

USER vscode
RUN flutter config --enable-web --no-analytics
