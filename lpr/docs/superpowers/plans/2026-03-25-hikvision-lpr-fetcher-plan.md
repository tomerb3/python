# Hikvision LPR Camera Data Fetcher — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Python script on WSL2 Ubuntu that fetches latest 20 vehicle captures from Hikvision LPR camera every 5 minutes via cron, saves plate images and metadata to JSON.

**Architecture:** Python script using `requests` library with HTTP Digest Auth to query Hikvision ISAPI endpoints. Discovers correct endpoints at runtime, downloads plate images, outputs `vehicles.json`. Bash wrapper handles cron invocation with flock concurrency protection.

**Tech Stack:** Python 3, `requests` library, `flock`, `cron`

---

## File Structure

```
/home/baum/src/lpr/
├── lpr_fetcher/
│   ├── lpr_fetcher.py      # Main script
│   ├── config.py           # Configuration (env vars)
│   ├── run_fetcher.sh     # Cron wrapper (flock)
│   ├── images/             # Downloaded plate images
│   ├── vehicles.json       # Output data
│   └── fetcher.log        # Cron log output
└── docs/superpowers/plans/
```

---

## Task 1: Create Directory Structure

**Files:**
- Create: `/home/baum/src/lpr/lpr_fetcher/images/`

- [ ] **Step 1: Create directories**

```bash
mkdir -p /home/baum/src/lpr/lpr_fetcher/images
touch /home/baum/src/lpr/lpr_fetcher/vehicles.json
touch /home/baum/src/lpr/lpr_fetcher/fetcher.log
```

- [ ] **Step 2: Verify structure**

```bash
ls -la /home/baum/src/lpr/lpr_fetcher/
```

Expected: `images/` directory exists, empty `vehicles.json` and `fetcher.log`

---

## Task 2: Create `config.py`

**Files:**
- Create: `/home/baum/src/lpr/lpr_fetcher/config.py`

- [ ] **Step 1: Write config.py**

```python
import os

CAMERA_URL = os.environ.get("LPR_CAMERA_URL", "http://shomron13.ddns.net:8215")
USERNAME = os.environ.get("LPR_CAMERA_USER", "admin")
PASSWORD = os.environ.get("LPR_CAMERA_PASSWORD")

OUTPUT_DIR = "/home/baum/src/lpr/lpr_fetcher"
IMAGES_DIR = f"{OUTPUT_DIR}/images"
VEHICLES_FILE = f"{OUTPUT_DIR}/vehicles.json"

# Retry settings
MAX_RETRIES = 3
RETRY_BACKOFF = [1, 2, 4]  # seconds

# Disk space threshold (MB)
MIN_DISK_SPACE_MB = 50

def get_required_env(var_name: str) -> str:
    """Get required environment variable or exit with error."""
    value = os.environ.get(var_name)
    if not value:
        print(f"ERROR: {var_name} environment variable is required")
        exit(1)
    return value
```

- [ ] **Step 2: Test import**

```bash
cd /home/baum/src/lpr/lpr_fetcher && python3 -c "import config; print(config.CAMERA_URL)"
```

Expected: prints default URL

---

## Task 3: Create `lpr_fetcher.py` — Core Structure & Auth

**Files:**
- Create: `/home/baum/src/lpr/lpr_fetcher/lpr_fetcher.py`
- Test: Inline test using `--test-auth` flag

- [ ] **Step 1: Write skeleton with auth test**

