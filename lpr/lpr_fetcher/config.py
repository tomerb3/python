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
