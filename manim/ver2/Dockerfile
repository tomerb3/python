FROM python:3.9.16-slim

WORKDIR /Timelaps

# Install system deps first
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

# Install Python deps separately to leverage Docker layer cache
COPY requirements.txt ./
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Validate Python deps at build time
RUN python - <<'PY'
import sys
mods = ["moviepy", "cv2", "numpy"]
missing = []
for m in mods:
    try:
        __import__(m)
    except Exception as e:
        missing.append((m, repr(e)))
if missing:
    raise SystemExit(f"Missing or broken modules: {missing}")
print("Dependencies OK")
PY

# Copy application source
#COPY . .

# Default command
CMD ["python", "11.py"]