```python
#!/usr/bin/env python3
import argparse
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Optional

import requests
from requests.auth import HTTPDigestAuth

import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def test_auth() -> bool:
    """Test authentication against camera's deviceInfo endpoint."""
    url = f"{config.CAMERA_URL}/ISAPI/System/deviceInfo"
    try:
        response = requests.get(
            url,
            auth=HTTPDigestAuth(config.USERNAME, config.PASSWORD),
            timeout=10,
        )
        if response.status_code == 200:
            logger.info("Auth successful: %s", response.text[:200])
            return True
        else:
            logger.error("Auth failed: HTTP %d - %s", response.status_code, response.text[:200])
            return False
    except requests.RequestException as e:
        logger.error("Auth error: %s", e)
        return False


def discover_endpoints() -> dict:
    """Discover available ISAPI endpoints on the camera."""
    # Try common LPR endpoints
    endpoints = {
        "device_info": f"{config.CAMERA_URL}/ISAPI/System/deviceInfo",
        "vehicle_recognition": f"{config.CAMERA_URL}/ISAPI/Traffic/channels/1/vehicleRecognition",
    }
    results = {}
    for name, url in endpoints.items():
        try:
            response = requests.get(
                url,
                auth=HTTPDigestAuth(config.USERNAME, config.PASSWORD),
                timeout=10,
            )
            results[name] = {"url": url, "status": response.status_code, "works": response.status_code == 200}
        except requests.RequestException as e:
            results[name] = {"url": url, "error": str(e)}
    return results


def fetch_vehicles() -> list:
    """Fetch vehicle records from camera."""
    # Placeholder - returns empty list until we discover real endpoint
    return []


def main():
    parser = argparse.ArgumentParser(description="Hikvision LPR Fetcher")
    parser.add_argument("--test-auth", action="store_true", help="Test camera authentication")
    parser.add_argument("--discover", action="store_true", help="Discover ISAPI endpoints")
    args = parser.parse_args()

    if args.test_auth:
        success = test_auth()
        sys.exit(0 if success else 1)

    if args.discover:
        results = discover_endpoints()
        print(json.dumps(results, indent=2))
        sys.exit(0)

    # Normal run
    logger.info("Fetching vehicles from %s", config.CAMERA_URL)
    vehicles = fetch_vehicles()
    logger.info("Got %d vehicles", len(vehicles))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Set password and test auth**

```bash
export LPR_CAMERA_PASSWORD="YOUR_PASSWORD_HERE"
cd /home/baum/src/lpr/lpr_fetcher && python3 lpr_fetcher.py --test-auth
```

Expected: Auth successful message or error with HTTP status

- [ ] **Step 3: Discover endpoints**

```bash
cd /home/baum/src/lpr/lpr_fetcher && python3 lpr_fetcher.py --discover
```

Expected: JSON with endpoint status codes

---

## Task 4: Implement `fetch_vehicles()` — ISAPI Integration

**Files:**
- Modify: `/home/baum/src/lpr/lpr_fetcher/lpr_fetcher.py`

**Note:** The actual ISAPI endpoint for LPR data varies by camera firmware. This task implements the full fetching logic assuming an endpoint exists. User will need to verify/correct the endpoint after discovery.

- [ ] **Step 1: Add helper functions before `fetch_vehicles()`**

```python
def retry_with_backoff(func, max_retries=3, backoff=[1, 2, 4]):
    """Retry a function with exponential backoff, handling HTTP 429 rate limits."""
    for attempt in range(max_retries):
        try:
            return func()
        except requests.RequestException as e:
            if attempt == max_retries - 1:
                raise
            wait = backoff[attempt] if attempt < len(backoff) else backoff[-1]
            logger.warning("Attempt %d failed: %s. Retrying in %ds...", attempt + 1, e, wait)
            time.sleep(wait)


def retry_request(url, auth, timeout=30, max_retries=3):
    """Make HTTP request with rate limit (429) handling and retry logic."""
    for attempt in range(max_retries):
        response = requests.get(url, auth=auth, timeout=timeout)

        if response.status_code == 200:
            return response

        if response.status_code == 429:
            # Rate limited - respect Retry-After header
            retry_after = response.headers.get("Retry-After", backoff[attempt] if attempt < len(backoff) else backoff[-1])
            try:
                wait = int(retry_after)
            except ValueError:
                wait = backoff[attempt] if attempt < len(backoff) else backoff[-1]
            logger.warning("Rate limited (429). Waiting %ds before retry...", wait)
            time.sleep(wait)
            continue

        if attempt == max_retries - 1:
            raise requests.RequestException(f"HTTP {response.status_code} after {max_retries} attempts")

        time.sleep(backoff[attempt] if attempt < len(backoff) else backoff[-1])

    raise requests.RequestException("Max retries exceeded")


