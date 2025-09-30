FROM node:20-bullseye

# Install ffmpeg and Chromium
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    chromium \
 && rm -rf /var/lib/apt/lists/*

# Puppeteer expects CHROMIUM_PATH or to download its own. We use system Chromium:
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_DOWNLOAD=true

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm i --omit=dev

COPY renderer.html overlay.js ./

# Default command (can be overridden by n8n Execute Command)
CMD ["node", "overlay.js", "--help"]
