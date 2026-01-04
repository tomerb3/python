import importlib.util
import os
import subprocess
import sys
from types import ModuleType
from typing import Any


def _load_module_from_path(path: str) -> ModuleType:
    module_name = os.path.splitext(os.path.basename(path))[0]
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module from {path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    script_name = os.environ.get("script_name")
    if not script_name:
        print("ERROR: env var 'script_name' is required (e.g. -e script_name=tb-2ver.py)", file=sys.stderr)
        return 2

    app_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(app_dir, script_name)
    if not os.path.isfile(script_path):
        print(f"ERROR: script not found: {script_path}", file=sys.stderr)
        return 2

    if len(sys.argv) < 2:
        print("ERROR: missing function name argument (e.g. func1)", file=sys.stderr)
        return 2

    func_name = sys.argv[1]
    func_args = sys.argv[2:]

    if func_name == "main":
        completed = subprocess.run([sys.executable, "-u", script_path, *func_args])
        return int(completed.returncode)

    try:
        module = _load_module_from_path(script_path)
    except Exception as e:
        print(f"ERROR: failed to import {script_name}: {e}", file=sys.stderr)
        return 1

    func: Any = getattr(module, func_name, None)
    if func is None or not callable(func):
        print(f"ERROR: function '{func_name}' not found or not callable in {script_name}", file=sys.stderr)
        return 2

    result = func(*func_args)
    if isinstance(result, int):
        return result

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
