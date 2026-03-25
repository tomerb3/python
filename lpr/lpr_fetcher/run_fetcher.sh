#!/bin/bash
set -e

LOCK_FILE="/tmp/lpr_fetcher.lock"
SCRIPT_DIR="/home/baum/src/python_readonly/lpr/lpr_fetcher"
LOG_FILE="$SCRIPT_DIR/fetcher.log"

# Run with flock to prevent concurrent executions
exec flock -n "$LOCK_FILE" -c "cd $SCRIPT_DIR && python3 lpr_fetcher.py" >> "$LOG_FILE" 2>&1
