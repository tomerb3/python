#!/usr/bin/env python3
import argparse
import json
import logging
import os
import shutil
import sys
import time
from pathlib import Path
from typing import Optional

import requests
from requests.auth import HTTPDigestAuth

import config

LPR_ENDPOINTS = [
    "/ISAPI/Traffic/channels/1/vehicleDetect/plates",
]

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
    endpoints = {
        "device_info": f"{config.CAMERA_URL}/ISAPI/System/deviceInfo",
        "plates": f"{config.CAMERA_URL}/ISAPI/Traffic/channels/1/vehicleDetect/plates",
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


def parse_timestamp(ts_str: str) -> str:
    """Normalize timestamp to ISO format."""
    if not ts_str:
        return ""
    if "T" in ts_str and "+" in ts_str:
        try:
            date_part = ts_str.split("T")[0]
            time_tz = ts_str.split("T")[1]
            time_part = time_tz.split("+")[0]
            tz = "+" + time_tz.split("+")[1]
            dt = f"{date_part[:4]}-{date_part[4:6]}-{date_part[6:8]}T{time_part[:2]}:{time_part[2:4]}:{time_part[4:6]}{tz}"
            return dt
        except:
            pass
    return ts_str


def fetch_vehicles() -> list:
    """Fetch vehicle records from camera ISAPI."""
    vehicles = []

    for endpoint in LPR_ENDPOINTS:
        url = f"{config.CAMERA_URL}{endpoint}"
        logger.info("Trying endpoint: %s", url)
        try:
            body = '''<?xml version="1.0" encoding="UTF-8"?>
<PlateQuery version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
<plateNo>.*</plateNo>
<timeSpan>
<startTime>2026-03-01T00:00:00Z</startTime>
<endTime>2026-12-31T23:59:59Z</endTime>
</timeSpan>
</PlateQuery>'''
            response = requests.post(
                url,
                auth=HTTPDigestAuth(config.USERNAME, config.PASSWORD),
                data=body,
                headers={'Content-Type': 'application/xml'},
                timeout=30,
            )
            if response.status_code == 200:
                logger.info("Endpoint works: %s", url)
                vehicles = parse_vehicle_response(response.text)
                break
            else:
                logger.warning("Endpoint returned %d: %s", response.status_code, url)
                continue
        except requests.RequestException as e:
            logger.warning("Endpoint error: %s - %s", url, e)
            continue

    if not vehicles:
        logger.warning("No working LPR endpoint found")

    return vehicles[:20]


def parse_vehicle_response(data: str) -> list:
    """Parse ISAPI vehicle recognition response (XML format)."""
    vehicles = []
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(data)
        for item in root.iter():
            tag = item.tag.split("}")[-1] if "}" in item.tag else item.tag
            if tag in ["Plate", "plate"]:
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
        tag = child.tag.split("}")[-1]
        if tag in ["plateNumber", "plateNo"]:
            vehicle["plate_number"] = child.text or ""
        elif tag == "captureTime":
            vehicle["capture_time"] = parse_timestamp(child.text or "")
        elif tag in ["laneNo", "lane"]:
            vehicle["lane"] = child.text or ""
        elif tag == "direction":
            vehicle["direction"] = child.text or ""
        elif tag == "matchingResult":
            vehicle["match_result"] = child.text or ""
        elif tag == "country":
            vehicle["country"] = child.text or ""
    return vehicle if vehicle.get("plate_number") else None


def check_disk_space(path: str, required_mb: int = 50) -> bool:
    """Check if disk has required space available."""
    stat = shutil.disk_usage(path)
    free_mb = stat.free / (1024 * 1024)
    if free_mb < required_mb:
        logger.error("Disk space low: %.1f MB free (need %d MB)", free_mb, required_mb)
        return False
    return True


def load_existing_records() -> list:
    """Load existing records from vehicles.json."""
    if os.path.exists(config.VEHICLES_FILE):
        try:
            with open(config.VEHICLES_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            logger.warning("Could not load existing records, starting fresh")
    return []


def save_all_records(records: list):
    """Save all records to JSON file."""
    if not check_disk_space(config.OUTPUT_DIR, config.MIN_DISK_SPACE_MB):
        logger.error("Insufficient disk space")
        return

    with open(config.VEHICLES_FILE, "w") as f:
        json.dump(records, f, indent=2)

    logger.info("Saved %d total records to %s", len(records), config.VEHICLES_FILE)


def write_vehicles_json(new_vehicles: list):
    """Append new vehicles to existing records, deduplicate by plate+time."""
    if not new_vehicles:
        logger.info("No new vehicles to save")
        return

    # Load existing records
    existing = load_existing_records()

    # Create set of existing (capture_time, plate_number) for dedup
    existing_keys = {(r["capture_time"], r["plate_number"]) for r in existing}

    # Add new records that aren't duplicates
    added = 0
    for v in new_vehicles:
        key = (v.get("capture_time"), v.get("plate_number"))
        if key not in existing_keys:
            record = {
                "capture_time": v.get("capture_time"),
                "plate_number": v.get("plate_number"),
                "lane": v.get("lane"),
                "direction": v.get("direction"),
                "match_result": v.get("match_result"),
                "country": v.get("country"),
            }
            existing.append(record)
            existing_keys.add(key)
            added += 1

    save_all_records(existing)
    logger.info("Added %d new records (%d total)", added, len(existing))


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

    if not config.PASSWORD:
        logger.error("LPR_CAMERA_PASSWORD environment variable not set")
        sys.exit(1)

    Path(config.OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    Path(config.IMAGES_DIR).mkdir(parents=True, exist_ok=True)

    if not check_disk_space(config.OUTPUT_DIR, config.MIN_DISK_SPACE_MB):
        sys.exit(1)

    logger.info("Fetching vehicles from %s", config.CAMERA_URL)
    vehicles = fetch_vehicles()
    logger.info("Got %d vehicles from API", len(vehicles))

    write_vehicles_json(vehicles)
    logger.info("Done")


if __name__ == "__main__":
    main()
