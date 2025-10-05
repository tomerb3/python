#!/usr/bin/env bash
set -euo pipefail

# This entrypoint tries to use a host virtualenv mounted into the container.
# Caveat: host venvs are generally NOT portable across OS/architectures.
# This will best-effort source it; if that fails, it will fall back to system Python.

VENV_HOST_MOUNT_DIR=${VENV_HOST_MOUNT_DIR:-/venv-host}
APP_DIR=${APP_DIR:-/app}
PYTHON_BIN=${PYTHON_BIN:-python3}

# Try to activate the mounted venv
if [ -f "${VENV_HOST_MOUNT_DIR}/bin/activate" ]; then
  echo "Sourcing mounted venv: ${VENV_HOST_MOUNT_DIR}"
  # shellcheck disable=SC1090
  source "${VENV_HOST_MOUNT_DIR}/bin/activate" || echo "Warning: could not activate venv; will try PYTHONPATH fallback"

  if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    # Activation failed to provide python; try adding site-packages to PYTHONPATH
    pyver=$(${PYTHON_BIN} -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")') || pyver="3"
    SITE_PACKAGES="${VENV_HOST_MOUNT_DIR}/lib/python${pyver}/site-packages"
    if [ -d "$SITE_PACKAGES" ]; then
      export PYTHONPATH="${SITE_PACKAGES}:${PYTHONPATH-}"
      echo "Set PYTHONPATH to mounted venv site-packages: ${SITE_PACKAGES}"
    else
      echo "Mounted venv site-packages not found: ${SITE_PACKAGES}"
    fi
  fi
else
  echo "Mounted venv activate not found at ${VENV_HOST_MOUNT_DIR}/bin/activate; using system Python"
fi

cd "${APP_DIR}"

if [ "$#" -eq 0 ]; then
  echo "Usage: supply your Python script and args as container arguments"
  echo "Example: docker run ... image python your_script.py --flag val"
  exec bash
fi

exec "$@"
