FROM python:3.10.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install ffmpeg for video creation
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything from the current directory into the image
COPY . /app/

# Install Python dependencies
# (assumes requirements.txt is in the project root)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Default to running Python so you can pass the script name and args after `docker run`
ENTRYPOINT ["python"]