def get_image_url(vehicle_data: dict) -> Optional[str]:
    """Extract plate image URL from vehicle data."""
    # Hikvision ISAPI typically embeds image URL in the vehicle data
    # Look for common field names
    for key in ["plateImageUrl", "imageUrl", "picUrl", "platePicUrl"]:
        if key in vehicle_data:
            return vehicle_data[key]
    return None


def parse_timestamp(ts_str: str) -> str:
    """Normalize timestamp to ISO format."""
    # Hikvision returns: "2026-03-25T14:30:00Z" or similar
    return ts_str.replace(" ", "T") + "Z" if not ts_str.endswith("Z") else ts_str
```

- [ ] **Step 2: Implement `fetch_vehicles()` with multiple endpoint fallbacks**

```python
LPR_ENDPOINTS = [
    "/ISAPI/Traffic/channels/1/vehicleRecognition",
    "/ISAPI/Traffic/channels/1/LPR",
    "/ISAPI/LPR/vehicleRecognition",
    "/ISAPI/Traffic/channels/1/vehicleDetect",
]


def fetch_vehicles() -> list:
    """Fetch vehicle records from camera ISAPI."""
    vehicles = []

    for endpoint in LPR_ENDPOINTS:
        url = f"{config.CAMERA_URL}{endpoint}"
        logger.info("Trying endpoint: %s", url)
        try:
            response = retry_request(
                url,
                auth=HTTPDigestAuth(config.USERNAME, config.PASSWORD),
                timeout=30,
            )
            logger.info("Endpoint works: %s", url)
            data = response.text
            # Parse XML or JSON depending on response
            vehicles = parse_vehicle_response(data)
            break
        except requests.RequestException as e:
            logger.warning("Endpoint error: %s - %s", url, e)
            continue

    if not vehicles:
        logger.warning("No working LPR endpoint found")

    return vehicles[:20]  # Latest 20
```

- [ ] **Step 3: Add `parse_vehicle_response()`**

```python
def parse_vehicle_response(data: str) -> list:
    """Parse ISAPI vehicle recognition response (XML format)."""
    vehicles = []
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(data)

        # Namespace map for Hikvision ISAPI
        ns = {"ns": "http://www.hikvision.com/tech/"} if "hikvision" in data else {}

        # Try to find vehicle elements - structure varies by firmware
        # Look for common element names
        for item in root.iter():
            if item.tag in ["Vehicle", "vehicle", "LPRRecord", "lprRecord"]:
                vehicle = extract_vehicle_fields(item)
                if vehicle:
                    vehicles.append(vehicle)

    except ET.ParseError:
        logger.warning("Failed to parse XML response")
    except Exception as e:
        logger.warning("Error parsing vehicle response: %s", e)

    return vehicles


def extract_vehicle_fields(element) -> Optional[dict]:
    """Extract vehicle fields from XML element."""
    vehicle = {}
    for child in element:
        tag = child.tag.split("}")[-1]  # Strip namespace
        if tag in ["plateNumber", "plateNo", "licensePlate", "plate"]:
            vehicle["plate_number"] = child.text or ""
        elif tag in ["captureTime", "time", "timestamp", "dateTime"]:
            vehicle["capture_time"] = parse_timestamp(child.text or "")
        elif tag in ["lane", "laneId", "laneID"]:
            vehicle["lane"] = child.text or ""
        elif tag in ["direction", "dir"]:
            vehicle["direction"] = child.text or ""
        elif tag in ["matchResult", "match", "result"]:
            vehicle["match_result"] = child.text or ""
        elif tag in ["country", "countryRegion", "region"]:
            vehicle["country"] = child.text or ""
        elif tag in ["plateImageUrl", "imageUrl", "picUrl"]:
            vehicle["image_url"] = child.text or ""

    return vehicle if vehicle.get("plate_number") else None
```

- [ ] **Step 4: Test discovery again**

```bash
export LPR_CAMERA_PASSWORD="YOUR_PASSWORD"
cd /home/baum/src/lpr/lpr_fetcher && python3 lpr_fetcher.py --discover
```

Expected: Find at least one working endpoint

---

## Task 5: Implement Image Download & JSON Output

**Files:**
- Modify: `/home/baum/src/lpr/lpr_fetcher/lpr_fetcher.py`

- [ ] **Step 1: Add disk space check**

```python
import shutil

