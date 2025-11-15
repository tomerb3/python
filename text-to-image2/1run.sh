#!/bin/bash
set -euo pipefail

PEXELS_API_KEY="${PEXELS_API_KEY:-}"

backgrounds() {
  local query="${1:-nature}"
  local out_dir="/mnt/c/ffmpeg/c/back1"

  if [[ -z "$PEXELS_API_KEY" ]]; then
    echo "PEXELS_API_KEY is not set" >&2
    exit 1
  fi

  mkdir -p "$out_dir"

  # Request 8 photos from Pexels search API
  local json
  json=$(curl -fSs \
    -H "Authorization: $PEXELS_API_KEY" \
    "https://api.pexels.com/v1/search?query=${query}&per_page=8")

  if [[ -z "$json" ]]; then
    echo "Empty response from Pexels API" >&2
    exit 1
  fi

  # Extract image URLs (original size) with python and download them
  echo "$json" | python - "$out_dir" << 'PY'
import os
import sys
import json
import urllib.request

data = json.load(sys.stdin)
out_dir = sys.argv[1]

photos = data.get("photos", [])
for i, photo in enumerate(photos, start=1):
    src = photo.get("src", {})
    url = src.get("original") or src.get("large") or src.get("medium")
    if not url:
        continue
    filename = os.path.join(out_dir, f"back_{i}.jpg")
    print(f"Downloading {url} -> {filename}")
    urllib.request.urlretrieve(url, filename)
PY
}

usage() {
  echo "Usage: $0 <command> [args...]" >&2
  echo "Commands:" >&2
  echo "  backgrounds [query]   Download 8 Pexels images into /mnt/c/ffmpeg/c/back1" >&2
}

cmd="${1:-}"
shift || true

case "$cmd" in
  backgrounds)
    backgrounds "$@" ;;
  ""|-h|--help|help)
    usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac