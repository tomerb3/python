# Use official Python 3.10 image (closest stable to 3.10.14)
FROM python:3.10-slim

# Ensure system is up to date and basic build deps (optional: needed if some wheels need compiling)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# Set working directory inside the container
WORKDIR /app

# Copy only requirements for dependency install
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Default command: do nothing; you will override with `docker run ...`
CMD ["bash"]