def check_disk_space(path: str, required_mb: int = 50) -> bool:
    """Check if disk has required space available."""
    stat = shutil.disk_usage(path)
    free_mb = stat.free / (1024 * 1024)
    if free_mb < required_mb:
        logger.error("Disk space low: %.1f MB free (need %d MB)", free_mb, required_mb)
        return False
    return True
```

- [ ] **Step 2: Add image download function**

```python
def download_image(image_url: str, plate_number: str, timestamp: str) -> Optional[str]:
    """Download plate image and return local path. Retries once on 0-byte download."""
    if not image_url:
        return None

    # Build filename
    safe_plate = plate_number.replace("/", "_").replace("\\", "_").replace(":", "_")
    timestamp_safe = timestamp.replace(":", "-").replace("T", "_").replace("Z", "")
    filename = f"{safe_plate}_{timestamp_safe}.jpg"
    local_path = os.path.join(config.IMAGES_DIR, filename)

    # Skip if already downloaded and file exists with size > 0
    if os.path.exists(local_path) and os.path.getsize(local_path) > 0:
        logger.debug("Image already exists: %s", local_path)
        return local_path

    def _download():
        response = requests.get(
            image_url,
            auth=HTTPDigestAuth(config.USERNAME, config.PASSWORD),
            timeout=30,
        )
        if response.status_code == 200:
            return response.content
        raise requests.RequestException(f"HTTP {response.status_code}")

    for attempt in range(2):  # Try twice: initial + 1 retry
        try:
            content = _download()
            if len(content) == 0:
                if attempt == 0:
                    logger.warning("Image is 0 bytes, retrying: %s", image_url)
                    time.sleep(1)
                    continue
                else:
                    logger.warning("Image download returned 0 bytes twice: %s", image_url)
                    return None
            with open(local_path, "wb") as f:
                f.write(content)
            logger.info("Downloaded image: %s", local_path)
            return local_path
        except requests.RequestException as e:
            if attempt == 0:
                logger.warning("Image download error: %s, retrying...", e)
                time.sleep(1)
                continue
            logger.warning("Image download error after retry: %s", e)
            return None

    return None
```

- [ ] **Step 3: Update `fetch_vehicles()` to process images and update JSON**

```python
def write_vehicles_json(vehicles: list):
    """Write vehicles to JSON file with image paths."""
    if not check_disk_space(config.OUTPUT_DIR, config.MIN_DISK_SPACE_MB):
        logger.error("Insufficient disk space")
        return

    # Backup existing file if corrupted
    if os.path.exists(config.VEHICLES_FILE):
        try:
            with open(config.VEHICLES_FILE, "r") as f:
                json.load(f)  # Test if valid JSON
        except (json.JSONDecodeError, IOError):
            backup_path = config.VEHICLES_FILE + ".bak"
            logger.warning("Corrupted JSON file, backing up to %s", backup_path)
            shutil.copy(config.VEHICLES_FILE, backup_path)

    output_vehicles = []
    for v in vehicles:
        record = {
            "capture_time": v.get("capture_time"),
            "plate_number": v.get("plate_number"),
            "plate_image": v.get("plate_image"),
            "lane": v.get("lane"),
            "direction": v.get("direction"),
            "match_result": v.get("match_result"),
            "country": v.get("country"),
        }
        output_vehicles.append(record)

    with open(config.VEHICLES_FILE, "w") as f:
        json.dump(output_vehicles, f, indent=2)

    logger.info("Wrote %d vehicles to %s", len(output_vehicles), config.VEHICLES_FILE)
```

- [ ] **Step 4: Update `main()` to run full pipeline**

```python
def main():
    parser = argparse.ArgumentParser(description="Hikvision LPR Fetcher")
    parser.add_argument("--test-auth", action="store_true", help="Test camera authentication")
    parser.add_argument("--discover", action="store_true", help="Discover ISAPI endpoints")
    args = parser.parse_args()

    if args.test_auth:
        success = test_auth()
        sys.exit(0 if success else 1)

    if args.discover:
        results = discover_endpoints()
        print(json.dumps(results, indent=2))
        sys.exit(0)

    # Validate credentials
    if not config.PASSWORD:
        logger.error("LPR_CAMERA_PASSWORD environment variable not set")
        sys.exit(1)

    # Ensure output dir exists
    Path(config.IMAGES_DIR).mkdir(parents=True, exist_ok=True)

    # Check disk space
    if not check_disk_space(config.OUTPUT_DIR, config.MIN_DISK_SPACE_MB):
        sys.exit(1)

    # Fetch vehicles
    logger.info("Fetching vehicles from %s", config.CAMERA_URL)
    vehicles = fetch_vehicles()
    logger.info("Got %d vehicles from API", len(vehicles))

    # Write output
    write_vehicles_json(vehicles)
    logger.info("Done")
```

---

## Task 6: Create `run_fetcher.sh`

**Files:**
- Create: `/home/baum/src/lpr/lpr_fetcher/run_fetcher.sh`

- [ ] **Step 1: Write bash wrapper**

```bash
#!/bin/bash
set -e

LOCK_FILE="/tmp/lpr_fetcher.lock"
SCRIPT_DIR="/home/baum/src/lpr/lpr_fetcher"
LOG_FILE="$SCRIPT_DIR/fetcher.log"

# Run with flock to prevent concurrent executions
exec flock -n "$LOCK_FILE" -c "cd $SCRIPT_DIR && python3 lpr_fetcher.py" >> "$LOG_FILE" 2>&1
```

- [ ] **Step 2: Make executable and test**

```bash
chmod +x /home/baum/src/lpr/lpr_fetcher/run_fetcher.sh
chmod 600 /home/baum/src/lpr/lpr_fetcher/fetcher.log
```

---

## Task 7: Full Integration Test

- [ ] **Step 1: Set environment and run manually**

```bash
export LPR_CAMERA_PASSWORD="YOUR_ACTUAL_PASSWORD"
cd /home/baum/src/lpr/lpr_fetcher && python3 lpr_fetcher.py
```

Expected: Fetches vehicles, downloads images, writes `vehicles.json`

- [ ] **Step 2: Check output**

```bash
cat /home/baum/src/lpr/lpr_fetcher/vehicles.json
ls -la /home/baum/src/lpr/lpr_fetcher/images/
```

- [ ] **Step 3: Run bash wrapper**

```bash
cd /home/baum/src/lpr/lpr_fetcher && ./run_fetcher.sh
cat /home/baum/src/lpr/lpr_fetcher/fetcher.log
```

---

## Task 8: Cron Setup

- [ ] **Step 1: Add to crontab**

```bash
crontab -e
```

Add line:
```
*/5 * * * * /home/baum/src/lpr/lpr_fetcher/run_fetcher.sh
```

- [ ] **Step 2: Verify cron**

```bash
crontab -l
```

- [ ] **Step 3: (Optional) Set up logrotate**

```bash
sudo nano /etc/logrotate.d/lpr-fetcher
```

Contents:
```
/home/baum/src/lpr/lpr_fetcher/fetcher.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## Testing Checklist

| Test | Command | Success Criteria |
|------|---------|------------------|
| Auth test | `python3 lpr_fetcher.py --test-auth` | HTTP 200, device info printed |
| Discover | `python3 lpr_fetcher.py --discover` | At least one endpoint returns 200 |
| Manual run | `python3 lpr_fetcher.py` | `vehicles.json` updated, images downloaded |
| Bash wrapper | `./run_fetcher.sh` | Same as manual run |
| Concurrent run | Run twice quickly | Second instance skipped (flock) |

---

## Troubleshooting

**"Auth failed: HTTP 401"** — Wrong password. Verify `LPR_CAMERA_PASSWORD` env var.

**"No working LPR endpoint found"** — Camera firmware may use different endpoint paths. Run with `--discover` and check the actual ISAPI paths from camera's web interface (check browser network tab when viewing the LPR page).

**"Connection timeout"** — Camera not reachable from WSL2. Check network connectivity: `curl -v http://shomron13.ddns.net:8215/ISAPI/System/deviceInfo`

**"Empty vehicles array"** — No recent captures on camera, or XML parsing failed. Check camera has LPR captures in its internal view.
