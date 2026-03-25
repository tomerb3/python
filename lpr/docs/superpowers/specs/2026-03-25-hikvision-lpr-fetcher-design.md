# Hikvision LPR Camera Data Fetcher — Design Spec

## Overview

A Python script running on WSL2 Ubuntu (via cron every 5 minutes) that queries a Hikvision DS-2CD7A26G0/P LPR camera's ISAPI API, fetches the latest vehicle captures, downloads plate images, and saves everything to a JSON file.

## Camera Details

- **Model:** Hikvision DS-2CD7A26G0/P
- **URL:** http://shomron13.ddns.net:8215
- **Access:** Admin credentials, SSH enabled with port forwarding
- **Network:** Accessible via HTTP from local machine

## Data Fields to Capture

Per vehicle capture:
- `capture_time` — timestamp of capture
- `plate_number` — license plate text
- `plate_image` — local path to downloaded plate image
- `lane` — lane identifier
- `direction` — in/out
- `match_result` — matching result
- `country` — country of origin

## Architecture

```
┌─────────────────┐     HTTP ISAPI      ┌──────────────────┐
│  Hikvision LPR  │ ◄──────────────────► │  Python Fetcher  │
│  Camera         │   GET /ISAPI/...      │  Script          │
│  DS-2CD7A26G0   │                       │  (WSL2 Ubuntu)   │
└─────────────────┘                       └────────┬─────────┘
                                                   │
                                          Every 5 min (cron)
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │  vehicles.json  │
                                          │  + /images/     │
                                          └─────────────────┘
```

## Components

### 1. `lpr_fetcher/lpr_fetcher.py`

Main Python script that:
- Reads configuration from `config.py`
- Authenticates to camera via HTTP Digest Auth
- Queries ISAPI endpoint for vehicle recognition data
- Downloads plate images to `images/` subdirectory
- Writes vehicle records to `vehicles.json`
- Handles errors: network failures (retry 3x), auth failures (log + exit non-zero)

### 2. `lpr_fetcher/config.py`

```python
import os

CAMERA_URL = os.environ.get("LPR_CAMERA_URL", "http://shomron13.ddns.net:8215")
USERNAME = os.environ.get("LPR_CAMERA_USER", "admin")
PASSWORD = os.environ.get("LPR_CAMERA_PASSWORD")  # Required — no default
OUTPUT_DIR = "/home/baum/src/lpr/lpr_fetcher"
IMAGES_DIR = f"{OUTPUT_DIR}/images"
VEHICLES_FILE = f"{OUTPUT_DIR}/vehicles.json"
```

**Credentials via environment variables** — never hardcoded. Set before running:
```bash
export LPR_CAMERA_PASSWORD="your_actual_password"
```

### 3. `lpr_fetcher/run_fetcher.sh`

Bash wrapper script for cron — includes flock for concurrency protection:
```bash
#!/bin/bash
LOCK_FILE="/tmp/lpr_fetcher.lock"
exec flock -n "$LOCK_FILE" -c "/home/baum/src/lpr/lpr_fetcher/lpr_fetcher.py" >> /home/baum/src/lpr/lpr_fetcher/fetcher.log 2>&1
```

If the script is already running when cron fires, the new instance is skipped.

### 4. `lpr_fetcher/images/`

Directory storing downloaded plate images. Filename format: `{plate_number}_{timestamp}.jpg`

### 5. `lpr_fetcher/vehicles.json`

Output JSON file — array of vehicle records:
```json
[
  {
    "capture_time": "2026-03-25T14:30:00Z",
    "plate_number": "ABC-1234",
    "plate_image": "/home/baum/src/lpr/lpr_fetcher/images/ABC-1234_20260325_143000.jpg",
    "lane": "lane1",
    "direction": "in",
    "match_result": "match",
    "country": "Israel"
  }
]
```

## ISAPI Integration

### Authentication
Hikvision ISAPI uses HTTP Digest Authentication. Python `requests` library with `HTTPDigestAuth` handles this.

### Endpoints (to discover/test)
**Note:** ISAPI endpoint paths vary by camera firmware. The implementation phase will include discovery logic to probe the camera and find the correct endpoints.

Typical Hikvision LPR ISAPI endpoints (for reference):
- `/ISAPI/Traffic/channels/1/vehicleRecognition` — list vehicle captures
- `/ISAPI/Streaming/channels/1/picture` — plate image
- `/ISAPI/System/deviceInfo` — device info (for testing auth)

The script will:
1. First probe `/ISAPI/System/deviceInfo` to verify auth works
2. Then discover available LPR endpoints via OPTIONS requests or sitemap
3. Fall back to known endpoint patterns if discovery fails

### Polling Logic
1. Query vehicle list endpoint
2. Filter to latest 20 records
3. For each record, download plate image if not already cached
4. Write combined JSON output
5. Exit cleanly

## Scheduling

### Cron Job
```
*/5 * * * * /home/baum/src/lpr/lpr_fetcher/run_fetcher.sh
```

Note: Logging is handled inside `run_fetcher.sh` via flock redirection.

## Error Handling

| Scenario | Action |
|----------|--------|
| Network timeout | Retry 3 times with exponential backoff (1s, 2s, 4s) |
| Auth failure | Log error, exit(1) |
| HTTP 429 rate limit | Respect `Retry-After` header, wait accordingly |
| Invalid API response | Log warning, skip malformed records |
| `vehicles.json` corrupted | Backup to `.bak`, start fresh |
| Image download failure | Log warning, set `plate_image` to null |
| Image file is 0 bytes | Treat as download failure, retry once |
| Disk space low | Check before write, exit(1) if < 50MB free |
| Empty vehicle list | Not an error — normal case, write empty array |
| File write failure | Log error, exit(1) |

## File Structure

```
/home/baum/src/lpr/
└── lpr_fetcher/
    ├── lpr_fetcher.py      # Main script
    ├── config.py           # Configuration
    ├── run_fetcher.sh      # Cron wrapper
    ├── images/             # Downloaded plate images
    ├── vehicles.json       # Output data
    └── fetcher.log         # Cron log output
```

## Security Considerations

- **Credentials via environment variables** — not stored in source files
- Camera uses HTTP (not HTTPS) — runs on trusted network only
- Log file may contain sensitive data — restrict permissions: `chmod 600 fetcher.log`
- Consider adding `logrotate` for log management:
  ```
  /home/baum/src/lpr/lpr_fetcher/fetcher.log {
      weekly
      rotate 4
      compress
  }
  ```

## Testing

1. Test authentication: `python3 lpr_fetcher.py --test-auth`
2. Test API discovery: `python3 lpr_fetcher.py --discover`
3. Run once manually: `python3 lpr_fetcher.py`
4. Check `vehicles.json` output
5. Verify images in `images/` directory
6. Set up cron after manual testing works

## Optional Enhancements (Out of Scope for V1)

- Push notifications on new matches
- Deduplication (don't save duplicate plates within X minutes)
- Database storage instead of JSON
- Web dashboard
- Multiple cameras support
