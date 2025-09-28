#!/usr/bin/env bash 
set -euo pipefail
set -x
IMAGE="gcr.io/google.com/cloudsdktool/google-cloud-cli:stable"
CONFIG_DIR="${HOME}/.config/gcloud"

mkdir -p "${CONFIG_DIR}"

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

echo "Starting Application Default Credentials login with youtube.upload scope..."
docker run -it --rm \
  -v "${CONFIG_DIR}:/root/.config/gcloud" \
  "${IMAGE}" \
  gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/youtube.upload

echo "Done. ADC stored under ${CONFIG_DIR}. You can now run the uploader script."
