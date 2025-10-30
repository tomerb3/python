FROM python:3.11-slim

# Minimal system setup
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install Python deps
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

ENV PYTHONUNBUFFERED=1

# Default to python; you will pass the script path and args at runtime
ENTRYPOINT ["python"]
