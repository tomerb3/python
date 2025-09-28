# Parametric Python base (match your venv's Python minor version)
ARG PYTHON_IMAGE=python:3.11-slim
FROM ${PYTHON_IMAGE}

# Install useful runtime deps (tini for signal handling; ffmpeg for compose_video)
RUN set -eux; \
    # Handle EOL Debian (e.g., buster) by switching to archive mirrors
    if grep -Eqs 'VERSION=.*buster' /etc/os-release || grep -qs 'buster' /etc/apt/sources.list; then \
      sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list; \
      sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list; \
      apt-get -o Acquire::Check-Valid-Until=false update; \
    else \
      apt-get update; \
    fi; \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      tini \
    && rm -rf /var/lib/apt/lists/*

ENV VENV_DIR=/venv
WORKDIR /app

# Entrypoint to activate mounted venv and run a Python script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["tini", "-g", "--", "/usr/local/bin/docker-entrypoint.sh"]
