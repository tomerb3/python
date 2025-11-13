# Base image with exact Python version 3.10.14
FROM python:3.10.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install ffmpeg for video creation
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy scripts into the image
COPY 1.py 2.py /app/

# Install Python deps used by the scripts
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir huggingface_hub pillow

# Default to running Python so you can pass the script name and args after `docker run`
ENTRYPOINT ["python"]
