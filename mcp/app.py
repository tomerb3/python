import os
import time
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, Literal

import subprocess
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse

app = FastAPI(title="Home MCP Service")

DATA_DIR = Path("/data")
DATA_DIR.mkdir(parents=True, exist_ok=True)

JobStatus = Literal["running", "ready", "done", "error"]

jobs: Dict[str, Dict] = {}
_jobs_lock = threading.Lock()


def _set_job(job_id: str, **fields) -> None:
    with _jobs_lock:
        jobs.setdefault(job_id, {})
        jobs[job_id].update(fields)


def _any_running() -> bool:
    with _jobs_lock:
        return any(j.get("status") == "running" for j in jobs.values())


@app.get("/hb")
async def hb() -> Dict[str, str]:
    """Healthcheck.

    - "ready"  -> service up, no jobs running
    - "running" -> at least one job currently running
    """
    return {"status": "running" if _any_running() else "ready"}


def _run_task(job_id: str, task_type: str, payload: Dict[str, Any]) -> None:
    try:
        _set_job(job_id, status="running")

        if task_type == "task1":
            # Simulate long work
            time.sleep(60)
            target = DATA_DIR / "file1.txt"
            target.write_text("tomer", encoding="utf-8")
        elif task_type == "task2":
            # Simulate long work
            time.sleep(60)
            target = DATA_DIR / "file2.txt"
            target.write_text("baum", encoding="utf-8")
        elif task_type == "tts":
            text = payload.get("text")
            if not text:
                raise ValueError("'text' is required for tts task")

            # Host base path for MCP data, used both inside this container and as host path for docker -v
            base_root = Path(os.environ.get("TTS_HOST_BASE", "/home/baum/src/mcp"))
            base_dir = base_root / "folder1"
            base_dir.mkdir(parents=True, exist_ok=True)

            script_path = base_dir / "video_script.txt"
            script_path.write_text(str(text), encoding="utf-8")

            # Call external TTS docker container on the host via docker socket.
            # Option B: mount TTS source dir (with run_tts.py) and data dir separately.
            tts_src = Path(
                os.environ.get(
                    "TTS_SRC_DIR",
                    "/home/baum/src/tbstuff/ai/n8n/backup/n8n_data/scripts/tts/docker",
                )
            )

            cmd = [
                "docker",
                "run",
                "--rm",
                "-e",
                "PYTHONWARNINGS=ignore::UserWarning:pkg_resources",
                "-v",
                "root1:/root/.local/share",
                "-e",
                "COQUI_TOS_AGREED=1",
                "-e",
                "COQUI_LOCAL_USER=1",
                "-v",
                f"{tts_src}:/app",
                "-v",
                f"{base_dir}:/app/folder1",
                "tts",
                "python",
                "run_tts.py",
                "--folder_name",
                "folder1",
                "--output_file_name",
                "folder1.mp3",
                "--model_name",
                "tts_models/multilingual/multi-dataset/xtts_v2",
                "--speaker_wav",
                "/app/example/example.wav",
                "--language",
                "en",
                "--slowdown",
                "1.00",
            ]

            proc = subprocess.run(
                cmd,
                cwd=str(base_dir),
                text=True,
                capture_output=True,
            )
            if proc.returncode != 0:
                raise RuntimeError(
                    "tts docker failed "
                    f"(code {proc.returncode}):\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
                )

            target = base_dir / "folder1.mp3"
            if not target.exists():
                raise RuntimeError(f"Expected output file not found: {target}")
        else:
            raise ValueError(f"Unknown task_type: {task_type}")

        _set_job(job_id, status="done", filename=str(target))
    except Exception as exc:  # noqa: BLE001
        _set_job(job_id, status="error", error=str(exc))


@app.post("/task")
async def create_task(payload: Dict[str, Any]):
    task_type = payload.get("task_type")
    if task_type not in {"task1", "task2", "tts"}:
        raise HTTPException(status_code=400, detail="task_type must be 'task1', 'task2' or 'tts'")

    job_id = str(uuid.uuid4())
    _set_job(job_id, status="ready", task_type=task_type)

    thread = threading.Thread(target=_run_task, args=(job_id, task_type, payload), daemon=True)
    thread.start()

    return {"job_id": job_id, "status": "running"}


@app.get("/status/{job_id}")
async def get_status(job_id: str):
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="job not found")
    return {"job_id": job_id, **job}


@app.get("/result/{job_id}")
async def get_result(job_id: str):
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="job not found")

    status = job.get("status")
    if status != "done":
        return JSONResponse({"job_id": job_id, "status": status}, status_code=202)

    filename = job.get("filename")
    if not filename:
        raise HTTPException(status_code=500, detail="job finished without filename")

    path = Path(filename)
    if not path.exists():
        raise HTTPException(status_code=404, detail="result file missing")

    return FileResponse(path, filename=path.name)


def get_port() -> int:
    value = os.environ.get("MCP_PORT", "8089")
    try:
        return int(value)
    except ValueError:
        return 8089


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="0.0.0.0", port=get_port(), reload=False)
